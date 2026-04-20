import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

final class NotificationResponse {

    private let businessInjector: BusinessInjectorProtocol
    private let notificationManager: NotificationManager

    private let threemaDict: [AnyHashable: Any]?
    private let categoryIdentifier: String
    private let actionIdentifier: String
    private var userText: String?
    private var identity: String?
    private var messageID: String?

    private let userInfo: [AnyHashable: Any]

    private let notificationIdentifier: String
    private let completionHandler: () -> Void

    private var conversation: ConversationEntity?

    required init(
        businessInjector: BusinessInjectorProtocol,
        notificationManager: NotificationManager,
        response: UNNotificationResponse,
        completion: @escaping (() -> Void)
    ) {
        self.businessInjector = businessInjector
        self.notificationManager = notificationManager

        if let tmpThreemaDict = response.notification.request.content.userInfo["threema"] as? [AnyHashable: Any] {
            self.threemaDict = PushPayloadDecryptor.decryptPushPayload(tmpThreemaDict)
            self.categoryIdentifier = response.notification.request.content.categoryIdentifier
            self.actionIdentifier = response.actionIdentifier
            self.completionHandler = completion
            self.userInfo = response.notification.request.content.userInfo
            if let mid = threemaDict!["messageId"] as? String {
                self.messageID = mid
                self.notificationIdentifier = "\(kAppPushReplyBackgroundTask)\(messageID!)"
            }
            else {
                self.notificationIdentifier = kAppPushReplyBackgroundTask
            }

            let entityManager = businessInjector.entityManager

            if let threemaDict, let groupIDString = threemaDict["groupId"] as? String,
               let groupCreator = threemaDict["groupCreator"] as? String,
               let groupID = Data(base64Encoded: groupIDString) {
                self.conversation = entityManager.entityFetcher.groupConversationEntity(
                    for: groupID,
                    creatorID: groupCreator,
                    myIdentity: businessInjector.myIdentityStore.identity
                )
            }
            else if let threemaDict, let senderIdentity = threemaDict["from"] as? String {
                self.conversation = entityManager.entityFetcher.conversationEntity(for: senderIdentity)
            }
            else {
                DDLogError("Could not find conversation for push notification")
            }

            self.identity = response.notification.request.identifier

            if let replyText = (response as? UNTextInputNotificationResponse)?.userText {
                self.userText = replyText
            }
        }
        else {
            self.threemaDict = nil
            self.categoryIdentifier = response.notification.request.content.categoryIdentifier
            self.actionIdentifier = response.actionIdentifier
            self.userInfo = response.notification.request.content.userInfo
            self.notificationIdentifier = kAppPushReplyBackgroundTask
            self.completionHandler = completion
        }
    }

    @objc convenience init(response: UNNotificationResponse, completion: @escaping (() -> Void)) {
        let businessInjector = BusinessInjector.ui
        self.init(
            businessInjector: businessInjector,
            notificationManager: NotificationManager(businessInjector: businessInjector),
            response: response,
            completion: completion
        )
    }

    @objc func handleNotificationResponse() {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: notificationIdentifier,
            timeout: Int(kAppPushReplyBackgroundTaskTime)
        ) {
            // connect all running sessions
            if WCSessionManager.shared.isRunningWCSession() {
                DDLogNotice("[Threema Web] handleNotificationResponse --> connect all running sessions")
            }
            WCSessionManager.shared.connectAllRunningSessions()
            
            self.handleResponse()
        }
    }

    private func handleResponse() {
        if categoryIdentifier == NotificationActionProvider
            .Category.singleCategory.rawValue || categoryIdentifier == NotificationActionProvider.Category.groupCategory
            .rawValue {

            if !businessInjector.userSettings.ipcCommunicationEnabled {
                AppGroup.setMeActive()
            }

            if actionIdentifier == NotificationActionProvider.Action.replyAction.rawValue {
                handleReplyMessage()
            }
            else if NotificationActionProvider.Action.isEmojiAction(identifier: actionIdentifier) {
                handleEmojiReply(identifier: actionIdentifier)
            }
            else {
                notificationManager.handleThreemaNotification(
                    payload: userInfo,
                    receivedWhileRunning: AppDelegate.shared().active
                )
            }
        }
        else if categoryIdentifier == NotificationActionProvider.Category.callCategory.rawValue {
            if actionIdentifier == NotificationActionProvider.Action.replyAction.rawValue {
                handleReplyMessageToMissedCaller()
            }
            else if actionIdentifier == NotificationActionProvider.Action.callBackAction.rawValue {
                handleCallMessage()
            }
            else {
                notificationManager.handleThreemaNotification(
                    payload: userInfo,
                    receivedWhileRunning: AppDelegate.shared().active
                )
                finishResponse()
            }
        }
        else if categoryIdentifier == "SAFE_SETUP" {
            handleSafeSetup()
            finishResponse()
        }
        else {
            notificationManager.handleThreemaNotification(payload: userInfo, receivedWhileRunning: false)
            finishResponse()
        }
    }

    private func finishResponse() {
        BackgroundTaskManager.shared.cancelBackgroundTask(key: notificationIdentifier)
        DispatchQueue.main.async {
            self.completionHandler()
        }
    }

    private func handleReplyMessage() {
        guard let userText else {
            finishResponse()
            return
        }
        
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .notificationHandler, timeout: 20) {
            Task { @MainActor in
                if let messageID = self.messageID, let conversation = self.conversation,
                   let baseMessage = self.businessInjector.entityManager.entityFetcher.message(
                       with: messageID.decodeHex(),
                       in: conversation
                   ) {
                    let conversation = baseMessage.conversation
                    if !baseMessage.isGroupMessage,
                       let contact = conversation.contact {

                        await self.updateMessageAsRead(for: baseMessage)
                        await self.businessInjector.messageSender.sendReadReceipt(
                            for: [baseMessage],
                            toIdentity: contact.threemaIdentity
                        )
                    }

                    let _ = await self.businessInjector.messageSender.sendTextMessage(
                        containing: userText,
                        in: conversation,
                        sendProfilePicture: false
                    )
                }
                else {
                    self.sendReplyError()
                }

                self.finishResponse()
            }
        } onTimeout: {
            self.sendReplyError()
            self.finishResponse()
        }
    }

    private func handleReplyMessageToMissedCaller() {
        guard let userText else {
            finishResponse()
            return
        }

        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .notificationHandler, timeout: 20) {
            Task { @MainActor in
                if let conversation = self.conversation {
                    _ = await self.businessInjector.messageSender.sendTextMessage(
                        containing: userText,
                        in: conversation,
                        sendProfilePicture: false
                    )
                }
                else {
                    self.sendReplyError()
                }

                self.finishResponse()
            }
        } onTimeout: {
            self.sendReplyError()
            self.finishResponse()
        }
    }

    private func handleEmojiReply(identifier: String) {
        guard let emoji = NotificationActionProvider.Action.emoji(for: identifier) else {
            sendReactionError()
            finishResponse()
            return
        }
        
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .notificationHandler, timeout: 20) {
            guard let messageID = self.messageID, let conversation = self.conversation else {
                self.sendReactionError()
                self.finishResponse()
                return
            }

            Task { @MainActor in
                let entityManager = self.businessInjector.entityManager
                let (messageObjectID, isGroupMessage, baseMessage):
                    (NSManagedObjectID?, Bool, BaseMessageEntity?) = await entityManager.perform {
                        let baseMessage = entityManager.entityFetcher.message(
                            with: messageID.decodeHex(),
                            in: conversation
                        )
                        return (baseMessage?.objectID, baseMessage?.isGroupMessage ?? false, baseMessage)
                    }

                guard let messageObjectID, let baseMessage else {
                    self.sendReactionError()
                    self.finishResponse()
                    return
                }

                if !isGroupMessage,
                   let contact = conversation.contact {

                    await self.updateMessageAsRead(for: baseMessage)
                    await self.businessInjector.messageSender.sendReadReceipt(
                        for: [baseMessage],
                        toIdentity: contact.threemaIdentity
                    )
                }

                do {
                    let result = try await self.businessInjector.messageSender.sendReaction(
                        to: messageObjectID,
                        reaction: emoji
                    )
                    
                    if result != .success {
                        self.sendReactionError()
                    }
                }
                catch {
                    DDLogError("[NotificationResponse] Could not send reaction: \(error)")
                    self.sendReactionError()
                }

                self.finishResponse()
            }
        } onTimeout: {
            self.sendReactionError()
            self.finishResponse()
        }
    }
    
    private func sendReplyError() {
        ThreemaUtilityObjC.sendErrorLocalNotification(
            #localize("send_notification_message_error_title"),
            body: #localize("send_notification_message_error_failed"),
            userInfo: userInfo
        )
    }
    
    private func sendReactionError() {
        ThreemaUtilityObjC.sendErrorLocalNotification(
            #localize("send_notification_reaction_error_title"),
            body: #localize("send_notification_reaction_error_body"),
            userInfo: userInfo
        )
    }

    private func handleCallMessage() {
        guard let identity else {
            finishResponse()
            return
        }

        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .notificationExtension, timeout: 20) {
            if let contact = self.businessInjector.entityManager.entityFetcher.contactEntity(for: identity) {
                VoIPCallStateManager.shared.startCall(callee: contact.identity) {
                    self.finishResponse()
                }
            }
            else {
                self.finishResponse()
            }
        } onTimeout: {
            self.finishResponse()
        }
    }

    private func handleSafeSetup() {
        let safeConfig = SafeConfigManager()
        let safeManager = SafeManager(
            safeConfigManager: safeConfig,
            safeStore: SafeStore(
                safeConfigManager: safeConfig,
                serverApiConnector: ServerAPIConnector(),
                groupManager: businessInjector.groupManager,
                myIdentityStore: businessInjector.myIdentityStore
            ),
            safeAPIService: SafeApiService()
        )

        if safeManager.isActivated {
            NotificationCenter.default.post(name: Notification.Name(kSafeSetupUI), object: nil)
        }
    }

    /// Update message read.
    /// - Parameter message: Message to set read true
    private func updateMessageAsRead(for message: BaseMessageEntity) async {
        await businessInjector.entityManager.performSave {
            message.read = NSNumber(booleanLiteral: true)
            message.readDate = Date()
            DDLogVerbose("Message marked as read: \(message.id.hexString)")
        }
        notificationManager.updateUnreadMessagesCount(baseMessage: message)
    }
}
