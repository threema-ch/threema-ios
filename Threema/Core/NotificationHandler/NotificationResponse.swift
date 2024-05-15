//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

class NotificationResponse: NSObject {

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

    private var conversation: Conversation?

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

            let entityManager = EntityManager()

            if let threemaDict, let groupIDString = threemaDict["groupId"] as? String,
               let groupCreator = threemaDict["groupCreator"] as? String,
               let groupID = Data(base64Encoded: groupIDString) {
                self.conversation = entityManager.entityFetcher.conversation(for: groupID, creator: groupCreator)
            }
            else if let threemaDict, let senderIdentity = threemaDict["from"] as? String {
                self.conversation = entityManager.entityFetcher.conversation(forIdentity: senderIdentity)
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
        let businessInjector = BusinessInjector()
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
                ValidationLogger.shared()?
                    .logString("[Threema Web] handleNotificationResponse --> connect all running sessions")
            }
            WCSessionManager.shared.connectAllRunningSessions()
            
            self.handleResponse()
        }
    }

    private func handleResponse() {
        if categoryIdentifier == "SINGLE" || categoryIdentifier == "GROUP" {
            AppGroup.setActive(false, for: AppGroupTypeNotificationExtension)
            AppGroup.setActive(false, for: AppGroupTypeShareExtension)

            if actionIdentifier == "THUMB_UP" {
                businessInjector.serverConnector.connect(initiator: .notificationHandler)
                handleThumbUp()
            }
            else if actionIdentifier == "THUMB_DOWN" {
                businessInjector.serverConnector.connect(initiator: .notificationHandler)
                handleThumbDown()
            }
            else if actionIdentifier == "REPLY_MESSAGE" {
                businessInjector.serverConnector.connect(initiator: .notificationHandler)
                handleReplyMessage()
            }
            else {
                businessInjector.serverConnector.connect(initiator: .app)
                notificationManager.handleThreemaNotification(
                    payload: userInfo,
                    receivedWhileRunning: AppDelegate.shared().active
                )
                finishResponse()
            }
        }
        else if categoryIdentifier == "CALL" {
            if actionIdentifier == "REPLY_MESSAGE" {
                handleReplyMessage()
            }
            else if actionIdentifier == "CALL" {
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
        else if categoryIdentifier == "INCOMCALL" {
            if actionIdentifier == "ACCEPTCALL" {
                handleAcceptCall()
            }
            else if actionIdentifier == "REJECTCALL" {
                handleRejectCall()
            }
            else {
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

    private func handleThumbUp() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            guard let messageID = self.messageID, let conversation = self.conversation,
                  let baseMessage = self.businessInjector.entityManager.entityFetcher.message(
                      with: messageID.decodeHex(),
                      conversation: conversation
                  ),
                  let conversation = baseMessage.conversation else {
                self.sendThumbUpError()
                self.finishResponse()
                return
            }
           
            let isGroup = conversation.isGroup()
            
            if isGroup {
                if let groupDeliveryReceipts = baseMessage.groupDeliveryReceipts,
                   !groupDeliveryReceipts.isEmpty,
                   baseMessage.isMyReaction(.acknowledged) {
                    self.finishResponse()
                    return
                }

                if let group = self.businessInjector.groupManager.getGroup(conversation: conversation) {
                    Task {
                        await self.businessInjector.messageSender.sendReadReceipt(
                            for: [baseMessage],
                            toGroupIdentity: group.groupIdentity
                        )
                        await self.businessInjector.messageSender.sendUserAck(for: baseMessage, toGroup: group)
                        self.updateMessageAsRead(for: baseMessage)
                        self.finishResponse()
                    }
                }
            }
            else {
                guard let identity = conversation.contact?.threemaIdentity else {
                    self.sendThumbUpError()
                    self.finishResponse()
                    return
                }
                // Only send changed acks
                if baseMessage.userackDate != nil, let currentAck = baseMessage.userack, currentAck.boolValue {
                    self.finishResponse()
                    return
                }
                Task {
                    await self.businessInjector.messageSender.sendReadReceipt(for: [baseMessage], toIdentity: identity)
                    await self.businessInjector.messageSender.sendUserAck(for: baseMessage, toIdentity: identity)
                    self.updateMessageAsRead(for: baseMessage)
                    self.finishResponse()
                }
            }
            
        }) {
            self.sendThumbUpError()
            self.finishResponse()
        }
    }
    
    private func sendThumbUpError() {
        ThreemaUtilityObjC.sendErrorLocalNotification(
            BundleUtil.localizedString(forKey: "send_notification_message_error_title"),
            body: BundleUtil.localizedString(forKey: "send_notification_message_error_agree"),
            userInfo: userInfo
        )
    }

    private func handleThumbDown() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            guard let messageID = self.messageID, let conversation = self.conversation,
                  let baseMessage = self.businessInjector.entityManager.entityFetcher.message(
                      with: messageID.decodeHex(),
                      conversation: conversation
                  ),
                  let conversation = baseMessage.conversation else {
                self.sendThumbDownError()
                self.finishResponse()
                return
            }
           
            if conversation.isGroup() {
                if let groupDeliveryReceipts = baseMessage.groupDeliveryReceipts,
                   !groupDeliveryReceipts.isEmpty,
                   baseMessage.isMyReaction(.declined) {
                    self.finishResponse()
                    return
                }
                
                if let group = self.businessInjector.groupManager.getGroup(conversation: conversation) {
                    Task {
                        await self.businessInjector.messageSender.sendReadReceipt(
                            for: [baseMessage],
                            toGroupIdentity: group.groupIdentity
                        )
                        await self.businessInjector.messageSender.sendUserDecline(for: baseMessage, toGroup: group)
                        self.updateMessageAsRead(for: baseMessage)
                        self.finishResponse()
                    }
                }
            }
            else {
                guard let contact = conversation.contact else {
                    self.sendThumbDownError()
                    self.finishResponse()
                    return
                }
                // Only send changed acks
                if baseMessage.userackDate != nil, let currentAck = baseMessage.userack, !currentAck.boolValue {
                    self.finishResponse()
                    return
                }

                Task {
                    await self.businessInjector.messageSender.sendReadReceipt(
                        for: [baseMessage],
                        toIdentity: contact.threemaIdentity
                    )
                    await self.businessInjector.messageSender.sendUserDecline(
                        for: baseMessage,
                        toIdentity: contact.threemaIdentity
                    )
                    self.updateMessageAsRead(for: baseMessage)
                    self.finishResponse()
                }
            }
        }) {
            self.sendThumbDownError()
            self.finishResponse()
        }
    }
    
    private func sendThumbDownError() {
        ThreemaUtilityObjC.sendErrorLocalNotification(
            BundleUtil.localizedString(forKey: "send_notification_message_error_title"),
            body: BundleUtil.localizedString(forKey: "send_notification_message_error_disagree"),
            userInfo: userInfo
        )
    }

    private func handleReplyMessage() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            let businessInjector = BusinessInjector()
            
            if let messageID = self.messageID, let conversation = self.conversation,
               let baseMessage = businessInjector.entityManager.entityFetcher.message(
                   with: messageID.decodeHex(),
                   conversation: conversation
               ),
               let conversation = baseMessage.conversation {

                if !baseMessage.isGroupMessage,
                   let contact = conversation.contact {
                    Task { @MainActor in
                        await self.businessInjector.messageSender.sendReadReceipt(
                            for: [baseMessage],
                            toIdentity: contact.threemaIdentity
                        )
                        self.updateMessageAsRead(for: baseMessage)
                        self.sendUserText(
                            text: self.userText,
                            conversation: conversation,
                            isConnectionEstablished: true
                        )
                    }
                }
                else {
                    self.updateMessageAsRead(for: baseMessage)
                    self.sendUserText(text: self.userText, conversation: conversation, isConnectionEstablished: true)
                }
            }
            else {
                self.sendReplyError()
                self.finishResponse()
            }
        }) {
            if let messageID = self.messageID, let conversation = self.conversation,
               let baseMessage = self.businessInjector.entityManager.entityFetcher.message(
                   with: messageID.decodeHex(),
                   conversation: conversation
               ),
               let conversation = baseMessage.conversation {
                
                self.updateMessageAsRead(for: baseMessage)
                self.sendUserText(text: self.userText, conversation: conversation, isConnectionEstablished: false)
            }
            else {
                self.sendReplyError()
                self.finishResponse()
            }
        }
    }
    
    private func sendUserText(text: String?, conversation: Conversation, isConnectionEstablished: Bool) {
        let trimmedMessages = ThreemaUtilityObjC.getTrimmedMessages(text) as? [String]

        if trimmedMessages == nil {
            let trimmedMessageData = Data(userText!.utf8)
            if trimmedMessageData.count > Int(kMaxMessageLen) {
                sendReplyError()
                finishResponse()
                return
            }

            businessInjector.messageSender.sendTextMessage(
                text: text,
                in: conversation,
                quickReply: true,
                requestID: nil,
                completion: { _ in
                    if !isConnectionEstablished {
                        self.sendReplyError()
                    }
                    self.finishResponse()
                }
            )
        }
        else {
            for (index, object) in trimmedMessages!.enumerated() {
                businessInjector.messageSender.sendTextMessage(
                    text: object,
                    in: conversation,
                    quickReply: true,
                    requestID: nil,
                    completion: { _ in
                        if index == trimmedMessages!.count - 1 {
                            if !isConnectionEstablished {
                                self.sendReplyError()
                            }
                            self.finishResponse()
                            return
                        }
                    }
                )
            }
        }
    }

    private func sendReplyError() {
        ThreemaUtilityObjC.sendErrorLocalNotification(
            BundleUtil.localizedString(forKey: "send_notification_message_error_title"),
            body: BundleUtil.localizedString(forKey: "send_notification_message_error_failed"),
            userInfo: userInfo
        )
    }

    private func handleCallMessage() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            if let contact = self.businessInjector.entityManager.entityFetcher.contact(for: self.identity!) {
                var callID: VoIPCallID?
                if let threemaDict = self.threemaDict {
                    if let tmpCallID = threemaDict["callId"] {
                        callID = VoIPCallID(callID: tmpCallID as? UInt32)
                    }
                }

                let action = VoIPCallUserAction(
                    action: .call,
                    contactIdentity: contact.identity,
                    callID: callID,
                    completion: {
                        self.finishResponse()
                    }
                )
                VoIPCallStateManager.shared.processUserAction(action)
            }
            else {
                self.finishResponse()
                return
            }
        }) {
            self.finishResponse()
        }
    }

    private func handleAcceptCall() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            if let contact = self.businessInjector.entityManager.entityFetcher.contact(for: self.identity!) {
                var callID: VoIPCallID?
                if let threemaDict = self.threemaDict {
                    if let tmpCallID = threemaDict["callId"] {
                        callID = VoIPCallID(callID: tmpCallID as? UInt32)
                    }
                }
                let action = VoIPCallUserAction(
                    action: .accept,
                    contactIdentity: contact.identity,
                    callID: callID,
                    completion: {
                        self.finishResponse()
                    }
                )
                VoIPCallStateManager.shared.processUserAction(action)
            }
            else {
                self.finishResponse()
                return
            }
        }) {
            self.finishResponse()
        }
    }

    private func handleRejectCall() {
        ServerConnectorHelper.waitUntilConnected(timeout: 20, onConnect: {
            if let contact = self.businessInjector.entityManager.entityFetcher.contact(for: self.identity!) {
                var callID: VoIPCallID?
                if let threemaDict = self.threemaDict {
                    if let tmpCallID = threemaDict["callId"] {
                        callID = VoIPCallID(callID: tmpCallID as? UInt32)
                    }
                }
                let action = VoIPCallUserAction(
                    action: .reject,
                    contactIdentity: contact.identity,
                    callID: callID,
                    completion: {
                        self.finishResponse()
                    }
                )
                VoIPCallStateManager.shared.processUserAction(action)
            }
            else {
                self.finishResponse()
                return
            }
        }) {
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
                groupManager: businessInjector.groupManager
            ),
            safeApiService: SafeApiService()
        )

        if safeManager.isActivated {
            NotificationCenter.default.post(name: Notification.Name(kSafeSetupUI), object: nil)
        }
    }

    /// Update message read.
    /// - Parameter message: Message to set read true
    private func updateMessageAsRead(for message: BaseMessage) {
        businessInjector.entityManager.performSyncBlockAndSafe {
            message.read = NSNumber(booleanLiteral: true)
            message.readDate = Date()
            DDLogVerbose("Message marked as read: \(message.id.hexString)")
        }
        notificationManager.updateUnreadMessagesCount(baseMessage: message)
    }
}
