//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

import Foundation

@objc class NotificationResponse: NSObject {

    @objc var threemaDict: [AnyHashable: Any]?
    @objc var categoryIdentifier: String
    @objc var actionIdentifier: String
    @objc var userText: String?
    @objc var identity: String?
    @objc var messageID: String?
    @objc var userInfo: [AnyHashable: Any]

    @objc var notificationIdentifier: String
    @objc var completionHandler: () -> Void
    
    private let notificationManager = NotificationManager()

    @objc init(response: UNNotificationResponse, completion: @escaping (() -> Void)) {
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
                ServerConnector.shared().connect(initiator: .notificationHandler)
                handleThumbUp()
            }
            else if actionIdentifier == "THUMB_DOWN" {
                ServerConnector.shared().connect(initiator: .notificationHandler)
                handleThumbDown()
            }
            else if actionIdentifier == "REPLY_MESSAGE" {
                ServerConnector.shared().connect(initiator: .notificationHandler)
                handleReplyMessage()
            }
            else {
                ServerConnector.shared().connect(initiator: .app)
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
            let entityManager = EntityManager()
            guard let baseMessage = entityManager.entityFetcher.message(with: self.messageID!.decodeHex()),
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
                let groupManager = GroupManager(entityManager: entityManager)
                let group = groupManager.getGroup(conversation: conversation)

                self.sendUserAck(
                    for: baseMessage,
                    conversation: conversation,
                    contact: nil,
                    group: group,
                    entityManager: entityManager
                )
            }
            else {
                guard let contact = conversation.contact else {
                    self.sendThumbUpError()
                    self.finishResponse()
                    return
                }
                // Only send changed acks
                if baseMessage.userackDate != nil, let currentAck = baseMessage.userack, currentAck.boolValue {
                    self.finishResponse()
                    return
                }
                MessageSender.sendReadReceipt(forMessages: [baseMessage], toIdentity: contact.identity) {
                    self.sendUserAck(
                        for: baseMessage,
                        conversation: conversation,
                        contact: contact,
                        group: nil,
                        entityManager: entityManager
                    )
                }
            }
            
        }) {
            self.sendThumbUpError()
            self.finishResponse()
        }
    }
    
    private func sendUserAck(
        for baseMessage: BaseMessage,
        conversation: Conversation,
        contact: Contact?,
        group: Group?,
        entityManager: EntityManager
    ) {
        updateMessageAsRead(for: baseMessage, entityManager: entityManager)
        
        MessageSender.sendUserAck(
            forMessages: [baseMessage],
            toIdentity: contact?.identity,
            group: group,
            onCompletion: {
                entityManager.performSyncBlockAndSafe {
                    if conversation.isGroup() {
                        let groupDeliveryReceipt = GroupDeliveryReceipt(
                            identity: MyIdentityStore.shared().identity,
                            deliveryReceiptType: .acknowledged,
                            date: Date()
                        )
                        baseMessage.add(groupDeliveryReceipt: groupDeliveryReceipt)
                    }
                    else {
                        baseMessage.userack = NSNumber(value: true)
                        baseMessage.userackDate = Date()
                    }
                    if baseMessage.id == conversation.lastMessage?.id {
                        conversation.lastMessage = baseMessage
                    }
                }
                self.finishResponse()
            }
        )
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
            let entityManager = EntityManager()
            guard let baseMessage = entityManager.entityFetcher.message(with: self.messageID!.decodeHex()),
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
                
                let groupManager = GroupManager(entityManager: entityManager)
                let group = groupManager.getGroup(conversation: conversation)

                self.sendUserDecline(
                    for: baseMessage,
                    conversation: conversation,
                    contact: nil,
                    group: group,
                    entityManager: entityManager
                )
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
                
                MessageSender.sendReadReceipt(
                    forMessages: [baseMessage],
                    toIdentity: contact.identity,
                    onCompletion: {
                        self.sendUserDecline(
                            for: baseMessage,
                            conversation: conversation,
                            contact: contact,
                            group: nil,
                            entityManager: entityManager
                        )
                    }
                )
            }
        }) {
            self.sendThumbDownError()
            self.finishResponse()
        }
    }
    
    private func sendUserDecline(
        for baseMessage: BaseMessage,
        conversation: Conversation,
        contact: Contact?,
        group: Group?,
        entityManager: EntityManager
    ) {
        updateMessageAsRead(for: baseMessage, entityManager: entityManager)
        MessageSender.sendUserDecline(
            forMessages: [baseMessage],
            toIdentity: contact?.identity,
            group: group,
            onCompletion: {
                entityManager.performSyncBlockAndSafe {
                    if conversation.isGroup() {
                        let groupDeliveryReceipt = GroupDeliveryReceipt(
                            identity: MyIdentityStore.shared().identity,
                            deliveryReceiptType: .declined,
                            date: Date()
                        )
                        baseMessage.add(groupDeliveryReceipt: groupDeliveryReceipt)
                    }
                    else {
                        baseMessage.userack = NSNumber(value: false)
                        baseMessage.userackDate = Date()
                    }
                    if baseMessage.id == conversation.lastMessage?.id {
                        conversation.lastMessage = baseMessage
                    }
                }
                self.finishResponse()
            }
        )
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
            let entityManager = EntityManager()
            
            if let baseMessage = entityManager.entityFetcher.message(with: self.messageID!.decodeHex()),
               let conversation = baseMessage.conversation {

                if !baseMessage.isGroupMessage,
                   let contact = conversation.contact {
                    MessageSender.sendReadReceipt(
                        forMessages: [baseMessage],
                        toIdentity: contact.identity,
                        onCompletion: {
                            self.updateMessageAsRead(for: baseMessage, entityManager: entityManager)
                            MessageSender.reflectReadReceipt(messages: [baseMessage], senderIdentity: contact.identity)
                            self.sendUserText(
                                text: self.userText,
                                conversation: conversation,
                                isConnectionEstablished: true
                            )
                        }
                    )
                }
                else {
                    self.updateMessageAsRead(for: baseMessage, entityManager: entityManager)
                    self.sendUserText(text: self.userText, conversation: conversation, isConnectionEstablished: true)
                }
            }
            else {
                self.sendReplyError()
                self.finishResponse()
            }
        }) {
            let entityManager = EntityManager()
            if let baseMessage = entityManager.entityFetcher.message(with: self.messageID!.decodeHex()),
               let conversation = baseMessage.conversation {
                
                self.updateMessageAsRead(for: baseMessage, entityManager: entityManager)
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
            let trimmedMessageData = userText!.data(using: .utf8)
            if trimmedMessageData!.count > Int(kMaxMessageLen) {
                sendReplyError()
                finishResponse()
                return
            }

            MessageSender.sendMessage(text, in: conversation, quickReply: true, requestID: nil, completion: { _ in
                if !isConnectionEstablished {
                    self.sendReplyError()
                }
                self.finishResponse()
            })
        }
        else {
            for (index, object) in trimmedMessages!.enumerated() {
                MessageSender.sendMessage(
                    object,
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
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(for: self.identity!) {
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
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(for: self.identity!) {
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
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(for: self.identity!) {
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
                groupManager: GroupManager()
            ),
            safeApiService: SafeApiService()
        )

        if safeManager.isActivated {
            NotificationCenter.default.post(name: Notification.Name(kSafeSetupUI), object: nil)
        }
    }

    /// Update message read.
    /// - Parameter message: Message to set read true
    private func updateMessageAsRead(for message: BaseMessage, entityManager: EntityManager) {
        entityManager.performSyncBlockAndSafe {
            message.read = NSNumber(booleanLiteral: true)
            message.readDate = Date()
        }
        notificationManager.updateUnreadMessagesCount(baseMessage: message)
    }
}
