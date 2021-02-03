//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

    @objc var threemaDict: [AnyHashable : Any]?
    @objc var categoryIdentifier: String
    @objc var actionIdentifier: String
    @objc var userText: String?
    @objc var identity: String?
    @objc var messageId: String?
    @objc var userInfo: [AnyHashable : Any]

    @objc var notificationIdentifier: String
    @objc var completionHandler: (()->Void)

    @objc init(response: UNNotificationResponse, completion: @escaping (()->Void)) {
        if  let tmpThreemaDict = response.notification.request.content.userInfo["threema"] as? [AnyHashable : Any] {
            threemaDict = PushPayloadDecryptor.decryptPushPayload(tmpThreemaDict)
            categoryIdentifier = response.notification.request.content.categoryIdentifier
            actionIdentifier = response.actionIdentifier
            completionHandler = completion
            userInfo = response.notification.request.content.userInfo
            if let mid = threemaDict!["messageId"] as? String {
                messageId = mid
                notificationIdentifier = String.init(format: "%@%@", kAppPushReplyBackgroundTask, messageId!)
            } else {
                notificationIdentifier = kAppPushReplyBackgroundTask
            }
            
            identity = response.notification.request.identifier
            
            if let replyText = (response as? UNTextInputNotificationResponse)?.userText {
                userText = replyText
            }
        } else {
            threemaDict = nil
            categoryIdentifier = response.notification.request.content.categoryIdentifier
            actionIdentifier = response.actionIdentifier
            userInfo = response.notification.request.content.userInfo
            notificationIdentifier = kAppPushReplyBackgroundTask
            completionHandler = completion
        }
    }

    @objc func handleNotificationResponse() {
        BackgroundTaskManager.shared.newBackgroundTask(key: notificationIdentifier, timeout: Int(kAppPushReplyBackgroundTaskTime)) {
            // connect all running sessions
            if WCSessionManager.shared.isRunningWCSession() {
                ValidationLogger.shared()?.logString("Threema Web: handleNotificationResponse --> connect all running sessions")
            }
            WCSessionManager.shared.connectAllRunningSessions()
            
            self.handleResponse()
        }
    }

    private func handleResponse() {
        if self.categoryIdentifier == "SINGLE" || self.categoryIdentifier == "GROUP" {
            AppGroup.setActive(false, for: AppGroupTypeShareExtension)
            ServerConnector.shared().connect()

            if self.actionIdentifier == "THUMB_UP" {
                self.handleThumbUp()
            }
            else if self.actionIdentifier == "THUMB_DOWN" {
                self.handleThumbDown()
            }
            else if self.actionIdentifier == "REPLY_MESSAGE" {
                self.handleReplyMessage()
            } else {
                AppDelegate.shared().handleRemoteNotification(self.userInfo, receivedWhileRunning: AppDelegate.shared().active, notification: nil)
                self.finishResponse()
            }
        }
        else if self.categoryIdentifier == "CALL" {
            if self.actionIdentifier == "REPLY_MESSAGE" {
                self.handleReplyMessage()
            }
            else if self.actionIdentifier == "CALL" {
                self.handleCallMessage()
            }
            else {
                self.finishResponse()
            }
        }
        else if self.categoryIdentifier == "INCOMCALL" {
            if self.actionIdentifier == "ACCEPTCALL" {
                self.handleAcceptCall()
            }
            else if self.actionIdentifier == "REJECTCALL" {
                self.handleRejectCall()
            } else {
                self.finishResponse()
            }
        }
        else if self.categoryIdentifier == "SAFE_SETUP" {
            self.handleSafeSetup()
            self.finishResponse()
        }
        else {
            AppDelegate.shared().handleRemoteNotification(self.userInfo, receivedWhileRunning: false, notification: nil)
            self.finishResponse()
        }
    }

    private func finishResponse() {
        NotificationManager.sharedInstance()?.updateUnreadMessagesCount(false)
        BackgroundTaskManager.shared.cancelBackgroundTask(key: notificationIdentifier)
        self.completionHandler()
    }

    private func handleThumbUp() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            let baseMessage = entityManager.entityFetcher.message(withId: self.messageId!.decodeHex())

            if baseMessage != nil {
                let conversation = baseMessage!.conversation
                if baseMessage!.userackDate == nil || baseMessage!.userack.boolValue != true {
                    let unreadMessageCount = conversation!.unreadMessageCount
                    entityManager.performSyncBlockAndSafe({
                        baseMessage!.read = NSNumber.init(value: true)
                        baseMessage!.readDate = Date()
                        conversation?.unreadMessageCount = NSNumber.init(value: unreadMessageCount!.intValue - 1)
                    })

                    MessageSender.sendReadReceipt(forMessages: [baseMessage!], toIdentity: conversation?.contact.identity, async: false, quickReply: true)
                    MessageSender.sendUserAck(forMessages: [baseMessage!], toIdentity: conversation?.contact.identity, async: false, quickReply: true)
                    entityManager.performSyncBlockAndSafe({
                        baseMessage!.userack = NSNumber.init(value: true)
                        baseMessage!.userackDate = Date()

                        if baseMessage!.id == conversation?.lastMessage.id {
                            conversation?.lastMessage = baseMessage!
                        }
                    })
                    self.finishResponse()
                    return
                } else {
                    self.sendThumbUpError()
                    self.finishResponse()
                    return
                }
            } else {
                self.sendThumbUpError()
                self.finishResponse()
                return
            }

        }) {
            self.sendThumbUpError()
            self.finishResponse()
            return
        }
    }

    private func sendThumbUpError() {
        Utils.sendErrorLocalNotification(NSLocalizedString("send_notification_message_error_title", comment: ""), body: NSLocalizedString("send_notification_message_error_agree", comment: ""), userInfo:self.userInfo)
    }

    private func handleThumbDown() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            let baseMessage = entityManager.entityFetcher.message(withId: self.messageId!.decodeHex())

            if baseMessage != nil {
                let conversation = baseMessage!.conversation
                if baseMessage!.userackDate == nil || baseMessage!.userack.boolValue != false {
                    let unreadMessageCount = conversation!.unreadMessageCount
                    entityManager.performSyncBlockAndSafe({
                        baseMessage!.read = NSNumber.init(value: true)
                        baseMessage!.readDate = Date()
                        conversation?.unreadMessageCount = NSNumber.init(value: unreadMessageCount!.intValue - 1)
                    })

                    MessageSender.sendReadReceipt(forMessages: [baseMessage!], toIdentity: conversation?.contact.identity, async: false, quickReply: true)
                    MessageSender.sendUserDecline(forMessages: [baseMessage!], toIdentity: conversation?.contact.identity, async: false, quickReply: true)
                    entityManager.performSyncBlockAndSafe({
                        baseMessage!.userack = NSNumber.init(value: false)
                        baseMessage!.userackDate = Date()

                        if baseMessage!.id == conversation?.lastMessage.id {
                            conversation?.lastMessage = baseMessage!
                        }
                    })
                    self.finishResponse()
                    return
                } else {
                    self.sendThumbDownError()
                    self.finishResponse()
                    return
                }
            } else {
                self.sendThumbDownError()
                self.finishResponse()
                return
            }

        }) {
            self.sendThumbDownError()
            self.finishResponse()
            return
        }
    }

    private func sendThumbDownError() {
        Utils.sendErrorLocalNotification(NSLocalizedString("send_notification_message_error_title", comment: ""), body: NSLocalizedString("send_notification_message_error_disagree", comment: ""), userInfo: self.userInfo)
    }

    private func handleReplyMessage() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            let baseMessage = entityManager.entityFetcher.message(withId: self.messageId!.decodeHex())

            if baseMessage != nil {
                let conversation = baseMessage!.conversation
                let unreadMessageCount = conversation!.unreadMessageCount

                entityManager.performSyncBlockAndSafe({
                    baseMessage!.read = NSNumber.init(value: true)
                    baseMessage!.readDate = Date()
                    conversation?.unreadMessageCount = NSNumber.init(value: unreadMessageCount!.intValue - 1)
                })
                if !baseMessage!.conversation.isGroup() {
                    MessageSender.sendReadReceipt(forMessages: [baseMessage!], toIdentity: conversation?.contact.identity, async: false, quickReply: true)
                }

                let trimmedMessages = Utils.getTrimmedMessages(self.userText) as? [String]

                if trimmedMessages == nil {
                    let trimmedMessageData = self.userText!.data(using: .utf8)
                    if trimmedMessageData!.count > Int(kMaxMessageLen) {
                        self.sendReplyError()
                        self.finishResponse()
                        return
                    }

                    MessageSender.sendMessage(self.userText, in: conversation!, async: false, quickReply: true, requestId: nil, onCompletion: { (message, conv) in
                        self.finishResponse()
                        return
                    })
                } else {
                    for (index, object) in trimmedMessages!.enumerated() {
                        MessageSender.sendMessage(object, in: conversation!, async: false, quickReply: true, requestId: nil, onCompletion: { (message, conv) in
                            if index == trimmedMessages!.count - 1 {
                                self.finishResponse()
                                return
                            }
                        })
                    }
                }
            } else {
                self.sendReplyError()
                self.finishResponse()
                return
            }
        }) {
            let entityManager = EntityManager()
            let baseMessage = entityManager.entityFetcher.message(withId: self.messageId!.decodeHex())

            if baseMessage != nil {
                let conversation = baseMessage!.conversation
                let trimmedMessages = Utils.getTrimmedMessages(self.userText) as? [String]

                if trimmedMessages == nil {
                    MessageSender.sendMessage(self.userText, in: conversation!, async: false, quickReply: true, requestId: nil, onCompletion: { (message, conv) in
                        self.sendReplyError()
                        self.finishResponse()
                        return
                    })
                } else {
                    for (index, object) in trimmedMessages!.enumerated() {
                        MessageSender.sendMessage(object, in: conversation!, async: false, quickReply: true, requestId: nil, onCompletion: { (message, conv) in
                            if index == trimmedMessages!.count - 1 {
                                self.sendReplyError()
                                self.finishResponse()
                                return
                            }
                        })
                    }
                }
            } else {
                self.sendReplyError()
                self.finishResponse()
                return
            }
        }
    }

    private func sendReplyError() {
        Utils.sendErrorLocalNotification(NSLocalizedString("send_notification_message_error_title", comment: ""), body: NSLocalizedString("send_notification_message_error_failed", comment: ""), userInfo: self.userInfo)
    }

    private func handleCallMessage() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(forId: self.identity!) {
                var callId: VoIPCallId?
                if let threemaDict = self.threemaDict {
                    if let tmpCallId = threemaDict["callId"] {
                        callId = VoIPCallId(callId: tmpCallId as? UInt32)
                    }
                }

                let action = VoIPCallUserAction.init(action: .call, contact: contact, callId: callId, completion: {
                    self.finishResponse()
                    return
                })
                VoIPCallStateManager.shared.processUserAction(action)
            } else {
                self.finishResponse()
                return
            }
        }) {
            self.finishResponse()
            return
        }
    }

    private func handleAcceptCall() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(forId: self.identity!) {
                var callId: VoIPCallId?
                if let threemaDict = self.threemaDict {
                    if let tmpCallId = threemaDict["callId"] {
                        callId = VoIPCallId(callId: tmpCallId as? UInt32)
                    }
                }
                let action = VoIPCallUserAction.init(action: .accept, contact: contact, callId: callId, completion: {
                    self.finishResponse()
                    return
                })
                VoIPCallStateManager.shared.processUserAction(action)
            } else {
                self.finishResponse()
                return
            }
        }) {
            self.finishResponse()
            return
        }
    }

    private func handleRejectCall() {
        waitUntilConnectedTimeout(count: 20, onConnect: {
            let entityManager = EntityManager()
            if let contact = entityManager.entityFetcher.contact(forId: self.identity!) {
                var callId: VoIPCallId?
                if let threemaDict = self.threemaDict {
                    if let tmpCallId = threemaDict["callId"] {
                        callId = VoIPCallId(callId: tmpCallId as? UInt32)
                    }
                }
                let action = VoIPCallUserAction.init(action: .reject, contact: contact, callId: callId, completion: {
                    self.finishResponse()
                    return
                })
                VoIPCallStateManager.shared.processUserAction(action)
            } else {
                self.finishResponse()
                return
            }
        }) {
            self.finishResponse()
            return
        }
    }

    private func waitUntilConnectedTimeout(count: Int, onConnect: @escaping (()->Void), onTimeout: @escaping (()->Void)) {
        if ServerConnector.shared().connectionState == ConnectionStateLoggedIn {
            onConnect()
            return
        }

        if count > 0 && AppGroup.getActiveType() == AppGroupTypeApp {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.waitUntilConnectedTimeout(count: count-1, onConnect: onConnect, onTimeout: onTimeout)
            }
        } else {
            onTimeout()
        }
    }

    private func handleSafeSetup() {
        let safeConfig = SafeConfigManager()
        let safeManager = SafeManager(safeConfigManager: safeConfig, safeStore: SafeStore(safeConfigManager: safeConfig, serverApiConnector: ServerAPIConnector()), safeApiService: SafeApiService())

        if safeManager.isActivated {
            NotificationCenter.default.post(name: Notification.Name(kSafeSetupUI), object: nil)
        }
    }
}
