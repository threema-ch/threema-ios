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
import ThreemaFramework
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    private static var isRunning = false
    private static var didJustReportCall = false

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    private lazy var businessInjector = BusinessInjector()
    private var pendingUserNotificationManager: PendingUserNotificationManagerProtocol?

    private static var stopProcessingTimer: Timer?
    private static var stopProcessingGroup = DispatchGroup()

    private var isChatQueueDry = false
    private var isReflectionQueueDry = false
    
    private let threemaPayloadKey = "threema"
    private let aliveCheckKey = "alive-check"

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        PromiseKitConfiguration.configurePromiseKit()
        
        guard !NotificationService.didJustReportCall else {
            businessInjector.serverConnector.disconnect(initiator: .notificationExtension)
            
            DDLogNotice("[Push] Suppressing push because we have just reported an incoming call")
            self.contentHandler = contentHandler
            applyContent()
            return
        }
        
        // Make timer invalid, to prevent stopping processing
        DispatchQueue.main.async {
            NotificationService.stopProcessingTimer?.invalidate()
        }

        guard !NotificationService.isRunning else {
            return
        }
        NotificationService.isRunning = true

        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        AppGroup.setAppID(BundleUtil.mainBundle()?.bundleIdentifier)
        
        // Initialize app setup state (checking database file exists) as early as possible
        _ = AppSetupState()
        
        #if DEBUG
            LogManager.initializeGlobalLogger(debug: true)
        #else
            LogManager.initializeGlobalLogger(debug: false)
        #endif
        
        AppGroup.setActive(true, for: AppGroupTypeNotificationExtension)
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)

        DDLogNotice("[Push] Notification did receive: \(request.content)")
        
        logMemoryUsage()

        // Drop shared instance in order to adapt to user's configuration changes
        UserSettings.resetSharedInstance()

        // Initialize content handler to show any notification
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if extensionIsReady() {
            if let bestAttemptContent = bestAttemptContent,
               let threemaDictEntcrypted = bestAttemptContent.userInfo[threemaPayloadKey],
               let threemaDict = PushPayloadDecryptor.decryptPushPayload(threemaDictEntcrypted as? [AnyHashable: Any]) {
                
                DDLogInfo("[Push] Request threema push: \(threemaDict)")
                                
                let isAliveCheck: Bool = ((threemaDict[aliveCheckKey] as? Int) != nil)
                let threemaPushNotification = try? ThreemaPushNotification(from: threemaDict as! [String: Any])
                
                if threemaPushNotification != nil || isAliveCheck {

                    // Exit if connected already
                    if businessInjector.serverConnector.connectionState == .connecting || ServerConnector.shared()
                        .connectionState == .loggedIn {
                        DDLogWarn("[Push] Already connected")
                        return
                    }

                    businessInjector.serverConnector.businessInjectorForMessageProcessing = businessInjector

                    // Caution: DB main context reset when start Notification Extension,
                    // because the context can become corrupt and don't save any data anymore.
                    DatabaseContext.reset()
                    
                    // Refresh all DB objects before access it
                    DatabaseManager.db()?.refreshAllObjects()
                    businessInjector.backgroundEntityManager.refreshAll()

                    businessInjector.contactStore.resetEntityManager()

                    pendingUserNotificationManager = PendingUserNotificationManager(
                        UserNotificationManager(
                            businessInjector.userSettings,
                            businessInjector.contactStore,
                            businessInjector.backgroundGroupManager,
                            businessInjector.backgroundEntityManager,
                            businessInjector.licenseStore.getRequiresLicenseKey()
                        ),
                        businessInjector.backgroundEntityManager
                    )
                    
                    // Create pendingUserNotification only for message notifications, not for keep alive checks
                    // Keep alive check will connect to the server, because if the last connection was too long ago, the server sets the identity as inactive
                    var baseMessage: BaseMessage?
                    if let threemaPushNotification = threemaPushNotification {
                        if threemaPushNotification.voip == false {
                            baseMessage = messageAlreadyInDB(threemaPushNotification.messageID)
                            if let baseMessage = baseMessage,
                               let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
                                   for: baseMessage,
                                   fromIdentity: threemaPushNotification.from,
                                   stage: .base
                               ) {
                                _ = pendingUserNotificationManager?
                                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                            }
                            else if let pendingUserNotification = pendingUserNotificationManager?
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

                    // do not connect to the server if message is already in the database
                    if baseMessage == nil {
                        // Start processing incoming messages and wait (max. 25s)
                        DDLogNotice("[Push] Enter the stopProcessingGroup")
                        NotificationService.stopProcessingGroup.enter()

                        // We observe for invalid license
                        NotificationCenter.default.addObserver(
                            forName: NSNotification.Name(rawValue: kNotificationLicenseMissing),
                            object: nil,
                            queue: nil
                        ) { [weak self] _ in
                            self?.addInvalidLicenseKeyNotification(removingInitialPushFor: threemaPushNotification)
                        }
                        
                        DispatchQueue.global().async {
                            // Register message processor delegate and connect to server
                            self.businessInjector.serverConnector.registerMessageProcessorDelegate(delegate: self)
                            self.businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
                            
                            self.businessInjector.serverConnector.connect(initiator: .notificationExtension)
                        }

                        let result = NotificationService.stopProcessingGroup.wait(timeout: .now() + 25)
                        if result != .success {
                            DDLogWarn("[Push] Stopping processing incoming messages, because time is up!")
                            if NotificationService.didJustReportCall {
                                DDLogError("[Push] Stopped processing incoming messages, but we were reporting a call!")
                                NotificationService.didJustReportCall = false
                            }
                        }

                        businessInjector.serverConnector.unregisterMessageProcessorDelegate(delegate: self)
                        businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
                        businessInjector.serverConnector.disconnect(initiator: .notificationExtension)
                    }
                }
                
                applyContent()
            }
            else {
                DDLogWarn("[Push] Message ID is missing")

                if let bestAttemptContent = bestAttemptContent {
                    // Show test notification (necessary for customer support)
                    pendingUserNotificationManager = PendingUserNotificationManager(
                        UserNotificationManager(
                            businessInjector.userSettings,
                            businessInjector.contactStore,
                            businessInjector.backgroundGroupManager,
                            businessInjector.backgroundEntityManager,
                            businessInjector.licenseStore.getRequiresLicenseKey()
                        ),
                        businessInjector.backgroundEntityManager
                    )
                    
                    if bestAttemptContent.userInfo["3mw"] is [AnyHashable: Any] {
                        DDLogInfo("[Push] Configure Threema Web notification")
                        pendingUserNotificationManager?.editThreemaWebNotification(
                            payload: bestAttemptContent.userInfo,
                            completion: { content in
                                // Use applyContent to set the badge with the count of unread messages
                                self.applyContent(content)
                            }
                        )
                    }
                    else {
                        pendingUserNotificationManager?.startTestUserNotification(
                            payload: bestAttemptContent.userInfo,
                            completion: {
                                let emptyContent = UNMutableNotificationContent()
                                bestAttemptContent.badge = 999
                                self.contentHandler?(emptyContent)
                                
                                DDLogInfo("[Push] Test notification showed!")
                            }
                        )
                    }
                }
            }
        }
        else {
            DDLogWarn("[Push] Extension not ready")
        }

        logMemoryUsage()

        AppGroup.setActive(false, for: AppGroupTypeNotificationExtension)
        DDLog.flushLog()

        NotificationService.isRunning = false
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        DDLogWarn("[Push] Stopping processing incoming messages, because extension will expire!")
        exitIfAllTasksProcessed(force: true)
    }
    
    // MARK: Private functions
    
    /// Looking for message in DB.
    ///
    /// - Parameter messageID: Message ID
    /// - Returns: Message found otherwise nil
    @discardableResult private func messageAlreadyInDB(_ messageID: String) -> BaseMessage? {
        guard let id = BytesUtility.toBytes(hexString: messageID) else {
            return nil
        }

        var message: BaseMessage?
        businessInjector.backgroundEntityManager.performBlockAndWait {
            message = self.businessInjector.backgroundEntityManager.entityFetcher.message(with: Data(id))
        }
        return message
    }
    
    /// Apply notification content or suppress it.
    /// For muted groups update badge count here.
    ///
    /// - Parameters:
    ///   - bestAttemptContent: Best content for notification, is nil no notification will be showed
    private func applyContent(_ bestAttemptContent: UNMutableNotificationContent? = nil) {

        var badge = 0
        if let conversations = businessInjector.backgroundEntityManager.entityFetcher
            .notArchivedConversations() as? [Conversation] {
            badge = businessInjector.backgroundUnreadMessages.totalCount(doCalcUnreadMessagesCountOf: conversations)
        }
        else {
            badge = businessInjector.backgroundUnreadMessages.totalCount()
        }
        DDLogNotice("[Push] Unread messages: \(badge)")

        if let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.badge = NSNumber(integerLiteral: badge)
            contentHandler?(bestAttemptContent)

            DDLogInfo("[Push] Notification showed!")
        }
        else {
            let emptyContent = UNMutableNotificationContent()
            emptyContent.badge = NSNumber(integerLiteral: badge)
            contentHandler?(emptyContent)

            DDLogInfo("[Push] Notification suppressed!")
        }
    }

    private func extensionIsReady() -> Bool {
        let appSetupSate = AppSetupState(myIdentityStore: MyIdentityStore.shared())
        guard appSetupSate.isAppSetupCompleted() else {
            DDLogWarn("[Push] App setup is not completed")
            return false
        }

        guard isDBReady(), !AppMigrationVersion.isMigrationRequired(userSettings: businessInjector.userSettings) else {
            DDLogWarn("[Push] DB not ready, requires migration")

            let content = UNMutableNotificationContent()
            content.body = BundleUtil.localizedString(forKey: "new_message_db_requires_migration")
            contentHandler?(content)

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
    /// - Parameter force: Means last incoming task is processed, exit anyway
    private func exitIfAllTasksProcessed(force: Bool = false, reportedCall: Bool = false) {
        let isMultiDeviceActivated = ServerConnector.shared().isMultiDeviceActivated
        if force ||
            (
                isChatQueueDry &&
                    (!isMultiDeviceActivated || (isMultiDeviceActivated && isReflectionQueueDry)) &&
                    TaskManager.isEmpty(queueType: .incoming)
            ) {
            DDLogNotice(
                "[Push] Stopping processing incoming messages, because receive message queue finished or chat/reflection queue is dry!"
            )
            DDLog.flushLog()

            // Gives a little time to remove notification from notification center
            // or has pending group messages (waiting for possible "group sync request" answer)
            var delay: Double = 2
            if let pendingUserNotificationManager = pendingUserNotificationManager,
               pendingUserNotificationManager.hasPendingGroupUserNotifications() {
                DDLogNotice("Push] Delay timeout for bc. has Pending notifications")
                delay = 5
            }
            else if reportedCall {
                DDLogNotice("Push] Delay timeout for incoming call")
                delay = 5
                NotificationService.didJustReportCall = reportedCall
            }

            DispatchQueue.main.sync {
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
                        NotificationService.stopProcessingGroup.leave()
                    }
                )
            }
        }
    }

    @objc private func addInvalidLicenseKeyNotification(
        removingInitialPushFor threemaPushNotification: ThreemaPushNotification?
    ) {
        DDLogWarn("[Push] Show invalid license key notification")
        
        // We remove the pending notification if it exists
        if let threemaPushNotification = threemaPushNotification,
           let pendingUserNotification = (
               pendingUserNotificationManager?
                   .pendingUserNotification(for: threemaPushNotification, stage: .initial)
           ) {
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
        
        let content = UNMutableNotificationContent()
        content.body = BundleUtil.localizedString(forKey: "new_message_invalid_license")
        
        applyContent(content)
        DDLogNotice("[Push] Left the stopProcessingGroup because there is no valid license")
        DDLog.flushLog()
        NotificationService.stopProcessingGroup.leave()
    }
    
    @available(iOSApplicationExtension 15, *)
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
        guard let identity = identity,
              !businessInjector.userSettings.blacklist.contains(identity) else {
            onCompletion?(self)
            return
        }
        DDLogNotice("[Push] will Report Incoming VoIP Push Payload to OS.")
        CXProvider.reportNewIncomingVoIPPushPayload(payload) { _ in
            DDLogNotice("[Push] Incoming VoIP Push Payload reported, leaving queue now.")
            DDLogNotice("[Push] Left the stopProcessingGroup for incoming call")
            
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
            let msgID = message.id.hexString
            DDLogNotice("[Push] Message processor changed for message id: \(msgID)")
        
            // Set dirty DB objects for refreshing in the app process
            let databaseManager = DatabaseManager()
            databaseManager.addDirtyObject(message)
            if let conversation = message.conversation {
                databaseManager.addDirtyObject(conversation)
                if let contact = conversation.contact {
                    databaseManager.addDirtyObject(contact)
                }
            }

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                fromIdentity: fromIdentity,
                stage: .base
            ) {
                DDLogInfo("[Push] Message processor changed for message id: \(msgID) found")
                _ = self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
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
                DDLogInfo("[Push] Message processor finished for message id: \(msgID) found")
                self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done { showed in
                        if showed {
                            self.pendingUserNotificationManager?
                                .addAsProcessed(pendingUserNotification: pendingUserNotification)
                        }

                        DDLogNotice("[Push] Notification processed for message id: \(msgID)")
                    }
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
    
    func taskQueueEmpty(_ queueTypeName: String) {
        let queueType = TaskQueueType.queue(name: queueTypeName)
        if queueType == .incoming {
            exitIfAllTasksProcessed(force: true)
        }
    }
    
    func outgoingMessageFinished(_ message: AbstractMessage) { }
    
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
            guard let identity = identity else {
                DDLogError("No contact for processing VoIP call offer.")
                onCompletion?(self)
                return
            }
            if #available(iOSApplicationExtension 15, *) {
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
            }
        default:
            onCompletion?(self)
            DDLogError("Message couldn't be processed as VoIP call.")
        }
    }
    
    private func rejectCall(offer: VoIPCallOfferMessage) {
        let voIPCallSender = VoIPCallSender(businessInjector.myIdentityStore)
        var reason: VoIPCallAnswerMessage.MessageRejectReason = .disabled
        let answer = VoIPCallAnswerMessage(
            action: .reject,
            contactIdentity: offer.contactIdentity,
            answer: nil,
            rejectReason: reason,
            features: nil,
            isVideoAvailable: false,
            callID: offer.callID,
            completion: nil
        )
        voIPCallSender.sendVoIPCall(answer: answer)
        addRejectedMessageToConversation(contactIdentity: offer.contactIdentity!, reason: kSystemMessageCallMissed)
    }
    
    private func addRejectedMessageToConversation(contactIdentity: String, reason: Int) {
        var systemMessage: SystemMessage?

        businessInjector.backgroundEntityManager.performSyncBlockAndSafe {
            if let conversation = self.businessInjector.backgroundEntityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: true
            ) {
                systemMessage = self.businessInjector.backgroundEntityManager.entityCreator
                    .systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: reason)
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: false),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage?.arg = callInfoData
                    systemMessage?.isOwn = NSNumber(booleanLiteral: false)
                    systemMessage?.conversation = conversation
                    conversation.lastMessage = systemMessage
                    if reason == kSystemMessageCallMissed {
                        conversation.lastUpdate = Date.now
                    }

                    let databaseManager = DatabaseManager()
                    databaseManager.addDirtyObject(conversation)
                    databaseManager.addDirtyObject(systemMessage)
                }
                catch {
                    print(error)
                }
            }
            else {
                DDLogNotice("Threema Calls: Can't add rejected message because conversation is nil")
            }
        }
    }
}

// MARK: - ConnectionStateDelegate

extension NotificationService: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        if state == .disconnecting || state == .disconnected {
            DDLogNotice("[Push] Left the stopProcessingGroup because connection is \(state.rawValue)")
            
            guard !NotificationService.didJustReportCall else {
                DDLogNotice("[Push] Don't leave after connection state change because we just reported a call.")
                return
            }
            
            exitIfAllTasksProcessed(force: true)
        }
    }
}
