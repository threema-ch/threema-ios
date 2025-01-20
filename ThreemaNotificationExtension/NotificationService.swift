//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
import ThreemaMacros
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    private static var isRunning = false
    private static var runningStartDate: Date?
    private static var didJustReportCall = false

    var contentHandler: ((UNNotificationContent) -> Void)?
    
    private lazy var backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)
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
    private let pushTestKey = "push-test"
    
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
            backgroundBusinessInjector.serverConnector.disconnect(initiator: .notificationExtension)

            DDLogNotice("[Push] Suppressing push because we have just reported an incoming call")
            applyContent()
            return
        }

        // Make timer invalid, to prevent stopping processing
        DispatchQueue.main.async {
            NotificationService.stopProcessingTimer?.invalidate()
        }
        
        // Suppressing push if notification extension is still running and running date is not older then 25 seconds
        if NotificationService.isRunning,
           let startDate = NotificationService.runningStartDate,
           Date().timeIntervalSince(startDate) < kNSETimeout {
            DDLogNotice("[Push] Suppressing push because Notification Extension is still running")
            
            let emptyContent = UNMutableNotificationContent()
            contentHandler(emptyContent)
            
            return
        }
        
        // Set the running start date to check if its older then 25 seconds
        NotificationService.runningStartDate = Date()
        NotificationService.isRunning = true

        // Checking database file exists as early as possible
        AppSetup.registerIfADatabaseFileExists()

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
        
        guard let threemaDictEntcrypted = bestAttemptContent.userInfo[threemaPayloadKey],
              let threemaDict = PushPayloadDecryptor.decryptPushPayload(threemaDictEntcrypted as? [AnyHashable: Any])
        else {
            notThreemaDictInPayload(bestAttemptContent)
            return
        }
                    
        DDLogInfo("[Push] Request threema push: \(threemaDict)")
        
        let isAliveCheck: Bool = ((threemaDict[aliveCheckKey] as? Int) != nil)
        let isPushTest: Bool = ((threemaDict[pushTestKey] as? Int) != nil)
        let threemaPushNotification = try? ThreemaPushNotification(from: threemaDict as! [String: Any])
        
        guard !isPushTest else {
            // Show test notification (necessary for customer support)
            showTestNotification(bestAttemptContent)
            return
        }
        
        if threemaPushNotification != nil || isAliveCheck {
            
            // Exit if connected already
            if backgroundBusinessInjector.serverConnector.connectionState == .connecting ||
                backgroundBusinessInjector.serverConnector.connectionState == .connected ||
                backgroundBusinessInjector.serverConnector.connectionState == .loggedIn {
                DDLogWarn("[Push] Suppressing push because already connected")
                applyContent()
                return
            }
            
            backgroundBusinessInjector.serverConnector
                .backgroundEntityManagerForMessageProcessing = backgroundBusinessInjector.entityManager
            
            // TODO: (IOS-4677) Shouldn't we always process GC messages?
            if backgroundBusinessInjector.settingsStore.enableThreemaGroupCalls {
                GlobalGroupCallManagerSingleton.injectedBackgroundBusinessInjector = backgroundBusinessInjector
            }
            
            // Refresh all DB objects before access it
            DatabaseManager.db()?.refreshAllObjects()
            backgroundBusinessInjector.entityManager.refreshAll()
            
            backgroundBusinessInjector.contactStore.resetEntityManager()
            
            pendingUserNotificationManager = PendingUserNotificationManager(
                UserNotificationManager(
                    backgroundBusinessInjector.settingsStore,
                    backgroundBusinessInjector.userSettings,
                    backgroundBusinessInjector.myIdentityStore,
                    backgroundBusinessInjector.pushSettingManager,
                    backgroundBusinessInjector.contactStore,
                    backgroundBusinessInjector.groupManager,
                    backgroundBusinessInjector.entityManager,
                    backgroundBusinessInjector.licenseStore.getRequiresLicenseKey()
                ),
                backgroundBusinessInjector.pushSettingManager,
                backgroundBusinessInjector.entityManager
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
            
            // Start processing incoming messages and wait (max. 25s kNSETimeout)
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
                self.backgroundBusinessInjector.serverConnector.registerMessageProcessorDelegate(delegate: self)
                self.backgroundBusinessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
                
                self.backgroundBusinessInjector.serverConnector.connect(initiator: .notificationExtension)
            }
            
            let result = NotificationService.stopProcessingGroup?.wait(timeout: .now() + kNSETimeout)
            if result != .success {
                DDLogWarn("[Push] Stopping processing incoming messages, because time is up!")
                
                if NotificationService.didJustReportCall {
                    DDLogError("[Push] Stopped processing incoming messages, but we were reporting a call!")
                    NotificationService.didJustReportCall = false
                }
            }
            
            backgroundBusinessInjector.serverConnector.unregisterMessageProcessorDelegate(delegate: self)
            backgroundBusinessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
            backgroundBusinessInjector.serverConnector.disconnectWait(initiator: .notificationExtension)
        }
        
        if isAliveCheck {
            let emptyContent = UNMutableNotificationContent()
            emptyContent.userInfo = bestAttemptContent.userInfo
            applyContent(emptyContent)
        }
        else {
            applyContent()
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push
        // payload will be used.
        DDLogWarn("[Push] Stopping processing incoming messages, because extension will expire!")
        exitIfAllTasksProcessed(force: true, willExpire: true)
    }
    
    // MARK: Private functions
    
    /// Apply notification content or suppress it.
    /// For muted groups update badge count here.
    ///
    /// - Parameters:
    ///   - bestAttemptContent: Best content for notification, is nil no notification will be shown
    ///   - recalculateBadgeCount: If `true` count of unread messages will calculated for changed conversations
    ///                            (`NotificationService.conversationsChanged`)
    private func applyContent(
        _ bestAttemptContent: UNMutableNotificationContent? = nil,
        recalculateBadgeCount: Bool = true
    ) {
        NotificationService.isRunning = false
        DDLogNotice("[Push] isRunning set to false from apply.")
        
        var badge = 0
        if recalculateBadgeCount {
            conversationsChangedQueue.sync {
                var recalculateConversations: Set<ConversationEntity>?
                if let conversationsChanged, let conversations = backgroundBusinessInjector.entityManager.entityFetcher
                    .notArchivedConversations() as? [ConversationEntity] {

                    recalculateConversations = Set(conversations.filter { conversationsChanged.contains($0.objectID) })
                }

                if let recalculateConversations, !recalculateConversations.isEmpty {
                    badge = backgroundBusinessInjector.unreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: Set(recalculateConversations))
                }
                else {
                    badge = backgroundBusinessInjector.unreadMessages.totalCount()
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
        
        guard AppSetup.isCompleted else {
            DDLogWarn("[Push] App setup is not completed")
            
            showNoAccessToKeychainLocalNotification {
                self.applyContent(nil, recalculateBadgeCount: false)
            }
            
            MyIdentityStore.resetSharedInstance()
            
            return false
        }

        guard isDBReady(),
              !AppMigrationVersion.isMigrationRequired(userSettings: backgroundBusinessInjector.userSettings) else {
            DDLogWarn("[Push] DB not ready, requires migration")

            ThreemaUtility.showLocalNotification(
                identifier: "ErrorMessage",
                title: "",
                body: #localize("new_message_db_requires_migration"),
                badge: 1,
                userInfo: nil
            ) {
                self.applyContent(nil, recalculateBadgeCount: false)
            }
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
    ///   - willExpire: If function is called from `serviceExtensionTimeWillExpire`
    private func exitIfAllTasksProcessed(force: Bool = false, reportedCall: Bool = false, willExpire: Bool = false) {
        let isMultiDeviceRegistered = backgroundBusinessInjector.settingsStore.isMultiDeviceRegistered
        if force ||
            (
                isChatQueueDry &&
                    (!isMultiDeviceRegistered || (isMultiDeviceRegistered && isReflectionQueueDry)) &&
                    TaskManager.isEmpty()
            ) {
            DDLogNotice(
                "[Push] Stopping process incoming messages (force: \(force), reportedCall: \(reportedCall) willExpire: \(willExpire)), because receive message queue finished or chat/reflection queue is dry!"
            )
            DDLog.flushLog()

            guard !willExpire else {
                NotificationService.stopProcessingTimer?.invalidate()
                NotificationService.didJustReportCall = false
                DDLogNotice("[Push] Leave Processing Group")
                NotificationService.stopProcessingGroup?.leave()
                NotificationService.stopProcessingGroup = nil
                NotificationService.isRunning = false
                DDLogNotice("[Push] isRunning set to false from exit.")
                return
            }
            
            if reportedCall {
                DDLogNotice("[Push] Set didJustReportCall")
                NotificationService.didJustReportCall = reportedCall
            }

            DispatchQueue.main.async {
                NotificationService.stopProcessingTimer?.invalidate()
                NotificationService.stopProcessingTimer = Timer.scheduledTimer(
                    withTimeInterval: 2, // Gives a little time to remove notification from notification center
                    repeats: false,
                    block: { _ in
                        if NotificationService.didJustReportCall {
                            DDLogNotice("[Push] didJustReportCall timer will start")
                            Timer.scheduledTimer(
                                withTimeInterval: 5,
                                repeats: false,
                                block: { _ in
                                    DDLogNotice("[Push] Reset didJustReportCall")
                                    NotificationService.didJustReportCall = false
                                }
                            )
                        }

                        DDLogNotice("[Push] Leave Processing Group")
                        NotificationService.stopProcessingGroup?.leave()
                        NotificationService.stopProcessingGroup = nil
                        NotificationService.isRunning = false
                        DDLogNotice("[Push] isRunning set to false from exit.")
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
        content.body = #localize("new_message_invalid_license")
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
        onCompletion: @escaping ((MessageProcessorDelegate) -> Void),
        onError: @escaping (any Error) -> Void
    ) {
        
        // Check if blocked
        guard let identity,
              !backgroundBusinessInjector.userSettings.blacklist.contains(identity) else {
            onCompletion(self)
            return
        }

        // Call forced exit here with reported call, this set didJustReportCall and prevent adding new tasks within
        // Notification Extension
        exitIfAllTasksProcessed(force: true, reportedCall: true)

        // Remove all incoming tasks. All further messages must be processed by the App
        TaskManager.interrupt()

        // Cancel the actual task processing of Offer message, because this message must be processed from the App
        // again!
        onError(ThreemaProtocolError.doNotProcessOfferMessageInNotificationExtension)

        DDLogNotice("[Push] will Report Incoming VoIP Push Payload to OS.")
        CXProvider.reportNewIncomingVoIPPushPayload(payload) { error in
            if let error {
                DDLogError("[Push] Incoming VoIP Push Payload, system disallow the call: \(error)")
            }
            else {
                DDLogNotice("[Push] Incoming VoIP Push Payload reported")
            }
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
    
    private func showNoAccessToKeychainLocalNotification(onCompletion: @escaping () -> Void) {
        let title = #localize("new_message_no_access_title")
        let message = String.localizedStringWithFormat(
            #localize("new_message_no_access_message"),
            ThreemaApp.appName
        )
        
        ThreemaUtility.showLocalNotification(
            identifier: "ErrorMessage",
            title: title,
            body: message,
            badge: 1,
            userInfo: nil,
            completionHandler: onCompletion
        )
    }
    
    /// Will apply the test message content
    /// - Parameter bestAttemptContent: UNMutableNotificationContent
    private func showTestNotification(_ bestAttemptContent: UNMutableNotificationContent) {
        pendingUserNotificationManager = PendingUserNotificationManager(
            UserNotificationManager(
                backgroundBusinessInjector.settingsStore,
                backgroundBusinessInjector.userSettings,
                backgroundBusinessInjector.myIdentityStore,
                backgroundBusinessInjector.pushSettingManager,
                backgroundBusinessInjector.contactStore,
                backgroundBusinessInjector.groupManager,
                backgroundBusinessInjector.entityManager,
                backgroundBusinessInjector.licenseStore.getRequiresLicenseKey()
            ),
            backgroundBusinessInjector.pushSettingManager,
            backgroundBusinessInjector.entityManager
        )
        
        pendingUserNotificationManager?.startTestUserNotification(
            payload: bestAttemptContent.userInfo,
            completion: {
                DDLogInfo("[Push] Test notification shown!")
                
                let emptyContent = UNMutableNotificationContent()
                bestAttemptContent.badge = 999
                self.applyContent(emptyContent)
            }
        )
    }
    
    /// Will apply a empty content or threema web content (if 3mw is in payload)
    /// - Parameter bestAttemptContent: UNMutableNotificationContent
    private func notThreemaDictInPayload(_ bestAttemptContent: UNMutableNotificationContent) {
        DDLogWarn("[Push] Missing threema key in payload")
        
        pendingUserNotificationManager = PendingUserNotificationManager(
            UserNotificationManager(
                backgroundBusinessInjector.settingsStore,
                backgroundBusinessInjector.userSettings,
                backgroundBusinessInjector.myIdentityStore,
                backgroundBusinessInjector.pushSettingManager,
                backgroundBusinessInjector.contactStore,
                backgroundBusinessInjector.groupManager,
                backgroundBusinessInjector.entityManager,
                backgroundBusinessInjector.licenseStore.getRequiresLicenseKey()
            ),
            backgroundBusinessInjector.pushSettingManager,
            backgroundBusinessInjector.entityManager
        )
        
        if bestAttemptContent.userInfo["3mw"] is [AnyHashable: Any] {
            DDLogInfo("[Push] Configure Threema Web notification")
            // Use applyContent to set the badge with the count of unread messages
            let content = pendingUserNotificationManager?
                .editThreemaWebNotification(payload: bestAttemptContent.userInfo)
            applyContent(content)
        }
        else {
            applyContent()
        }
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
        backgroundBusinessInjector.entityManager.performAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor started for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .abstract
            ) {
                DDLogInfo("[Push] Message processor started for message id: \(msgID) found")
                _ = self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
            }
        }
    }
    
    func incomingMessageChanged(_ message: AbstractMessage, baseMessage: BaseMessage) {
        backgroundBusinessInjector.entityManager.performAndWait {
            if let msg = self.backgroundBusinessInjector.entityManager.entityFetcher
                .getManagedObject(by: baseMessage.objectID) as? BaseMessage {
                let msgID = msg.id?.hexString
                DDLogNotice("[Push] Message processor changed for message id: \(msgID ?? "nil")")

                // Set dirty DB objects for refreshing in the app process
                let databaseManager = DatabaseManager()
                databaseManager.addDirtyObject(msg)
                                                
                if let conversation = msg.conversation {
                    databaseManager.addDirtyObject(conversation)
                    if let contact = conversation.contact {
                        databaseManager.addDirtyObject(contact)
                    }
                    if message is ReactionMessage || message is GroupReactionMessage,
                       let reactions = baseMessage.reactions {
                        for reaction in reactions {
                            databaseManager.addDirtyObject(reaction)
                        }
                    }

                    self.backgroundBusinessInjector.unreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: [conversation])

                    // Add conversation as change to recalculate unread messages
                    self.conversationsChangedQueue.async {
                        self.conversationsChanged?.insert(conversation.objectID)
                    }
                }
                
                if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                    for: message,
                    baseMessage: msg,
                    stage: .base
                ) {
                    DDLogInfo("[Push] Message processor changed for message id: \(msgID ?? "nil") found")
                    _ = self.pendingUserNotificationManager?
                        .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                }
            }
        }
    }
    
    func incomingMessageFinished(_ message: AbstractMessage) {
        backgroundBusinessInjector.entityManager.performAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor finished for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .final
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

    func readMessage(inConversations: Set<ConversationEntity>?) {
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
            stage: .abstract
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        // Remove notification
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .abstract
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?.removeAllTimedUserNotifications(
                pendingUserNotification: pendingUserNotification
            )
        }
        
        // Mark contact & conversation as dirty (1:1 conversation is needed if any status messages were added and the
        // conversation was shown when the app was backgrounded)
        backgroundBusinessInjector.entityManager.performAndWait {
            let databaseManager = DatabaseManager()
            
            if let contactEntity = self.backgroundBusinessInjector.entityManager.entityFetcher.contact(
                for: message.fromIdentity
            ) {
                databaseManager.addDirtyObject(contactEntity)
            }
            
            if let conversation = self.backgroundBusinessInjector.entityManager.entityFetcher.conversationEntity(
                forIdentity: message.fromIdentity
            ) {
                databaseManager.addDirtyObject(conversation)
            }
        }
    }
    
    func taskQueueEmpty() {
        exitIfAllTasksProcessed(force: true)
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
    
    func processTypingIndicator(_ message: TypingIndicatorMessage) { }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: @escaping ((any MessageProcessorDelegate) -> Void),
        onError: @escaping (any Error) -> Void
    ) {
        switch message {
        case is VoIPCallOfferMessage:
            let offerMessage = message as! VoIPCallOfferMessage
            
            guard let identity else {
                DDLogError("No contact for processing VoIP call offer.")
                onCompletion(self) // Discard message
                return
            }
            guard backgroundBusinessInjector.userSettings.enableThreemaCall else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage)
                onCompletion(self) // Discard message
                return
            }
            guard backgroundBusinessInjector.pushSettingManager.canMasterDndSendPush() else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage, rejectReason: .offHours)
                onCompletion(self) // Discard message
                return
            }
            
            let displayName = backgroundBusinessInjector.entityManager.entityFetcher.displayName(for: identity)!
            
            reportVoIPCall(
                for: ["NotificationExtensionOffer": identity, "NotificationExtensionCallerName": displayName],
                message: message as! VoIPCallOfferMessage,
                from: identity,
                onCompletion: onCompletion,
                onError: onError
            )
            
        case let message as VoIPCallHangupMessage:
            CallSystemMessageHelper
                .maybeAddMissedCallNotificationToConversation(
                    with: message,
                    on: backgroundBusinessInjector
                ) { conversation, systemMessage in
                    if let systemMessage, let conversation {
                        let databaseManager = DatabaseManager()
                        databaseManager.addDirtyObject(conversation)
                        databaseManager.addDirtyObject(systemMessage)
                        
                        self.updateNotificationContent(for: message)
                    }
                    
                    onCompletion(self)
                }

        default:
            DDLogError("Message couldn't be processed as VoIP call.")
            onCompletion(self) // Discard message
        }
    }
    
    /// Reject call because Threema Calls are disabled on this device
    /// - Parameter offer: VoIPCallOfferMessage
    /// - Parameter rejectReason: Reject reason (Default: .disabled)
    private func rejectCall(
        offer: VoIPCallOfferMessage,
        rejectReason: VoIPCallAnswerMessage.MessageRejectReason = .disabled
    ) {
        let voIPCallSender = VoIPCallSender(
            messageSender: backgroundBusinessInjector.messageSender,
            myIdentityStore: backgroundBusinessInjector.myIdentityStore
        )
        let reason: VoIPCallAnswerMessage.MessageRejectReason = rejectReason
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
            on: backgroundBusinessInjector
        ) { conversation, systemMessage in
            let databaseManager = DatabaseManager()
            databaseManager.addDirtyObject(conversation)
            databaseManager.addDirtyObject(systemMessage)
            
            self.backgroundBusinessInjector.unreadMessages
                .totalCount(doCalcUnreadMessagesCountOf: [conversation])

            // Add conversation as change to recalculate unread messages
            self.conversationsChangedQueue.async {
                self.conversationsChanged?.insert(conversation.objectID)
            }
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
        
        let contact = backgroundBusinessInjector.entityManager.entityFetcher.contact(for: contactIdentity)
        let notificationType = backgroundBusinessInjector.settingsStore.notificationType
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
        
        content.body = #localize("call_missed")
        
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
                "[Push] Server connection is disconnected (state: \(backgroundBusinessInjector.serverConnector.name(for: state)))) stop processing"
            )

            guard !NotificationService.didJustReportCall else {
                DDLogNotice("[Push] Don't leave after connection state change because we just reported a call.")
                return
            }

            exitIfAllTasksProcessed(force: true)
        }
    }
}
