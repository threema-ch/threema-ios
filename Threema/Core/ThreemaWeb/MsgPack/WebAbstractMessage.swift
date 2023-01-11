//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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
import SwiftMsgPack
import ThreemaFramework

public class WebAbstractMessage: NSObject {
        
    var messageType: String
    var messageSubType: String?
    var requestID: String?
    var ack: WebAbstractMessageAcknowledgement?
    
    var args: [AnyHashable: Any?]?
    var data: Any?
    
    public init(
        messageType: String,
        messageSubType: String?,
        requestID: String?,
        ack: WebAbstractMessageAcknowledgement?,
        args: [AnyHashable: Any?]?,
        data: Any?
    ) {
        self.messageType = messageType
        self.messageSubType = messageSubType
        self.requestID = requestID
        self.ack = ack
        self.args = args
        self.data = data
    }
    
    public init(dictionary: [AnyHashable: Any?]) {
        self.messageType = dictionary["type"] as! String
        self.messageSubType = dictionary["subType"] as? String
        self.requestID = dictionary["id"] as? String
        if let tmpID = dictionary["ack"] as? [AnyHashable: Any?] {
            self.ack = WebAbstractMessageAcknowledgement(object: tmpID)
        }
        self.args = dictionary["args"] as? [AnyHashable: Any?]
        if dictionary["id"] != nil {
            self.requestID = dictionary["id"] as? String
        }
        if dictionary["data"] != nil {
            self.data = dictionary["data"]! as Any?
        }
    }
    
    public init(message: WebAbstractMessage) {
        self.messageType = message.messageType
        self.messageSubType = message.messageSubType
        self.requestID = message.requestID
        self.ack = message.ack
        self.args = message.args
        self.data = message.data
    }
    
    public func addIDs(message: WebAbstractMessage) {
        requestID = message.requestID
        ack = message.ack
    }
    
    public func messagePack() -> Data {
        var msgData = Data()
        do {
            var dict: [AnyHashable: Any?] = ["type": messageType, "subType": messageSubType ?? ""]
            if requestID != nil {
                dict.updateValue(requestID, forKey: "id")
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
        }
        catch {
            print("Something went wrong while packing data: \(error)")
            return msgData
        }
    }
    
    func getResponseMsgpack(
        session: WCSession,
        completionHandler: @escaping (_ msgPack: Data?, _ blacklisted: Bool) -> Void
    ) {
        if session.connectionStatus() != .ready, messageType != "update", messageSubType != "connectionInfo" {
            if messageSubType != nil {
                ValidationLogger.shared()?
                    .logString(
                        "[Threema Web] Message received in invalid state: \(session.connectionStatus()?.rawValue ?? 0) \(messageType) \(messageSubType!)"
                    )
                completionHandler(nil, true)
            }
            else {
                ValidationLogger.shared()?
                    .logString(
                        "[Threema Web] Message received in invalid state: \(session.connectionStatus()?.rawValue ?? 0) \(messageType)"
                    )
                completionHandler(nil, true)
            }
            return
        }
        if messageType == "request" {
            switch messageSubType {
            case "clientInfo"?:
                let requestClientInfo = WebClientInfoRequest(message: self)
                let browserName = requestClientInfo.browserName ?? "Unknown"
                let broserVersion = requestClientInfo
                    .browserVersion != nil ? NSNumber(value: requestClientInfo.browserVersion!) : NSNumber(value: 0)
                if session.webClientSession != nil {
                    WebClientSessionStore.shared.updateWebClientSession(
                        session: session.webClientSession!,
                        browserName: browserName,
                        browserVersion: broserVersion
                    )
                }
                let responseClientInfo = WebClientInfoResponse(requestID: requestID)
                DDLogVerbose("[Threema Web] MessagePack -> Send response/clientInfo")
                completionHandler(responseClientInfo.messagePack(), false)
                return
            case "profile"?:
                let responseProfile = WebProfileResponse(requestID: requestID)
                DDLogVerbose("[Threema Web] MessagePack -> Send response/profile")
                completionHandler(responseProfile.messagePack(), false)
                return
            case "receivers"?:
                buildResponseReceivers { responseReceivers in
                    DDLogVerbose("[Threema Web] MessagePack -> Send response/receivers")
                    completionHandler(responseReceivers!.messagePack(), false)
                }
            case "conversations"?:
                let requestConversations = WebConversationsRequest(message: self)
                let responseConversations = WebConversationsResponse(
                    requestID: requestID,
                    conversationRequest: requestConversations,
                    session: session
                )
                DDLogVerbose("[Threema Web] MessagePack -> Send response/conversations")
                completionHandler(responseConversations.messagePack(), false)
                return
            case "batteryStatus"?:
                let responseBatteryStatus = WebBatteryStatusUpdate(requestID)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/batteryStatus")
                completionHandler(responseBatteryStatus.messagePack(), true)
                return
            case "messages"?:
                let requestMessages = WebMessagesRequest(message: self)
                let responseMessages = WebMessagesResponse(requestMessage: requestMessages, session: session)
                session.addRequestedConversation(conversationID: responseMessages.identity)
                DDLogVerbose("[Threema Web] MessagePack -> Send response/messages")
                completionHandler(responseMessages.messagePack(), false)
                return
            case "avatar"?:
                let requestAvatar = WebAvatarRequest(message: self)
                let responseAvatar = WebAvatarResponse(request: requestAvatar)
                DDLogVerbose("[Threema Web] MessagePack -> Send response/avatar")
                completionHandler(responseAvatar.messagePack(), false)
                return
            case "thumbnail"?:
                let requestThumbnail = WebThumbnailRequest(message: self)
                var baseMessage: BaseMessage?
                let entityManager = EntityManager()
                baseMessage = entityManager.entityFetcher.message(with: requestThumbnail.messageID)
                if baseMessage != nil {
                    if let imageMessageEntity = baseMessage as? ImageMessageEntity {
                        if imageMessageEntity.image == nil, imageMessageEntity.thumbnail == nil {
                            let confirmResponse = WebConfirmResponse(
                                message: requestThumbnail,
                                success: false,
                                error: "internalError"
                            )
                            DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                            completionHandler(confirmResponse.messagePack(), false)
                            return
                        }
                        else {
                            if imageMessageEntity.image != nil, imageMessageEntity.image.data == nil {
                                let confirmResponse = WebConfirmResponse(
                                    message: requestThumbnail,
                                    success: false,
                                    error: "internalError"
                                )
                                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                                completionHandler(confirmResponse.messagePack(), false)
                                return
                            }
                            else if imageMessageEntity.thumbnail != nil, imageMessageEntity.thumbnail.data == nil {
                                let confirmResponse = WebConfirmResponse(
                                    message: requestThumbnail,
                                    success: false,
                                    error: "internalError"
                                )
                                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                                completionHandler(confirmResponse.messagePack(), false)
                                return
                            }
                        }
                        let responseThumbnail = WebThumbnailResponse(
                            request: requestThumbnail,
                            imageMessageEntity: imageMessageEntity
                        )
                        DDLogVerbose("[Threema Web] MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                    else if let videoMessageEntity = baseMessage as? VideoMessageEntity {
                        let responseThumbnail = WebThumbnailResponse(
                            request: requestThumbnail,
                            videoMessageEntity: videoMessageEntity
                        )
                        DDLogVerbose("[Threema Web] MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                    else if let fileMessageEntity = baseMessage as? FileMessageEntity {
                        let responseThumbnail = WebThumbnailResponse(
                            request: requestThumbnail,
                            fileMessageEntity: fileMessageEntity
                        )
                        DDLogVerbose("[Threema Web] MessagePack -> Send response/thumbnail")
                        completionHandler(responseThumbnail.messagePack(), false)
                        return
                    }
                }
                else {
                    let confirmResponse = WebConfirmResponse(
                        message: requestThumbnail,
                        success: false,
                        error: "invalidMessage"
                    )
                    DDLogVerbose("[Threema Web] MessagePack -> Send response/thumbnail")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
            case "contactDetail"?:
                let requestContactDetail = WebContactDetailRequest(message: self)
                var contact: Contact?
                let entityManager = EntityManager()
                contact = entityManager.entityFetcher.contact(for: requestContactDetail.identity)
                let responseContactDetail = WebContactDetailResponse(
                    contact: contact,
                    contactDetailRequest: requestContactDetail
                )
                DDLogVerbose("[Threema Web] MessagePack -> Send response/contactDetail")
                completionHandler(responseContactDetail.messagePack(), false)
                return
            case "read"?:
                let requestRead = WebReadRequest(message: self)
                updateReadStateForMessage(requestMessage: requestRead)
                let confirmResponse = WebConfirmResponse(webReadRequest: requestRead)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            case "ack"?:
                let requestAck = WebAckRequest(message: self)
                var conversation: Conversation?
                var entityManager = EntityManager()
                
                if requestAck.type == "contact" {
                    conversation = entityManager.entityFetcher.conversation(forIdentity: requestAck.id)
                }
                else {
                    conversation = entityManager.entityFetcher.conversation(for: requestAck.id.hexadecimal())
                }
                
                guard let baseMessage = entityManager.entityFetcher.message(with: requestAck.messageID),
                      conversation?.objectID == baseMessage.conversation.objectID else {
                    let confirmResponse = WebConfirmResponse(
                        message: requestAck,
                        success: false,
                        error: "invalidMessage"
                    )
                    DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
                
                updateAckForMessage(
                    entityManager: entityManager,
                    requestMessage: requestAck,
                    baseMessage: baseMessage
                )
                let responseMessage = WebMessagesUpdate(
                    requestID,
                    baseMessage: baseMessage,
                    conversation: baseMessage.conversation,
                    objectMode: .modified,
                    session: session
                )
                DDLogVerbose("[Threema Web] MessagePack -> Send update/messages")
                completionHandler(responseMessage.messagePack(), false)
                return
            case "blob"?:
                let requestBlob = WebBlobRequest(message: self)
                var baseMessage: BaseMessage?
                let entityManager = EntityManager()
                baseMessage = entityManager.entityFetcher.message(with: requestBlob.messageID)
                
                if baseMessage != nil {
                    if let imageMessageEntity = baseMessage as? ImageMessageEntity {
                        let responseMessage = WebBlobResponse(
                            request: requestBlob,
                            imageMessage: imageMessageEntity
                        )
                        responseMessage.addImage {
                            DDLogVerbose("[Threema Web] MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                        }
                    }
                    else if let videoMessageEntity = baseMessage as? VideoMessageEntity {
                        let responseMessage = WebBlobResponse(
                            request: requestBlob,
                            videoMessageEntity: videoMessageEntity
                        )
                        responseMessage.addVideo {
                            DDLogVerbose("[Threema Web] MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                        }
                    }
                    else if let audioMessageEntity = baseMessage as? AudioMessageEntity {
                        let responseMessage = WebBlobResponse(
                            request: requestBlob,
                            audioMessageEntity: audioMessageEntity
                        )
                        responseMessage.addAudio {
                            DDLogVerbose("[Threema Web] MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                        }
                    }
                    else if let fileMessageEntity = baseMessage as? FileMessageEntity {
                        let responseMessage = WebBlobResponse(
                            request: requestBlob,
                            fileMessageEntity: fileMessageEntity
                        )
                        responseMessage.addFile {
                            DDLogVerbose("[Threema Web] MessagePack -> Send response/blob")
                            completionHandler(responseMessage.messagePack(), false)
                        }
                    }
                    else {
                        let confirmResponse = WebConfirmResponse(
                            message: requestBlob,
                            success: false,
                            error: "internalError"
                        )
                        DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                        completionHandler(confirmResponse.messagePack(), false)
                        return
                    }
                }
                else {
                    let confirmResponse = WebConfirmResponse(
                        message: requestBlob,
                        success: false,
                        error: "invalidMessage"
                    )
                    DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                    completionHandler(confirmResponse.messagePack(), false)
                    return
                }
            case "groupSync"?:
                let requestGroupSync = WebGroupSyncRequest(message: self)
                requestGroupSync.syncGroup()
                let responseConfirmAction = WebConfirmResponse(webGroupSyncRequest: requestGroupSync)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            case "connectionAck"?:
                if session.connectionContext() != nil {
                    _ = WebConnectionAckRequest(message: self)
                    let responseConnectionAck = WebConnectionAckUpdateResponse(
                        requestID: requestID,
                        incomingSequenceNumber: session.connectionContext()!.incomingSequenceNumber
                    )
                    session.connectionContext()!.runTimer()
                    DDLogVerbose("[Threema Web] MessagePack -> Send update/connectionAck")
                    completionHandler(responseConnectionAck.messagePack(), true)
                }
                else {
                    completionHandler(nil, true)
                }
                return
            default:
                let confirmResponse = WebConfirmResponse(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            }
        }
        else if messageType == "create" {
            switch messageSubType {
            case "contact"?:
                let createContactRequest = WebCreateContactRequest(message: self)
                let createContactResponse = WebCreateContactResponse(request: createContactRequest)
                createContactResponse.addContact {
                    DDLogVerbose("[Threema Web] MessagePack -> Sendcreate/contact")
                    completionHandler(createContactResponse.messagePack(), false)
                }
            case "group"?:
                let createGroupRequest = WebCreateGroupRequest(message: self)
                let createGroupResponse = WebCreateGroupResponse(request: createGroupRequest)
                createGroupResponse.addGroup {
                    DDLogVerbose("[Threema Web] MessagePack -> Sendcreate/group")
                    completionHandler(createGroupResponse.messagePack(), false)
                }
            case "textMessage"?:
                let createTextMessageRequest = WebCreateTextMessageRequest(message: self)
                session.addRequestCreateMessage(
                    requestID: createTextMessageRequest.requestID!,
                    abstractMessage: createTextMessageRequest
                )
                let alertArray: [String] = createTextMessageRequest.text.components(separatedBy: " ")
                createTextMessageRequest.sendMessage {
                    if createTextMessageRequest.id != nil, createTextMessageRequest.id == "ECHOECHO",
                       alertArray.count == 3, alertArray[0].lowercased() == "alert",
                       alertArray[1].lowercased() == "error" || alertArray[1].lowercased() == "warning" || alertArray[1]
                       .lowercased() == "info" {
                        let webAlertUpdate = WebAlertUpdate(
                            source: .device,
                            type: WebAlertUpdate.TypeObj(rawValue: alertArray[1].lowercased())!,
                            message: alertArray[2]
                        )
                        DDLogVerbose("[Threema Web] MessagePack -> Send update/alert")
                        session.sendMessageToWeb(blacklisted: false, msgpack: webAlertUpdate.messagePack())
                    }
                    
                    if createTextMessageRequest.tmpError != nil {
                        // send error
                        let createTextMessageResponse = WebCreateTextMessageResponse(request: createTextMessageRequest)
                        let baseMessageID = createTextMessageRequest.baseMessage?.id.hexEncodedString() ?? ""
                        let backgroundKey = kAppAckBackgroundTask + baseMessageID
                        BackgroundTaskManager.shared.newBackgroundTask(
                            key: backgroundKey,
                            timeout: Int(kAppAckBackgroundTaskTime)
                        ) {
                            DDLogVerbose("[Threema Web] MessagePack -> Send create/textMessage")
                            session.sendMessageToWeb(
                                blacklisted: false,
                                msgpack: createTextMessageResponse.messagePack()
                            )
                        }
                        
                        session.webClientProcessQueue.async {
                            completionHandler(nil, true)
                        }
                        return
                    }
                    else {
                        // background task to send ack to server
                        var id: String?
                        if let groupID = createTextMessageRequest.groupID {
                            id = groupID.hexEncodedString()
                        }
                        else {
                            id = createTextMessageRequest.id!
                        }
                        let backgroundKey = kAppAckBackgroundTask + id!
                        
                        BackgroundTaskManager.shared.newBackgroundTask(
                            key: backgroundKey,
                            timeout: Int(kAppAckBackgroundTaskTime)
                        ) {
                            session.webClientProcessQueue.async {
                                completionHandler(nil, true)
                            }
                        }
                    }
                }
            case "fileMessage"?:
                let createFileMessageRequest = WebCreateFileMessageRequest(message: self, session: session)
                session.addRequestCreateMessage(
                    requestID: createFileMessageRequest.requestID!,
                    abstractMessage: createFileMessageRequest
                )
                createFileMessageRequest.sendMessage {
                    completionHandler(nil, true)
                }
            default:
                let confirmResponse = WebConfirmResponse(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmResponse.messagePack(), false)
                return
            }
        }
        else if messageType == "update" {
            switch messageSubType {
            case "connectionInfo"?:
                let updateRequestConnectionInfo = WebUpdateConnectionInfoRequest(message: self)
                session.connectionContext()?.connectionInfoRequest = updateRequestConnectionInfo
                if session.connectionStatus() == .connectionInfoSend {
                    ValidationLogger.shared()?
                        .logString(
                            "[Threema Web] ConnectionInfo received maybeResume --> state: \(session.connectionStatus()!.rawValue)"
                        )
                    session.setWCConnectionStateToReady()
                    updateRequestConnectionInfo.maybeResume(session: session)
                    session.messageQueue.processQueue()
                }
                else {
                    ValidationLogger.shared()?
                        .logString(
                            "[Threema Web] ConnectionInfo received and wait for ConnectionInfoResponse --> state: \(session.connectionStatus()!.rawValue)"
                        )
                    session.setWCConnectionStateToConnectionInfoReceived()
                }
                completionHandler(nil, true)
                return
            case "contact"?:
                let updateRequestContact = WebUpdateContactRequest(message: self)
                updateRequestContact.updateContact()
                let updateResponseContact = WebUpdateContactResponse(request: updateRequestContact)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/contact")
                completionHandler(updateResponseContact.messagePack(), false)
                return
            case "profile"?:
                let updateRequestProfile = WebUpdateProfileRequest(message: self)
                updateRequestProfile.updateProfile()
                let confirmActionResponse = WebConfirmResponse(webUpdateProfileRequest: updateRequestProfile)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            case "group"?:
                let updateRequestGroup = WebUpdateGroupRequest(message: self)
                updateRequestGroup.updateGroup {
                    let updateResponseGroup = WebUpdateGroupResponse(groupRequest: updateRequestGroup)
                    DDLogVerbose("[Threema Web] MessagePack -> Send update/group")
                    completionHandler(updateResponseGroup.messagePack(), false)
                }
            case "typing"?:
                let updateTyping = WebTypingUpdate(message: self)
                updateTyping.sendTypingToContact()
                completionHandler(nil, true)
                return
            case "conversation"?:
                let requestUpdateConversation = WebUpdateConversationRequest(message: self)
                requestUpdateConversation.updateConversation()
                let responseConfirmAction =
                    WebConfirmResponse(webUpdateConversationRequest: requestUpdateConversation)
                DDLogVerbose("[Threema Web] MessagePack -> Send response/confirmAction")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            case "connectionDisconnect"?:
                let requestUpdateConnectionDisconnect = WebUpdateConnectionDisconnectRequest(message: self)
                requestUpdateConnectionDisconnect.disconnect(session: session)
                completionHandler(nil, true)
                return
            case "connectionAck"?:
                let requestUpdateConnectionAck = WebConnectionAckUpdateRequest(message: self)
                do {
                    // should be previousContext
                    if let context = session.connectionContext() {
                        if let sequenceNumber = requestUpdateConnectionAck.sequenceNumber {
                            try context.prune(theirSequenceNumber: sequenceNumber)
                        }
                        else {
                            ValidationLogger.shared()
                                .logString("[Threema Web] Could not prune cache: missing sequenceNumber.")
                            session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                            return
                        }
                    }
                    else {
                        ValidationLogger.shared().logString("[Threema Web] Could not prune cache: missing context.")
                        session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                        return
                    }
                }
                catch {
                    // do error stuff
                    ValidationLogger.shared().logString("[Threema Web] Could not prune cache: \(error).")
                    session.stop(close: true, forget: false, sendDisconnect: true, reason: .error)
                    return
                }
                return
            case "activeConversation"?:
                let updateActiveConversation = WebUpdateActiveConversationRequest(message: self)
                updateActiveConversation.updateActiveConversation()
                let confirmActionResponse =
                    WebConfirmResponse(webUpdateActiveConversationRequest: updateActiveConversation)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            default:
                let responseConfirmAction = WebConfirmResponse(
                    message: self,
                    success: false,
                    error: "unknownSubtype"
                )
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            }
        }
        else if messageType == "delete" {
            switch messageSubType {
            case "cleanReceiverConversation"?:
                let cleanReceiverConversationRequest = WebCleanReceiverConversationRequest(message: self)
                cleanReceiverConversationRequest.clean()
                let confirmActionResponse =
                    WebConfirmResponse(webCleanReceiverConversationRequest: cleanReceiverConversationRequest)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            case "message"?:
                let deleteMessageRequest = WebDeleteMessageRequest(message: self)
                deleteMessageRequest.delete()
                let confirmActionResponse = WebConfirmResponse(webDeleteMessageRequest: deleteMessageRequest)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            case "group"?:
                let deleteGroupRequest = WebDeleteGroupRequest(message: self)
                deleteGroupRequest.deleteOrLeave()
                let confirmActionResponse = WebConfirmResponse(webDeleteGroupRequest: deleteGroupRequest)
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(confirmActionResponse.messagePack(), false)
                return
            default:
                let responseConfirmAction = WebConfirmResponse(message: self, success: false, error: "unknownSubtype")
                DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
                completionHandler(responseConfirmAction.messagePack(), false)
                return
            }
        }
        else {
            let responseConfirmAction = WebConfirmResponse(message: self, success: false, error: "unknownType")
            DDLogVerbose("[Threema Web] MessagePack -> Send update/confirm")
            completionHandler(responseConfirmAction.messagePack(), false)
            return
        }
    }
    
    private func updateReadStateForMessage(requestMessage: WebReadRequest) {
        let entityManager = EntityManager()
        
        var conversation: Conversation?

        if let baseMessage = entityManager.entityFetcher.message(with: requestMessage.messageID) {
            if baseMessage.conversation.groupID != nil {
                conversation = entityManager.entityFetcher.conversation(for: baseMessage.conversation.groupID)
            }
            else {
                if let contact = baseMessage.conversation?.contact {
                    conversation = entityManager.entityFetcher.conversation(forIdentity: contact.identity)
                }
            }
            
            if let conversation = conversation {
                let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
                var foundMessageID = false
                
                var readReceiptQueue: [BaseMessage] = []
                var readNotificationsKeys: [String] = []
                let unreadMessages = messageFetcher.unreadMessages()
            
                for message in unreadMessages {
                    if let conversation = message.conversation,
                       message.id == requestMessage.messageID || foundMessageID {
                        readReceiptQueue.append(message)
                        if conversation.isGroup() {
                            // Quickfix: Sender should never be `nil` for incoming group messages
                            let key = message.sender!.identity + message.id.hexEncodedString()
                            for stage in UserNotificationStage.allCases {
                                readNotificationsKeys.append(key + "-\(stage)")
                            }
                        }
                        else {
                            guard let contact = conversation.contact else {
                                continue
                            }
                            let key = contact.identity + message.id.hexEncodedString()
                            for stage in UserNotificationStage.allCases {
                                readNotificationsKeys.append(key + "-\(stage)")
                            }
                        }
                        foundMessageID = true
                    }
                }
                
                if !readReceiptQueue.isEmpty {
                    ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
                        let conversationActions = ConversationActions(entityManager: entityManager)
                        // set isAppInBackground to false, because it will send receipts only if app is in foreground
                        conversationActions.read(conversation, isAppInBackground: false)
                    } onTimeout: {
                        DDLogError("[Threema Web] Sending read receipt message timed out")
                    }
                    
                    DispatchQueue.main.async {
                        let center = UNUserNotificationCenter.current()
                        center.removePendingNotificationRequests(withIdentifiers: readNotificationsKeys)
                        center.removeDeliveredNotifications(withIdentifiers: readNotificationsKeys)
                    }
                }
                else {
                    requestMessage.ack = WebAbstractMessageAcknowledgement(
                        requestMessage.requestID,
                        false,
                        "alreadyRead"
                    )
                }
                requestMessage.ack = WebAbstractMessageAcknowledgement(requestMessage.requestID, true, nil)
            }
            else {
                requestMessage.ack = WebAbstractMessageAcknowledgement(
                    requestMessage.requestID,
                    false,
                    "invalidMessage"
                )
            }
        }
        else {
            requestMessage.ack = WebAbstractMessageAcknowledgement(requestMessage.requestID, false, "invalidMessage")
        }
    }
    
    private func updateAckForMessage(
        entityManager: EntityManager,
        requestMessage: WebAckRequest,
        baseMessage: BaseMessage!
    ) {
        if baseMessage != nil {
                        
            guard let conversation = baseMessage.conversation else {
                return
            }
            
            let groupManager = GroupManager(entityManager: entityManager)
            let group = groupManager.getGroup(conversation: conversation)
            var contact: Contact?
            
            if conversation.isGroup() {
                if let groupDeliveryReceipts = baseMessage.groupDeliveryReceipts,
                   !groupDeliveryReceipts.isEmpty,
                   baseMessage.isMyReaction(requestMessage.acknowledged ? .acknowledged : .declined) {
                    return
                }
            }
            else {
                guard let c = conversation.contact else {
                    return
                }
                contact = c
                // Only send changed acks
                if baseMessage.userackDate != nil, let currentAck = baseMessage.userack,
                   currentAck.boolValue == requestMessage.acknowledged {
                    return
                }
            }
            
            ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
                if requestMessage.acknowledged {
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
                                    baseMessage.userack = NSNumber(booleanLiteral: requestMessage.acknowledged)
                                    baseMessage.userackDate = Date()
                                }
                            }
                        }
                    )
                }
                else {
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
                                    baseMessage.userack = NSNumber(booleanLiteral: requestMessage.acknowledged)
                                    baseMessage.userackDate = Date()
                                }
                            }
                        }
                    )
                }
            } onTimeout: {
                DDLogError("[Threema Web] Sending user ack/decline message timed out")
            }
        }
    }
    
    private func buildResponseReceivers(completion: @escaping (_ webResponseReceivers: WebReceiversResponse?) -> Void) {
        var contactResult: [Contact]?
        var allGroupConversations: [Conversation]?
        var responseReceivers: WebReceiversResponse?
        let entityManager = EntityManager()
        contactResult = entityManager.entityFetcher.allContacts() as? [Contact]
        allGroupConversations = (entityManager.entityFetcher.allGroupConversations() as? [Conversation])!
        FeatureMask.updateMask(forAllContacts: contactResult) {
            responseReceivers = WebReceiversResponse(
                requestID: self.requestID,
                allContacts: contactResult!,
                allGroupConversations: allGroupConversations!
            )
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
        self.id = object["id"] as? String
        self.success = object["success"] as! Bool
        self.error = object["error"] as? String
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
