//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

    //
//  WebAbstractMessage.swift
//  Threema
//
//  Copyright © 2018 Threema GmbH. All rights reserved.
//

import Foundation
import SwiftMsgPack
import CocoaLumberjackSwift

public class WebAbstractMessage: NSObject {
        
    var messageType: String
    var messageSubType: String?
    var requestId: String?
    var ack: WebAbstractMessageAcknowledgement?
    
    var args: [AnyHashable:Any?]?
    var data: Any?
    
    public init(messageType: String, messageSubType: String?, requestId: String?, ack: WebAbstractMessageAcknowledgement?, args: [AnyHashable:Any?]?, data: Any?) {
        self.messageType = messageType
        self.messageSubType = messageSubType
        self.requestId = requestId
        self.ack = ack
        self.args = args
        self.data = data
    }
    
    public init(dictionary: [AnyHashable: Any?]) {
        messageType = dictionary["type"] as! String
        messageSubType = dictionary["subType"] as? String
        requestId = dictionary["id"] as? String
        if let tmpId = dictionary["ack"] as? [AnyHashable: Any?] {
            ack = WebAbstractMessageAcknowledgement.init(object: tmpId)
        }
        args = dictionary["args"] as? [AnyHashable:Any?]
        if dictionary["id"] != nil {
            requestId = dictionary["id"] as? String
        }
        if dictionary["data"] != nil {
            data = dictionary["data"]! as Any?
        }
    }
    
    public init(message: WebAbstractMessage) {
        messageType = message.messageType
        messageSubType = message.messageSubType
        requestId = message.requestId
        ack = message.ack
        args = message.args
        data = message.data
    }
    
    public func addIds(message: WebAbstractMessage) {
        requestId = message.requestId
        ack = message.ack
    }
    
    public func messagePack() -> Data
    {
        var msgData = Data()
        do {
            var dict: [AnyHashable: Any?] = ["type": messageType, "subType": messageSubType ?? ""]
            if requestId != nil {
                dict.updateValue(requestId, forKey: "id")
            }
            if ack != nil {
                dict.updateValue(ack?.objectDict(), forKey: "ack")
            }
            if args != nil {
                dict.updateValue(args, forKey: "args")
            }
            if data != nil {
                dict.updateValue(data, forKey: "data")
            }
            try msgData.pack(dict)
            return msgData
        } catch {
            print("Something went wrong while packing data: \(error)")
            return msgData
        }
    }
    
    func getResponseMsgpack(session: WCSession, completionHandler: @escaping (_ msgPack: Data?, _ blacklisted: Bool) -> Void) {
        if session.connectionStatus() != .ready && messageType != "update" && messageSubType != "connectionInfo" {
            if messageSubType != nil {
                ValidationLogger.shared()?.logString("Threema Web: Message received in invalid state: \(session.connectionStatus()?.rawValue ?? 0) \(messageType) \(messageSubType!)")
                completionHandler(nil, true)
            } else {
                ValidationLogger.shared()?.logString("Threema Web: Message received in invalid state: \(session.connectionStatus()?.rawValue ?? 0) \(messageType)")
                completionHandler(nil, true)
            }
            return;
        }
        if messageType == "request" {
            switch messageSubType {
            case "clientInfo"?:
                let requestClientInfo = WebClientInfoRequest.init(message: self)
                let browserName = requestClientInfo.browserName ?? "Unknown"
                let broserVersion = requestClientInfo.browserVersion != nil ? NSNumber.init(value: requestClientInfo.browserVersion!) : NSNumber.init(value: 0)
                if session.webClientSession != nil {
                    WebClientSessionStore.shared.updateWebClientSession(session: session.webClientSession!, browserName: browserName, browserVersion: broserVersion)
                }
                let responseClientInfo = WebClientInfoResponse.init(requestId: self.requestId)
                DDLogVerbose("Threema Web: MessagePack -> Send response/clientInfo")
                completionHandler(responseClientInfo.messagePack(), false)
                return
            case "profile"?:
                let responseProfile = WebProfileResponse.init(requestId: self.requestId)
                DDLogVerbose("Threema Web: MessagePack -> Send response/profile")
                completionHandler(responseProfile.messagePack(), false)
                return
            case "receivers"?:
                self.buildResponseReceivers { (responseReceivers) in
                    DDLogVerbose("Threema Web: MessagePack -> Send response/receivers")
                    completionHandler(responseReceivers!.messagePack(), false)
                    return
                }
                break
            case "conversations"?:
                let requestConversations = WebConversationsRequest.init(message: self)
                let responseConversations = WebConversationsResponse.init(requestId: self.requestId, conversationRequest: requestConversations, session: session)
                DDLogVerbose("Threema Web: MessagePack -> Send response/conversations")
                completionHandler(responseConversations.messagePack(), false)
                return
            case "batteryStatus"?:
                let responseBatteryStatus = WebBatteryStatusUpdate.init(self.requestId)
                DDLogVerbose("Threema Web: MessagePack -> Send update/batteryStatus")
                completionHandler(responseBatteryStatus.messagePack(), true)
                return
            case "messages"?:
                let requestMessages = WebMessagesRequest.init(message: self)
                let responseMessages = WebMessagesResponse.init(requestMessage: requestMessages, session: session)
                session.addRequestedConversation(conversationId: responseMessages.identity)
                DDLogVerbose("Threema Web: MessagePack -> Send response/messages")
                completionHandler(responseMessages.messagePack(), false)
                return
            case "avatar"?:
                let requestAvatar = WebAvatarRequest.init(message: self)
                let responseAvatar = WebAvatarResponse.init(request: requestAvatar)
                DDLogVerbose("Threema Web: MessagePack -> Send response/avatar")
                completionHandler(responseAvatar.messagePack(), false)
                return
            case "thumbnail"?:
                let requestThumbnail = WebThumbnailRequest.init(message: self)
                var baseMessage: BaseMessage? = nil
                    let entityManager = EntityManager()
                    baseMessage = entityManager.entityFetcher.message(withId: requestThumbnail.messageId)
                if baseMessage != nil {
                    if baseMessage!.isKind(of: ImageMessage.self) {
                        let imageMessage = baseMessage as! ImageMessage
                        if imageMessage.image == nil && imageMessage.thumbnail == nil {
                            let confirmResponse = WebConfirmResponse.init(message: requestThumbnail, success: false, error: "internalError")
                            DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                            completionHandler(confirmResponse.messagePack(), false)
                            return
                        } else {
                            if imageMessage.image != nil && imageMessage.image.data == nil {
                                let confirmResponse = WebConfirmResponse.init(message: requestThumbnail, success: false, error: "internalError")
                                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                                completionHandler(confirmResponse.messagePack(), false)
                                return
                            }
                            else if imageMessage.thumbnail != nil && imageMessage.thumbnail.data == nil {
                                let confirmResponse = WebConfirmResponse.init(message: requestThumbnail, success: false, error: "internalError")
                                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                                completionHandler(confirmResponse.messagePack(), false)
                                return
                            }
                        }
                        let responseThumbnail = WebThumbnailResponse.init(request: requestThumbnail, imageMessage: baseMessage!)
                        DDLogVerbose("Threema Web: MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                    else if baseMessage!.isKind(of: VideoMessage.self) {
                        let responseThumbnail = WebThumbnailResponse.init(request: requestThumbnail, videoMessage: baseMessage!)
                        DDLogVerbose("Threema Web: MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                    else if baseMessage!.isKind(of: FileMessage.self) {
                        let responseThumbnail = WebThumbnailResponse.init(request: requestThumbnail, fileMessage: baseMessage!)
                        DDLogVerbose("Threema Web: MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                } else {
                    let confirmResponse = WebConfirmResponse.init(message: requestThumbnail, success: false, error: "invalidMessage")
                    DDLogVerbose("Threema Web: MessagePack -> Send response/thumbnail")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
                break
            case "contactDetail"?:
                let requestContactDetail = WebContactDetailRequest.init(message: self)
                var contact: Contact? = nil
                    let entityManager = EntityManager()
                    contact = entityManager.entityFetcher.contact(forId: requestContactDetail.identity)
                let responseContactDetail = WebContactDetailResponse.init(contact: contact, contactDetailRequest: requestContactDetail)
                DDLogVerbose("Threema Web: MessagePack -> Send response/contactDetail")
                completionHandler(responseContactDetail.messagePack(), false)
                return
            case "read"?:
                let requestRead = WebReadRequest.init(message: self)
                updateReadStateForMessage(requestMessage: requestRead)
                let confirmResponse = WebConfirmResponse.init(webReadRequest: requestRead)
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            case "ack"?:
                let requestAck = WebAckRequest.init(message: self)
                var baseMessage: BaseMessage? = nil
                var entityManager: EntityManager? = nil
                    entityManager = EntityManager()
                    baseMessage = entityManager?.entityFetcher.message(withId: requestAck.messageId)
                if baseMessage != nil {
                    updateAckForMessage(entityManager: entityManager!, requestMessage: requestAck, baseMessage: baseMessage)
                    let responseMessage = WebMessagesUpdate.init(self.requestId, baseMessage: baseMessage!, conversation: baseMessage!.conversation, objectMode: .modified, session: session)
                    DDLogVerbose("Threema Web: MessagePack -> Send update/messages")
                    completionHandler(responseMessage.messagePack(), false)
                    return
                } else {
                    let confirmResponse = WebConfirmResponse.init(message: requestAck, success: false, error: "invalidMessage")
                    DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
            case "blob"?:
                let requestBlob = WebBlobRequest.init(message: self)
                var baseMessage: BaseMessage? = nil
                let entityManager = EntityManager()
                baseMessage = entityManager.entityFetcher.message(withId: requestBlob.messageId)
                
                if baseMessage != nil {
                    if baseMessage!.isKind(of: ImageMessage.self) {
                        let responseMessage = WebBlobResponse.init(request: requestBlob, imageMessage: baseMessage! as! ImageMessage)
                        responseMessage.addImage {
                            DDLogVerbose("Threema Web: MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                            return
                        }
                    }
                    else if baseMessage!.isKind(of: VideoMessage.self) {
                        let responseMessage = WebBlobResponse.init(request: requestBlob, videoMessage: baseMessage! as! VideoMessage)
                        responseMessage.addVideo {
                            DDLogVerbose("Threema Web: MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                            return
                        }
                    }
                    else if baseMessage!.isKind(of: AudioMessage.self) {
                        let responseMessage = WebBlobResponse.init(request: requestBlob, audioMessage: baseMessage! as! AudioMessage)
                        responseMessage.addAudio {
                            DDLogVerbose("Threema Web: MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                            return
                        }
                    }
                    else if baseMessage!.isKind(of: FileMessage.self) {
                        let responseMessage = WebBlobResponse.init(request: requestBlob, fileMessage: baseMessage! as! FileMessage)
                        responseMessage.addFile {
                            DDLogVerbose("Threema Web: MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                            return
                        }
                    } else {
                        let confirmResponse = WebConfirmResponse.init(message: requestBlob, success: false, error: "internalError")
                        DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                        completionHandler(confirmResponse.messagePack(), false)
                        return
                    }
                } else {
                    let confirmResponse = WebConfirmResponse.init(message: requestBlob, success: false, error: "invalidMessage")
                    DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
                break
            case "groupSync"?:
                let requestGroupSync = WebGroupSyncRequest.init(message: self)
                requestGroupSync.syncGroup()
                let responseConfirmAction = WebConfirmResponse.init(webGroupSyncRequest: requestGroupSync)
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            case "connectionAck"?:
                if session.connectionContext() != nil {
                    _ = WebConnectionAckRequest.init(message: self)
                    let responseConnectionAck = WebConnectionAckUpdateResponse.init(requestId: self.requestId, incomingSequenceNumber: session.connectionContext()!.incomingSequenceNumber)
                    session.connectionContext()!.runTimer()
                    DDLogVerbose("Threema Web: MessagePack -> Send update/connectionAck")
                    completionHandler(responseConnectionAck.messagePack(), true)
                } else {
                    completionHandler(nil, true)
                }
                return
            default:
                let confirmResponse = WebConfirmResponse.init(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            }
        }
        else if messageType == "create" {
            switch messageSubType {
            case "contact"?:
                let createContactRequest = WebCreateContactRequest.init(message: self)
                let createContactResponse = WebCreateContactResponse.init(request: createContactRequest)
                createContactResponse.addContact {
                    DDLogVerbose("Threema Web: MessagePack -> Sendcreate/contact")
                    completionHandler(createContactResponse.messagePack(), false)
                    return
                }
                break
            case "group"?:
                let createGroupRequest = WebCreateGroupRequest.init(message: self)
                let createGroupResponse = WebCreateGroupResponse.init(request: createGroupRequest)
                createGroupResponse.addGroup {
                    DDLogVerbose("Threema Web: MessagePack -> Sendcreate/group")
                    completionHandler(createGroupResponse.messagePack(), false)
                    return
                }
                break
            case "textMessage"?:
                let createTextMessageRequest = WebCreateTextMessageRequest.init(message: self)
                session.addRequestCreateMessage(requestId: createTextMessageRequest.requestId!, abstractMessage: createTextMessageRequest)
                let alertArray: [String] = createTextMessageRequest.text.components(separatedBy: " ")
                createTextMessageRequest.sendMessage {
                    if createTextMessageRequest.id != nil && createTextMessageRequest.id == "ECHOECHO" && alertArray.count == 3 && alertArray[0].lowercased() == "alert" && ( alertArray[1].lowercased() == "error" || alertArray[1].lowercased() == "warning" || alertArray[1].lowercased() == "info") {
                        let webAlertUpdate = WebAlertUpdate.init(source: .device, type: WebAlertUpdate.TypeObj(rawValue: alertArray[1].lowercased())!, message:alertArray[2])
                        DDLogVerbose("Threema Web: MessagePack -> Send update/alert")
                        session.sendMessageToWeb(blacklisted: false, msgpack: webAlertUpdate.messagePack())
                    }
                    
                    if createTextMessageRequest.tmpError != nil {
                        // send error
                        let createTextMessageResponse =  WebCreateTextMessageResponse(request: createTextMessageRequest)
                        let baseMessageId = createTextMessageRequest.baseMessage?.id.hexEncodedString() ?? ""
                        let backgroundKey = kAppAckBackgroundTask + baseMessageId
                        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime)) {
                            DDLogVerbose("Threema Web: MessagePack -> Send create/textMessage")
                            session.sendMessageToWeb(blacklisted: false, msgpack: createTextMessageResponse.messagePack())
                        }
                        
                        session.webClientProcessQueue.async {
                            completionHandler(nil, true)
                        }
                        return
                    } else {
                        // background task to send ack to server
                        var id: String?
                        if let groupId = createTextMessageRequest.groupId {
                            id = groupId.hexEncodedString()
                        } else {
                            id = createTextMessageRequest.id!
                        }
                        let backgroundKey = kAppAckBackgroundTask + id!
                        
                        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime)) {
                            session.webClientProcessQueue.async {
                                completionHandler(nil, true)
                            }
                            return
                        }
                    }
                }
                break
            case "fileMessage"?:
                let createFileMessageRequest = WebCreateFileMessageRequest.init(message: self, session: session)
                session.addRequestCreateMessage(requestId: createFileMessageRequest.requestId!, abstractMessage: createFileMessageRequest)
                createFileMessageRequest.sendMessage {
                    completionHandler(nil, true)
                    return
                }
                break
            default:
                let confirmResponse = WebConfirmResponse.init(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            }
        }
        else if messageType == "update" {
                switch messageSubType {
                case "connectionInfo"?:
                    let updateRequestConnectionInfo = WebUpdateConnectionInfoRequest.init(message: self)
                    session.connectionContext()?.connectionInfoRequest = updateRequestConnectionInfo
                    if session.connectionStatus() == .connectionInfoSend {
                        ValidationLogger.shared()?.logString("Threema Web: ConnectionInfo received maybeResume --> state: \(session.connectionStatus()!.rawValue)")
                        session.setWCConnectionStateToReady()
                        updateRequestConnectionInfo.maybeResume(session: session)
                        session.messageQueue.processQueue()
                    } else {
                        ValidationLogger.shared()?.logString("Threema Web: ConnectionInfo received and wait for ConnectionInfoResponse --> state: \(session.connectionStatus()!.rawValue)")
                        session.setWCConnectionStateToConnectionInfoReceived()
                    }
                    completionHandler(nil, true)
                    return
                case "contact"?:
                    let updateRequestContact = WebUpdateContactRequest.init(message: self)
                    updateRequestContact.updateContact()
                    let updateResponseContact = WebUpdateContactResponse.init(request: updateRequestContact)
                    DDLogVerbose("Threema Web: MessagePack -> Send update/contact")
                    completionHandler(updateResponseContact.messagePack(), false)
                    return
                case "profile"?:
                    let updateRequestProfile = WebUpdateProfileRequest.init(message: self)
                    updateRequestProfile.updateProfile()
                    let confirmActionResponse = WebConfirmResponse.init(webUpdateProfileRequest: updateRequestProfile)
                    DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                    completionHandler(confirmActionResponse.messagePack(), false)
                    return
                case "group"?:
                    let updateRequestGroup = WebUpdateGroupRequest.init(message: self)
                    updateRequestGroup.updateGroup {
                        let updateResponseGroup = WebUpdateGroupResponse.init(groupRequest: updateRequestGroup)
                        DDLogVerbose("Threema Web: MessagePack -> Send update/group")
                        completionHandler(updateResponseGroup.messagePack(), false)
                        return
                    }
                    break
                case "typing"?:
                    let updateTyping = WebTypingUpdate.init(message: self)
                    updateTyping.sendTypingToContact()
                    completionHandler(nil, true)
                    return
                case "conversation"?:
                    let requestUpdateConversation = WebUpdateConversationRequest.init(message: self)
                    requestUpdateConversation.updateConversation()
                    let responseConfirmAction = WebConfirmResponse.init(webUpdateConversationRequest: requestUpdateConversation)
                    DDLogVerbose("Threema Web: MessagePack -> Send response/confirmAction")
                    completionHandler(responseConfirmAction.messagePack(), false)
                    return
                case "connectionDisconnect"?:
                    let requestUpdateConnectionDisconnect = WebUpdateConnectionDisconnectRequest.init(message: self)
                    requestUpdateConnectionDisconnect.disconnect(session: session)
                    completionHandler(nil, true)
                    return
                case "connectionAck"?:
                    let requestUpdateConnectionAck = WebConnectionAckUpdateRequest.init(message: self)
                    do {
                        // should be previousContext
                        if let context = session.connectionContext() {
                            if let sequenceNumber = requestUpdateConnectionAck.sequenceNumber {
                                try context.prune(theirSequenceNumber: sequenceNumber)
                            } else {
                                ValidationLogger.shared().logString("Threema Web: Could not prune cache: missing sequenceNumber.")
                                session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                                return
                            }
                        } else {
                            ValidationLogger.shared().logString("Threema Web: Could not prune cache: missing context.")
                            session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                            return
                        }
                    }
                    catch {
                        // do error stuff
                        ValidationLogger.shared().logString("Threema Web: Could not prune cache: \(error).")
                        session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                        return
                    }
                    return
                default:
                    let responseConfirmAction = WebConfirmResponse.init(message: self, success: false, error: "unknownSubtype")
                    DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                    completionHandler(responseConfirmAction.messagePack(), false)
                    return
                }
        }
        else if messageType == "delete" {
            switch messageSubType {
            case "cleanReceiverConversation"?:
                let cleanReceiverConversationRequest = WebCleanReceiverConversationRequest.init(message: self)
                cleanReceiverConversationRequest.clean()
                let confirmActionResponse = WebConfirmResponse.init(webCleanReceiverConversationRequest: cleanReceiverConversationRequest)
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            case "message"?:
                let deleteMessageRequest = WebDeleteMessageRequest.init(message: self)
                deleteMessageRequest.delete()
                let confirmActionResponse = WebConfirmResponse.init(webDeleteMessageRequest: deleteMessageRequest)
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            case "group"?:
                let deleteGroupRequest = WebDeleteGroupRequest.init(message: self)
                deleteGroupRequest.deleteOrLeave()
                let confirmActionResponse = WebConfirmResponse.init(webDeleteGroupRequest: deleteGroupRequest)
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            default:
                let responseConfirmAction = WebConfirmResponse.init(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            }
        } else {
            let responseConfirmAction = WebConfirmResponse.init(message: self, success: false, error: "unknownType")
            DDLogVerbose("Threema Web: MessagePack -> Send update/confirm")
            completionHandler(responseConfirmAction.messagePack(), false)
            return
        }
    }
    
    private func updateReadStateForMessage(requestMessage: WebReadRequest) {
        let entityManager = EntityManager()
        
        var conversation:Conversation? = nil
        let baseMessage = entityManager.entityFetcher.message(withId: requestMessage.messageId)
        
        if baseMessage != nil {
            if baseMessage?.conversation.groupId != nil {
                conversation = entityManager.entityFetcher.conversation(forGroupId: baseMessage?.conversation.groupId)
            } else {
                conversation = entityManager.entityFetcher.conversation(forIdentity: baseMessage?.conversation.contact.identity)
            }
            
            if conversation != nil {
                let messageFetcher = MessageFetcher.init(for: conversation, with: entityManager.entityFetcher)
                var foundMessageId = false
                
                var readReceiptQueue: [BaseMessage] = []
                var readNotificationsKeys: [String] = []
                let unreadMessages: [BaseMessage] = messageFetcher!.unreadMessages() as! [BaseMessage]                
            
                for case let message in unreadMessages {
                    if message.id == requestMessage.messageId || foundMessageId {
                        readReceiptQueue.append(message)
                        let conversation = message.conversation
                        if (conversation!.isGroup()) {
                            let key = message.sender.identity + message.id.hexEncodedString()
                            readNotificationsKeys.append(key)
                        } else {
                            let key = message.conversation.contact.identity + message.id.hexEncodedString()
                            readNotificationsKeys.append(key)
                        }
                        foundMessageId = true
                    }
                }
                
                if readReceiptQueue.count > 0 {
                    if !baseMessage!.conversation.isGroup() {
                        MessageSender.sendReadReceipt(forMessages: readReceiptQueue, toIdentity: baseMessage!.conversation.contact.identity, async: true, quickReply: false)
                    }
//                    DispatchQueue.main.sync {
                        entityManager.performSyncBlockAndSafe({
                            for message in readReceiptQueue {
                                message.read = NSNumber(value: true)
                                message.readDate = Date()
                                let unreadCount: Int = unreadMessages.count - readReceiptQueue.count
                                conversation!.unreadMessageCount = NSNumber.init(value: unreadCount)
                            }
                        })
                        
                        let center = UNUserNotificationCenter.current()
                        center.removeDeliveredNotifications(withIdentifiers: readNotificationsKeys)
//                    }
                } else {
                    requestMessage.ack = WebAbstractMessageAcknowledgement.init(requestMessage.requestId, false, "alreadyRead")
                }
                requestMessage.ack = WebAbstractMessageAcknowledgement.init(requestMessage.requestId, true, nil)
            } else {
                requestMessage.ack = WebAbstractMessageAcknowledgement.init(requestMessage.requestId, false, "invalidMessage")
            }
        } else {
            requestMessage.ack = WebAbstractMessageAcknowledgement.init(requestMessage.requestId, false, "invalidMessage")
        }
        DispatchQueue.main.async {
            NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
        }
    }
    
    private func updateAckForMessage(entityManager: EntityManager, requestMessage: WebAckRequest, baseMessage: BaseMessage!) {
        if baseMessage != nil {
            if baseMessage.userackDate != nil && baseMessage.userack.boolValue == requestMessage.acknowledged {
                return
            }
            entityManager.performSyncBlockAndSafe({
                if requestMessage.acknowledged {
                    MessageSender.sendUserAck(forMessages: [baseMessage], toIdentity: requestMessage.id, async: true, quickReply: false)
                    baseMessage.userack = NSNumber(value: true)
                } else {
                    MessageSender.sendUserDecline(forMessages: [baseMessage], toIdentity: requestMessage.id, async: true, quickReply: false)
                    baseMessage.userack = NSNumber(value: false)
                }
                baseMessage.userackDate = Date()
            })
        }
    }
    
    private func buildResponseReceivers(completion: @escaping (_ webResponseReceivers: WebReceiversResponse?) -> Void) {
        var contactResult: [Contact]?
        var allGroupConversations: [Conversation]?
        var responseReceivers: WebReceiversResponse? = nil
        let entityManager = EntityManager()
        contactResult = entityManager.entityFetcher.allContacts() as? [Contact]
        allGroupConversations = (entityManager.entityFetcher.allGroupConversations() as? [Conversation])!
        FeatureMask.updateMask(forAllContacts: contactResult) {
            responseReceivers = WebReceiversResponse.init(requestId: self.requestId, allContacts: contactResult!, allGroupConversations: allGroupConversations!)
            completion(responseReceivers)
        }
    }
}
    
public struct WebAbstractMessageAcknowledgement {
    var id: String?
    var success: Bool
    var error: String?
    
    init(_ id: String?, _ success: Bool, _ error: String?) {
        self.id = id
        self.success = success
        self.error = error
    }
    
    init(object: [AnyHashable: Any?]) {
        id = object["id"] as? String
        success = object["success"] as! Bool
        error = object["error"] as? String
    }
    
    func objectDict() -> [String: Any] {
        var valuesDict = [String: Any]()
        
        if id != nil {
            valuesDict.updateValue(id!, forKey: "id")
        }
        valuesDict.updateValue(success, forKey: "success")
        if error != nil {
            valuesDict.updateValue(error!, forKey: "error")
        }
        return valuesDict
    }
}

