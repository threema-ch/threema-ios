//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CallKit
import CocoaLumberjackSwift
import PromiseKit
import ThreemaEssentials
import ThreemaFramework
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    private static var isRunning = false
    private static var didJustReportCall = false

    var contentHandler: ((UNNotificationContent) -> Void)?
    
    private lazy var businessInjector = BusinessInjector()
    private var pendingUserNotificationManager: PendingUserNotificationManagerProtocol?

    private static var stopProcessingTimer: Timer?
    private static var stopProcessingGroup: DispatchGroup?

    private var isChatQueueDry = false
    private var isReflectionQueueDry = false

    private var conversationsChanged: Set<NSManagedObjectID>?
    private var conversationsChangedQueue =
        DispatchQueue(label: "ch.threema.NotificationService.conversationsChangedQueue")
    
    private let threemaPayloadKey = "threema"
    private let aliveCheckKey = "alive-check"
    
    private var observer: Any?

    /// Push received, every code path must call `contentHandler` (see `applyContent(...)`) at the end!
    /// - Parameters:
    ///   - request: Push request/payload
    ///   - contentHandler: Must be called before leaving this function
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        PromiseKitConfiguration.configurePromiseKit()
        
        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        AppGroup.setAppID(BundleUtil.mainBundle()?.bundleIdentifier)

        #if DEBUG
            LogManager.initializeGlobalLogger(debug: true)
        #else
            LogManager.initializeGlobalLogger(debug: false)
        #endif

        // Initialize content handler to show any notification
        self.contentHandler = contentHandler

        guard !NotificationService.didJustReportCall else {
            businessInjector.serverConnector.disconnect(initiator: .notificationExtension)

            DDLogNotice("[Push] Suppressing push because we have just reported an incoming call")
            applyContent()
            return
        }

        // Make timer invalid, to prevent stopping processing
        DispatchQueue.main.async {
            NotificationService.stopProcessingTimer?.invalidate()
        }

        guard !NotificationService.isRunning else {
            DDLogNotice("[Push] Suppressing push because Notification Extension is still running")
            return
        }
        NotificationService.isRunning = true

        // Initialize app setup state (checking database file exists) as early as possible
        _ = AppSetupState()

        AppGroup.setActive(true, for: AppGroupTypeNotificationExtension)
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)

        DDLogNotice("[Push] Notification did receive: \(request.content)")
        
        logMemoryUsage()

        // Drop shared instance in order to adapt to user's configuration changes
        UserSettings.resetSharedInstance()

        guard extensionIsReady() else {
            // Content apply is called in `extensionIsReady()` if it returns `false`
            return
        }
        
        guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            applyContent(recalculateBadgeCount: false)
            return
        }
        
        if let threemaDictEntcrypted = bestAttemptContent.userInfo[threemaPayloadKey],
           let threemaDict = PushPayloadDecryptor.decryptPushPayload(threemaDictEntcrypted as? [AnyHashable: Any]) {
            
            DDLogInfo("[Push] Request threema push: \(threemaDict)")
            
            let isAliveCheck: Bool = ((threemaDict[aliveCheckKey] as? Int) != nil)
            let threemaPushNotification = try? ThreemaPushNotification(from: threemaDict as! [String: Any])
            
            if threemaPushNotification != nil || isAliveCheck {
                
                // Exit if connected already
                if businessInjector.serverConnector.connectionState == .connecting ||
                    businessInjector.serverConnector.connectionState == .connected ||
                    businessInjector.serverConnector.connectionState == .loggedIn {
                    DDLogWarn("[Push] Suppressing push because already connected")
                    applyContent()
                    return
                }
                
                businessInjector.serverConnector.businessInjectorForMessageProcessing = businessInjector
                
                if businessInjector.settingsStore.enableThreemaGroupCalls {
                    GlobalGroupCallsManagerSingleton.shared.processBusinessInjector = businessInjector
                }
                
                // Caution: DB main context reset when start Notification Extension,
                // because the context can become corrupt and don't save any data anymore.
                DatabaseContext.reset()
                
                // Refresh all DB objects before access it
                DatabaseManager.db()?.refreshAllObjects()
                businessInjector.backgroundEntityManager.refreshAll()
                
                businessInjector.contactStore.resetEntityManager()
                
                pendingUserNotificationManager = PendingUserNotificationManager(
                    UserNotificationManager(
                        businessInjector.settingsStore,
                        businessInjector.userSettings,
                        businessInjector.myIdentityStore,
                        businessInjector.backgroundPushSettingManager,
                        businessInjector.contactStore,
                        businessInjector.backgroundGroupManager,
                        businessInjector.backgroundEntityManager,
                        businessInjector.licenseStore.getRequiresLicenseKey()
                    ),
                    businessInjector.backgroundPushSettingManager,
                    businessInjector.backgroundEntityManager
                )
                
                // Create pendingUserNotification only for message notifications, not for keep alive checks
                // Keep alive check will connect to the server, because if the last connection was too long ago, the
                // server sets the identity as inactive
                if let threemaPushNotification {
                    if threemaPushNotification.voip == false {
                        if let pendingUserNotification = pendingUserNotificationManager?
                            .pendingUserNotification(
                                for: threemaPushNotification,
                                stage: .initial
                            ) {
                            _ = pendingUserNotificationManager?
                                .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                        }
                    }
                }
                else {
                    DDLogInfo("[Push] Alive check")
                }
                
                // Start processing incoming messages and wait (max. 25s)
                DDLogNotice("[Push] Enter the stopProcessingGroup")
                NotificationService.stopProcessingGroup = DispatchGroup()
                NotificationService.stopProcessingGroup?.enter()
                
                // We observe for invalid license
                observer = NotificationCenter.default.addObserver(
                    forName: Notification.Name(rawValue: kNotificationLicenseMissing),
                    object: nil,
                    queue: nil
                ) { [weak self] _ in
                    self?.addInvalidLicenseKeyNotification(removingInitialPushFor: threemaPushNotification)
                }
                
                DispatchQueue.global().async {
                    // Initialize conversation changed for calc unread messages badge count
                    self.conversationsChangedQueue.async {
                        self.conversationsChanged = Set<NSManagedObjectID>()
                    }
                    
                    // Register message processor delegate and connect to server
                    self.businessInjector.serverConnector.registerMessageProcessorDelegate(delegate: self)
                    self.businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
                    
                    self.businessInjector.serverConnector.connect(initiator: .notificationExtension)
                }
                
                let result = NotificationService.stopProcessingGroup?.wait(timeout: .now() + 25)
                if result != .success {
                    DDLogWarn("[Push] Stopping processing incoming messages, because time is up!")
                    
                    if NotificationService.didJustReportCall {
                        DDLogError("[Push] Stopped processing incoming messages, but we were reporting a call!")
                        NotificationService.didJustReportCall = false
                    }
                }
                
                businessInjector.serverConnector.unregisterMessageProcessorDelegate(delegate: self)
                businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
                businessInjector.serverConnector.disconnectWait(initiator: .notificationExtension)
            }
            
            applyContent()
        }
        else {
            DDLogWarn("[Push] Message ID is missing")
            
            // Show test notification (necessary for customer support)
            pendingUserNotificationManager = PendingUserNotificationManager(
                UserNotificationManager(
                    businessInjector.settingsStore,
                    businessInjector.userSettings,
                    businessInjector.myIdentityStore,
                    businessInjector.backgroundPushSettingManager,
                    businessInjector.contactStore,
                    businessInjector.backgroundGroupManager,
                    businessInjector.backgroundEntityManager,
                    businessInjector.licenseStore.getRequiresLicenseKey()
                ),
                businessInjector.backgroundPushSettingManager,
                businessInjector.backgroundEntityManager
            )
            
            if bestAttemptContent.userInfo["3mw"] is [AnyHashable: Any] {
                DDLogInfo("[Push] Configure Threema Web notification")
                // Use applyContent to set the badge with the count of unread messages
                let content = pendingUserNotificationManager?
                    .editThreemaWebNotification(payload: bestAttemptContent.userInfo)
                applyContent(content)
            }
            else {
                pendingUserNotificationManager?.startTestUserNotification(
                    payload: bestAttemptContent.userInfo,
                    completion: {
                        DDLogInfo("[Push] Test notification showed!")
                        
                        let emptyContent = UNMutableNotificationContent()
                        bestAttemptContent.badge = 999
                        self.applyContent(emptyContent)
                    }
                )
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push
        // payload will be used.
        DDLogWarn("[Push] Stopping processing incoming messages, because extension will expire!")
        exitIfAllTasksProcessed(force: true)
    }
    
    // MARK: Private functions
    
    /// Apply notification content or suppress it.
    /// For muted groups update badge count here.
    ///
    /// - Parameters:
    ///   - bestAttemptContent: Best content for notification, is nil no notification will be showed
    ///   - recalculateBadgeCount: If `true` count of unread messages will calculated for changed conversations
    ///                            (`NotificationService.conversationsChanged`)
    private func applyContent(
        _ bestAttemptContent: UNMutableNotificationContent? = nil,
        recalculateBadgeCount: Bool = true
    ) {

        var badge = 0
        if recalculateBadgeCount {
            conversationsChangedQueue.sync {
                var recalculateConversations: Set<Conversation>?
                if let conversationsChanged, let conversations = businessInjector.backgroundEntityManager.entityFetcher
                    .notArchivedConversations() as? [Conversation] {

                    recalculateConversations = Set(conversations.filter { conversationsChanged.contains($0.objectID) })
                }

                if let recalculateConversations, !recalculateConversations.isEmpty {
                    badge = businessInjector.backgroundUnreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: Set(recalculateConversations))
                }
                else {
                    badge = businessInjector.backgroundUnreadMessages.totalCount()
                }
            }
            DDLogNotice("[Push] Unread messages: \(badge)")
        }
        
        logMemoryUsage()
        
        // Remove observer if there is any
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        AppGroup.setActive(false, for: AppGroupTypeNotificationExtension)
        NotificationService.isRunning = false

        if let bestAttemptContent {
            DDLogInfo("[Push] Notification showed!")
            DDLog.flushLog()

            if recalculateBadgeCount {
                bestAttemptContent.badge = NSNumber(integerLiteral: badge)
            }
            
            contentHandler?(bestAttemptContent)
        }
        else {
            DDLogInfo("[Push] Notification suppressed!")
            DDLog.flushLog()

            let emptyContent = UNMutableNotificationContent()
            
            if recalculateBadgeCount {
                emptyContent.badge = NSNumber(integerLiteral: badge)
            }
            
            contentHandler?(emptyContent)
        }
    }

    private func extensionIsReady() -> Bool {
        guard let myIdentityStore = MyIdentityStore.shared(), !myIdentityStore.isKeychainLocked() else {
            DDLogWarn("[Push] There is no MyIdentityStore or Keychain is locked.")
            showNoAccessToKeychainLocalNotification {
                self.applyContent(nil, recalculateBadgeCount: false)
            }
            
            MyIdentityStore.resetSharedInstance()
            return false
        }
        
        let appSetupSate = AppSetupState(myIdentityStore: myIdentityStore)
        guard appSetupSate.isAppSetupCompleted() else {
            DDLogWarn("[Push] App setup is not completed")
            
            showNoAccessToKeychainLocalNotification {
                self.applyContent(nil, recalculateBadgeCount: false)
            }
            
            MyIdentityStore.resetSharedInstance()
            
            return false
        }

        guard isDBReady(), !AppMigrationVersion.isMigrationRequired(userSettings: businessInjector.userSettings) else {
            DDLogWarn("[Push] DB not ready, requires migration")

            ThreemaUtility.showLocalNotification(
                identifier: "ErrorMessage",
                title: "",
                body: BundleUtil.localizedString(forKey: "new_message_db_requires_migration"),
                badge: 1,
                userInfo: nil
            ) {
                self.applyContent(nil, recalculateBadgeCount: false)
            }
            return false
        }

        guard !businessInjector.userSettings.blockCommunication else {
            DDLogWarn("[Push] Communication is blocked")

            let content = UNMutableNotificationContent()
            content.body = "Communication is blocked"
            applyContent(content, recalculateBadgeCount: false)

            return false
        }

        return true
    }

    private func isDBReady() -> Bool {
        let dbManager = DatabaseManager()
        let requiresMigration: StoreRequiresMigration = dbManager.storeRequiresMigration()
        return requiresMigration == RequiresMigrationNone
    }

    /// Exit Notification Extension if all tasks processed.
    /// - Parameters:
    ///   - force: Means last incoming task is processed, exit anyway
    ///   - reportedCall: Exit due to Threema Call was reported to the App, `NotificationService.didJustReportCall` will
    ///                   be set to `true` for 5s
    private func exitIfAllTasksProcessed(force: Bool = false, reportedCall: Bool = false) {
        let isMultiDeviceRegistered = businessInjector.settingsStore.isMultiDeviceRegistered
        if force ||
            (
                isChatQueueDry &&
                    (!isMultiDeviceRegistered || (isMultiDeviceRegistered && isReflectionQueueDry)) &&
                    TaskManager.isEmpty(queueType: .incoming)
            ) {
            DDLogNotice(
                "[Push] Stopping process incoming messages (force: \(force), because receive message queue finished or chat/reflection queue is dry!"
            )
            DDLog.flushLog()

            // Gives a little time to remove notification from notification center
            // or has pending group messages (waiting for possible "group sync request" answer)
            var delay: Double = 2
            if let pendingUserNotificationManager,
               pendingUserNotificationManager.hasPendingGroupUserNotifications() {
                DDLogNotice("Push] Delay timeout for bc. has Pending notifications")
                delay = 5
            }
            else if reportedCall {
                DDLogNotice("Push] Delay timeout for incoming call")
                delay = 5
                NotificationService.didJustReportCall = reportedCall
            }

            DispatchQueue.main.async {
                NotificationService.stopProcessingTimer?.invalidate()
                NotificationService.stopProcessingTimer = Timer.scheduledTimer(
                    withTimeInterval: delay,
                    repeats: false,
                    block: { _ in
                        if reportedCall {
                            DDLogNotice("[Push] didJustReportCall timer will start")
                            Timer.scheduledTimer(
                                withTimeInterval: delay,
                                repeats: false,
                                block: { _ in
                                    DDLogNotice("[Push] didJustReportCall timer did fire")
                                    NotificationService.didJustReportCall = false
                                }
                            )
                        }

                        DDLogNotice("[Push] Leave Processing Group")
                        NotificationService.stopProcessingGroup?.leave()
                        NotificationService.stopProcessingGroup = nil
                    }
                )
            }
        }
    }

    private func addInvalidLicenseKeyNotification(
        removingInitialPushFor threemaPushNotification: ThreemaPushNotification?
    ) {
        DDLogWarn("[Push] Show invalid license key notification")
        
        // We remove the pending notification if it exists
        if let threemaPushNotification,
           let pendingUserNotification = (
               pendingUserNotificationManager?
                   .pendingUserNotification(for: threemaPushNotification, stage: .initial)
           ) {
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }

        DDLogNotice("[Push] Left the stopProcessingGroup because there is no valid license")
        NotificationService.stopProcessingGroup?.leave()
        NotificationService.stopProcessingGroup = nil

        let content = UNMutableNotificationContent()
        content.body = BundleUtil.localizedString(forKey: "new_message_invalid_license")
        applyContent(content)
    }
    
    /// Reports incoming call to iOS, if originating identity is not blocked.
    /// - Parameters:
    ///   - payload: Payload to be reported
    ///   - identity: Originating Identity
    private func reportVoIPCall(
        for payload: [AnyHashable: Any],
        message: VoIPCallOfferMessage,
        from identity: String?,
        onCompletion: ((MessageProcessorDelegate) -> Void)? = nil
    ) {
        
        // Check if blocked
        guard let identity,
              !businessInjector.userSettings.blacklist.contains(identity) else {
            onCompletion?(self)
            return
        }
        DDLogNotice("[Push] will Report Incoming VoIP Push Payload to OS.")
        CXProvider.reportNewIncomingVoIPPushPayload(payload) { error in
            if let error {
                DDLogError("[Push] Incoming VoIP Push Payload, system disallow the call: \(error)")
            }
            else {
                DDLogNotice("[Push] Incoming VoIP Push Payload reported, leaving now")
            }
            self.exitIfAllTasksProcessed(force: true, reportedCall: true)
        }
    }

    private func logMemoryUsage() {
        let memoryTotal = ByteCountFormatter.string(
            fromByteCount: Int64(DeviceUtility.getTotalMemory()),
            countStyle: .memory
        )
        let memoryInUse = ByteCountFormatter.string(
            fromByteCount: Int64(DeviceUtility.getUsageMemory() ?? 0.0),
            countStyle: .memory
        )
        DDLogNotice("[Push] Memory: \(memoryTotal) in use \(memoryInUse)")
    }
    
    private func showNoAccessToKeychainLocalNotification(onComletion: @escaping () -> Void) {
        let title = BundleUtil.localizedString(forKey: "new_message_no_access_title")
        let message = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "new_message_no_access_message"),
            ThreemaApp.appName
        )
        
        ThreemaUtility.showLocalNotification(
            identifier: "ErrorMessage",
            title: title,
            body: message,
            badge: 1,
            userInfo: nil,
            completionHandler: onComletion
        )
    }
}

// MARK: - MessageProcessorDelegate

extension NotificationService: MessageProcessorDelegate {
    func beforeDecode() { }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        // Set dirty DB objects for refreshing in the app process
        let databaseManager = DatabaseManager()
        databaseManager.addDirtyObjectID(objectID)
    }
    
    func incomingMessageStarted(_ message: AbstractMessage) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor started for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .abstract,
                isPendingGroup: false
            ) {
                DDLogInfo("[Push] Message processor started for message id: \(msgID) found")
                _ = self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
            }
        }
    }
    
    func incomingMessageChanged(_ message: BaseMessage, fromIdentity: String) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            if let msg = self.businessInjector.backgroundEntityManager.entityFetcher
                .getManagedObject(by: message.objectID) as? BaseMessage {
                let msgID = msg.id?.hexString
                DDLogNotice("[Push] Message processor changed for message id: \(msgID ?? "nil")")

                // Set dirty DB objects for refreshing in the app process
                let databaseManager = DatabaseManager()
                databaseManager.addDirtyObject(msg)
                
                if let ballotMessage = msg as? BallotMessage,
                   let ballot = ballotMessage.ballot {
                    databaseManager.addDirtyObject(ballot)
                }
                
                if let conversation = msg.conversation {
                    databaseManager.addDirtyObject(conversation)
                    if let contact = conversation.contact {
                        databaseManager.addDirtyObject(contact)
                    }

                    self.businessInjector.backgroundUnreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: [conversation])

                    // Add conversation as change to recalculate unread messages
                    self.conversationsChangedQueue.async {
                        self.conversationsChanged?.insert(conversation.objectID)
                    }
                }

                if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                    for: msg,
                    fromIdentity: fromIdentity,
                    stage: .base
                ) {
                    DDLogInfo("[Push] Message processor changed for message id: \(msgID ?? "nil") found")
                    _ = self.pendingUserNotificationManager?
                        .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                }
            }
        }
    }
    
    func incomingMessageFinished(_ message: AbstractMessage, isPendingGroup: Bool) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor finished for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .final,
                isPendingGroup: isPendingGroup
            ) {
                DDLogNotice("[Push] Message processor finished for message id: \(msgID) found")
                self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done(on: .global(), flags: .inheritQoS) { showed in
                        if showed {
                            self.pendingUserNotificationManager?
                                .addAsProcessed(pendingUserNotification: pendingUserNotification)
                            DDLogNotice("[Push] Notification shown for message id: \(msgID)")
                        }

                        DDLogNotice("[Push] Notification processed for message id: \(msgID)")
                    }
            }
        }
    }

    func readMessage(inConversations: Set<Conversation>?) {
        conversationsChangedQueue.async {
            inConversations?.forEach { conversation in
                self.conversationsChanged?.insert(conversation.objectID)
            }
        }
    }
    
    func incomingMessageFailed(_ message: BoxedMessage) {
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .initial
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .abstract,
            isPendingGroup: false
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func taskQueueEmpty(_ queueTypeName: String) {
        let queueType = TaskQueueType.queue(name: queueTypeName)
        if queueType == .incoming {
            exitIfAllTasksProcessed(force: true)
        }
    }
    
    func chatQueueDry() {
        DDLogNotice("[Push] Message processor chat queue is dry")
        isChatQueueDry = true
        exitIfAllTasksProcessed()
    }
    
    func reflectionQueueDry() {
        DDLogNotice("[Push] Message processor reflection queue is dry")
        isReflectionQueueDry = true
        exitIfAllTasksProcessed()
    }
    
    func pendingGroup(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .abstract,
            isPendingGroup: true
        ) {
            DDLogInfo("[Push] Group not found for pending user notification")

            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func processTypingIndicator(_ message: TypingIndicatorMessage) { }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: ((MessageProcessorDelegate) -> Void)? = nil
    ) {
        switch message {
        case is VoIPCallOfferMessage:
            let offerMessage = message as! VoIPCallOfferMessage
            
            guard let identity else {
                DDLogError("No contact for processing VoIP call offer.")
                onCompletion?(self)
                return
            }
            guard businessInjector.userSettings.enableThreemaCall else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage)
                onCompletion?(self)
                return
            }
            
            let displayName = businessInjector.entityManager.entityFetcher.displayName(for: identity)!
            
            reportVoIPCall(
                for: ["NotificationExtensionOffer": identity, "NotificationExtensionCallerName": displayName],
                message: message as! VoIPCallOfferMessage,
                from: identity,
                onCompletion: onCompletion
            )
            
        case let message as VoIPCallHangupMessage:
            CallSystemMessageHelper
                .maybeAddMissedCallNotificationToConversation(
                    with: message,
                    on: businessInjector
                ) { conversation, systemMessage in
                    if let systemMessage, let conversation {
                        let databaseManager = DatabaseManager()
                        databaseManager.addDirtyObject(conversation)
                        databaseManager.addDirtyObject(systemMessage)
                        
                        self.updateNotificationContent(for: message)
                    }
                    
                    onCompletion?(self)
                }
        default:
            onCompletion?(self)
            DDLogError("Message couldn't be processed as VoIP call.")
        }
    }
    
    /// Reject call because Threema Calls are disabled on this device
    /// - Parameter offer: VoIPCallOfferMessage
    private func rejectCall(offer: VoIPCallOfferMessage) {
        let voIPCallSender = VoIPCallSender(
            messageSender: businessInjector.messageSender,
            myIdentityStore: businessInjector.myIdentityStore
        )
        let reason: VoIPCallAnswerMessage.MessageRejectReason = .disabled
        let answer = VoIPCallAnswerMessage(
            action: .reject,
            contactIdentity: offer.contactIdentity,
            answer: nil,
            rejectReason: reason,
            features: nil,
            isVideoAvailable: false,
            isUserInteraction: false,
            callID: offer.callID,
            completion: nil
        )
        voIPCallSender.sendVoIPCall(answer: answer)
        
        guard let contactIdentity = offer.contactIdentity else {
            DDLogError("Cannot reject call offer as it does not have an identity")
            return
        }
        
        CallSystemMessageHelper.addRejectedMessageToConversation(
            contactIdentity: contactIdentity,
            reason: kSystemMessageCallMissed,
            on: businessInjector
        ) { conversation, systemMessage in
            let databaseManager = DatabaseManager()
            databaseManager.addDirtyObject(conversation)
            databaseManager.addDirtyObject(systemMessage)
        }
    }
    
    private func updateNotificationContent(
        for message: VoIPCallHangupMessage,
        onCompletion: ((MessageProcessorDelegate) -> Void)? = nil
    ) {
        guard let contactIdentity = message.contactIdentity else {
            DDLogError("Cannot update local notification without contact identity")
            return
        }
        
        let contact = businessInjector.entityManager.entityFetcher.contact(for: contactIdentity)
        let notificationType = businessInjector.settingsStore.notificationType
        let content = UNMutableNotificationContent()
        
        if case .restrictive = notificationType {
            if let publicNickname = contact?.publicNickname,
               !publicNickname.isEmpty {
                content.title = publicNickname
            }
            else {
                content.title = contactIdentity
            }
        }
        else {
            if let displayName = contact?.displayName {
                content.title = displayName
            }
        }
        
        content.body = BundleUtil.localizedString(forKey: "call_missed")
        
        // Group notifications together with others from the same contact
        content.threadIdentifier = "SINGLE-\(contactIdentity)"
        applyContent(content)
    }
}

// MARK: - ConnectionStateDelegate

extension NotificationService: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        if state == .disconnecting || state == .disconnected {
            DDLogWarn(
                "[Push] Server connection is disconnected (state: \(businessInjector.serverConnector.name(for: state)))) stop processing"
            )

            guard !NotificationService.didJustReportCall else {
                DDLogNotice("[Push] Don't leave after connection state change because we just reported a call.")
                return
            }

            exitIfAllTasksProcessed(force: true)
        }
    }
}
