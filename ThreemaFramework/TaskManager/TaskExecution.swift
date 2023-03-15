//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import PromiseKit

enum TaskExecutionError: Error {
    case createAbsractMessageFailed
    case createReflectedMessageFailed
    case noDeviceGroupPathKey
    case messageReceiverBlockedOrUnknown
    case missingGroupInformation
    case missingMessageInformation
    case processIncomingMessageFailed(message: String?)
    case reflectMessageFailed(message: String?)
    case reflectMessageTimeout(message: String?)
    case sendMessageFailed(message: String)
    case sendMessageTimeout(message: String)
    case wrongTaskDefinitionType
    case invalidContact(message: String)
}

class TaskExecution: NSObject {
    var taskContext: TaskContextProtocol
    var taskDefinition: TaskDefinitionProtocol
    let frameworkInjector: FrameworkInjectorProtocol

    private let responseTimeoutInSeconds = 20
    
    required init(
        taskContext: TaskContextProtocol,
        taskDefinition: TaskDefinitionProtocol,
        frameworkInjector: FrameworkInjectorProtocol
    ) {
        self.taskContext = taskContext
        self.taskDefinition = taskDefinition
        self.frameworkInjector = frameworkInjector
    }
    
    required convenience init(taskContext: TaskContextProtocol, taskDefinition: TaskDefinitionProtocol) {
        self.init(taskContext: taskContext, taskDefinition: taskDefinition, frameworkInjector: BusinessInjector())
    }

    // MARK: Promises
    
    func isMultiDeviceActivated() -> Guarantee<Bool> {
        Guarantee { $0(frameworkInjector.serverConnector.isMultiDeviceActivated) }
    }
    
    /// Reflect message to mediator server.
    /// - Parameters:
    ///     - message: Message to reflect
    ///     - ltReflect: Logging Tag for reflect message
    ///     - ltAck: Logging Tag for ack reflect message
    /// - Throws: TaskExecutionError.reflectMessageFailed
    func reflectMessage(message: AbstractMessage, ltReflect: LoggingTag, ltAck: LoggingTag) throws {
        assert(ltReflect != .none && ltAck != .none)

        var envelope: D2d_Envelope!

        // Get envelope and its Reflect ID. It's sender me, than must be an outcoming message!
        if message.fromIdentity == frameworkInjector.myIdentityStore.identity {
            if message.flagGroupMessage() {
                guard let groupID = (message as? AbstractGroupMessage)?.groupID,
                      let groupCreator = (message as? AbstractGroupMessage)?.groupCreator else {
                    throw TaskExecutionError.reflectMessageFailed(message: message.loggingDescription)
                }
                
                envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
                    type: Int32(message.type()),
                    body: message.body(),
                    messageID: message.messageID.convert(),
                    groupID: groupID.convert(),
                    groupCreatorIdentity: groupCreator,
                    createdAt: message.date
                )
            }
            else {
                envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
                    type: Int32(message.type()),
                    body: message.body(),
                    messageID: message.messageID.convert(),
                    receiverIdentity: message.toIdentity,
                    createdAt: message.date
                )
            }
        }
        else {
            envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForIncomingMessage(
                type: Int32(message.type()),
                body: message.body(),
                messageID: message.messageID.convert(),
                senderIdentity: message.fromIdentity,
                createdAt: message.date
            )
        }
        
        try reflectMessage(envelope: envelope, ltReflect: ltReflect, ltAck: ltAck)
    }

    /// Reflect message to mediator server.
    /// - Parameters:
    ///     - envelope: Envelope message for sending to mediator
    ///     - ltReflect: Logging Tag for reflect message
    ///     - ltAck: Logging Tag for ack reflect message
    /// - Throws: TaskExecutionError.createReflectedMessageFailed, TaskExecutionError.reflectMessageTimeout
    func reflectMessage(envelope: D2d_Envelope, ltReflect: LoggingTag, ltAck: LoggingTag) throws {
        assert(ltReflect != .none && ltAck != .none)

        let reflectData = frameworkInjector.mediatorMessageProtocol.encodeEnvelope(envelope: envelope)

        guard let reflectID = reflectData.reflectID, let reflectMessage = reflectData.reflectMessage else {
            throw TaskExecutionError.createReflectedMessageFailed
        }

        let loggingMsgInfo = "(Reflect ID: \(reflectID.hexString) \(envelope.loggingDescription))"

        let mediatorMessageAck = DispatchGroup()
        let notificationCenter = NotificationCenter.default
        var mediatorMessageAckObserver: NSObjectProtocol?

        mediatorMessageAckObserver = notificationCenter.addObserver(
            forName: TaskManager.mediatorMessageAckObserverName(reflectID: reflectID),
            object: nil,
            queue: OperationQueue.current
        ) { notification in

            if let messageAckReflectID = notification.object as? Data {
                if messageAckReflectID.elementsEqual(reflectID) {
                    DDLogNotice("\(ltAck.hexString) \(ltAck) \(loggingMsgInfo)")
                    notificationCenter.removeObserver(mediatorMessageAckObserver!)

                    mediatorMessageAck.leave()
                }
            }
        }
        mediatorMessageAck.enter()

        DDLogNotice("\(ltReflect.hexString) \(ltReflect) \(loggingMsgInfo)")
        if frameworkInjector.serverConnector.reflectMessage(reflectMessage) {
            let result = mediatorMessageAck.wait(timeout: .now() + .seconds(responseTimeoutInSeconds))
            if result != .success {
                notificationCenter.removeObserver(mediatorMessageAckObserver!)
                throw TaskExecutionError.reflectMessageTimeout(message: loggingMsgInfo)
            }
        }
        else {
            notificationCenter.removeObserver(mediatorMessageAckObserver!)
            throw TaskExecutionError.reflectMessageFailed(message: loggingMsgInfo)
        }
    }

    /// Send abstract message to chat server.
    /// - Parameters:
    ///     - message: Message to send
    ///     - ltSend: Logging Tag for send message
    ///     - ltAck: Logging Tag for ack send message
    /// - Returns: AbstractMessage if message was sent otherwise nil
    /// - Throws: TaskExecutionError.sendMessageFailed, TaskExecutionError.sendMessageTimeout
    func sendMessage(
        message: AbstractMessage,
        ltSend: LoggingTag,
        ltAck: LoggingTag
    ) -> Promise<AbstractMessage?> {
        Promise { seal in
            assert(ltSend != .none && ltAck != .none)

            frameworkInjector.backgroundEntityManager.performBlock {
                guard let toContact = self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .contact(for: message.toIdentity) else {
                    seal.reject(
                        TaskExecutionError
                            .sendMessageFailed(
                                message: "Contact not found for identity \(String(describing: message.toIdentity)) (\(String(describing: message.loggingDescription)))"
                            )
                    )
                    return
                }

                guard toContact.isValid() else {
                    let msg =
                        "Do not sending message to invalid identity \(String(describing: message.toIdentity)) (\(String(describing: message.loggingDescription)))"
                    guard message.flagGroupMessage() else {
                        seal.reject(TaskExecutionError.invalidContact(message: msg))
                        return
                    }
                    DDLogWarn(msg)

                    seal.fulfill(nil)
                    return
                }

                if let task = self.taskDefinition as? TaskDefinitionSendMessageProtocol,
                   let toIdentity = message.toIdentity {
                    guard !self.isMessageAlreadySentTo(identity: toIdentity) else {
                        DDLogWarn(
                            "Message already sent \(toIdentity)) (\(String(describing: message.loggingDescription)))"
                        )
                        seal.fulfill(message)
                        return
                    }
                }

                var messageToSend = message
                var auxMessage: ForwardSecurityEnvelopeMessage?
                var sendCompletion: (() throws -> Void)?
                var sendAuxFailure: (() -> Void)?

                // Check whether the message and the destination contact support forward security
                if ThreemaUtility.supportsForwardSecurity, message.supportsForwardSecurity(),
                   toContact.forwardSecurityEnabled.boolValue,
                   toContact.isForwardSecurityAvailable() {
                    do {
                        let fsContact = ForwardSecurityContact(
                            identity: toContact.identity,
                            publicKey: toContact.publicKey
                        )
                        (
                            auxMessage: auxMessage,
                            message: messageToSend,
                            sendCompletion: sendCompletion,
                            sendAuxFailure: sendAuxFailure
                        ) = try self
                            .frameworkInjector.fsmp.makeMessage(
                                contact: fsContact,
                                innerMessage: message
                            )
                    }
                    catch {
                        seal.reject(error)
                        return
                    }
                }

                // Send message in own thread, because of possible network latency
                DispatchQueue.global().async {
                    if let auxMessage = auxMessage {
                        var boxAuxMsg: BoxedMessage?
                        // We have an auxiliary (control) message to send before the actual message
                        self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                            boxAuxMsg = auxMessage.makeBox(
                                toContact,
                                myIdentityStore: self.frameworkInjector.myIdentityStore
                            )
                        }

                        guard let boxAuxMsg else {
                            sendAuxFailure?()
                            let err = TaskExecutionError.sendMessageFailed(message: auxMessage.loggingDescription)
                            seal.reject(err)
                            return
                        }

                        do {
                            try self.sendAndWait(
                                abstractMessage: auxMessage,
                                boxMessage: boxAuxMsg,
                                ltSend: ltSend,
                                ltAck: ltAck,
                                isAuxMessage: true
                            )
                        }
                        catch {
                            sendAuxFailure?()
                            let err = TaskExecutionError.sendMessageFailed(message: auxMessage.loggingDescription)
                            seal.reject(err)
                            return
                        }
                    }
                    self.frameworkInjector.backgroundEntityManager.performBlock {
                        // Save forward security mode in any case (could also be a message first sent with FS and then resent without)
                        self.frameworkInjector.backgroundEntityManager.setForwardSecurityMode(
                            message.messageID,
                            forwardSecurityMode: messageToSend.forwardSecurityMode
                        )

                        guard let boxMsg = messageToSend.makeBox(
                            toContact,
                            myIdentityStore: self.frameworkInjector.myIdentityStore
                        ) else {
                            seal.reject(TaskExecutionError.sendMessageFailed(message: message.loggingDescription))
                            return
                        }

                        if !message.flagDontQueue() {
                            do {
                                let nonceGuard = NonceGuard(
                                    entityManager: self.frameworkInjector
                                        .backgroundEntityManager
                                )
                                try nonceGuard.processed(boxedMessage: boxMsg)
                            }
                            catch {
                                seal.reject(error)
                                return
                            }
                        }

                        DispatchQueue.global().async {
                            do {
                                try self.sendAndWait(
                                    abstractMessage: messageToSend,
                                    boxMessage: boxMsg,
                                    ltSend: ltSend,
                                    ltAck: ltAck,
                                    isAuxMessage: false
                                )

                                do {
                                    try sendCompletion?()
                                }
                                catch {
                                    let msg = "An error occurred when saving PFS state: \(error)"
                                    DDLogError(msg)
                                    assertionFailure(msg)
                                }
                            }
                            catch {
                                seal.reject(error)
                                return
                            }

                            seal.fulfill(message)
                        }
                    }
                }
            }
        }
    }
    
    private func sendAndWait(
        abstractMessage: AbstractMessage,
        boxMessage: BoxedMessage,
        ltSend: LoggingTag,
        ltAck: LoggingTag,
        isAuxMessage: Bool
    ) throws {
        assert(abstractMessage.fromIdentity == nil || abstractMessage.fromIdentity == boxMessage.fromIdentity)
        assert(abstractMessage.toIdentity == boxMessage.toIdentity)
        
        let chatMessageAck = DispatchGroup()
        let notificationCenter = NotificationCenter.default
        var messageAckObserver: NSObjectProtocol?
        
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        
        messageAckObserver = notificationCenter.addObserver(
            forName: TaskManager.chatMessageAckObserverName(
                messageID: abstractMessage.messageID,
                toIdentity: abstractMessage.toIdentity
            ),
            object: nil,
            queue: operationQueue
        ) { _ in
            DDLogNotice("\(ltAck.hexString) \(ltAck) \(abstractMessage.loggingDescription)")
            notificationCenter.removeObserver(messageAckObserver!)
            chatMessageAck.leave()
        }
        
        chatMessageAck.enter()
        
        DDLogNotice("\(ltSend.hexString) \(ltSend) \(abstractMessage.loggingDescription)")
        if frameworkInjector.serverConnector.send(boxMessage) {
            if abstractMessage.flagDontAck() {
                notificationCenter.removeObserver(messageAckObserver!)
            }
            else {
                let result = chatMessageAck.wait(timeout: .now() + .seconds(responseTimeoutInSeconds))
                if result == .success {
                    if !isAuxMessage, let toIdentity = abstractMessage.toIdentity {
                        messageAlreadySentTo(identity: toIdentity)
                    }
                }
                else {
                    notificationCenter.removeObserver(messageAckObserver!)
                    throw TaskExecutionError.sendMessageTimeout(message: abstractMessage.loggingDescription)
                }
            }
        }
        else {
            notificationCenter.removeObserver(messageAckObserver!)
            throw TaskExecutionError.sendMessageFailed(message: abstractMessage.loggingDescription)
        }
    }

    private func isMessageAlreadySentTo(identity: String) -> Bool {
        guard let task = taskDefinition as? TaskDefinitionSendMessageProtocol else {
            return false
        }

        var isMessageAlreadySentTo = false
        task.messageAlreadySentToQueue.sync {
            isMessageAlreadySentTo = task.messageAlreadySentTo.contains(identity)
        }
        return isMessageAlreadySentTo
    }

    private func messageAlreadySentTo(identity: String) {
        guard var task = taskDefinition as? TaskDefinitionSendMessageProtocol else {
            return
        }

        task.messageAlreadySentToQueue.sync {
            task.messageAlreadySentTo.append(identity)
        }
    }

    /// If group creator an gateway id and receiver and store-incoming-message is not set (group name without ☁), then the message (except leave and request sync) will not be send.
    ///
    /// - Parameter groupCreatorIdentity: Group creator identity
    /// - Parameter groupName: Group name
    /// - Parameter message: Message send to group
    /// - Returns: True send message, false not
    func canSendGroupMessageToGatewayID(
        groupCreatorIdentity: String,
        groupName: String?,
        message: AbstractMessage
    ) -> Bool {
        if groupCreatorIdentity.hasPrefix("*"), groupCreatorIdentity.elementsEqual(message.toIdentity),
           !(groupName?.hasPrefix("☁") ?? false), !(message is GroupLeaveMessage),
           !(message is GroupRequestSyncMessage) {
            DDLogWarn("Drop message to gateway id without store-incoming-message")
            frameworkInjector.backgroundEntityManager.markMessageAsSent(message.messageID, isLocal: true)

            return false
        }

        return true
    }

    /// Get conversation for TaskDefinitionSendBaseMessage or TaskDefinitionSendBallotVoteMessage.
    ///
    /// - Parameter task: Task definition
    /// - Returns: Conversation or nil
    func getConversation(_ task: TaskDefinitionProtocol) -> Conversation? {
        var conversation: Conversation?
        if let task = task as? TaskDefinitionSendBaseMessage,
           let groupCreatorIdentity = task.groupCreatorIdentity ?? frameworkInjector.myIdentityStore.identity,
           let internalConversation = task.isGroupMessage ? frameworkInjector.backgroundEntityManager.entityFetcher
           .conversation(
               for: task.groupID!,
               creator: groupCreatorIdentity
           ) : frameworkInjector.backgroundEntityManager.entityFetcher.ownMessage(with: task.messageID)?.conversation {
            conversation = internalConversation
        }
        else if let task = task as? TaskDefinitionSendBallotVoteMessage,
                let ballot = frameworkInjector.backgroundEntityManager.entityFetcher
                .ballot(for: task.ballotID) {
            conversation = ballot.conversation
        }
        return conversation
    }
    
    // MARK: Abstract Message Types
    
    /// Create abstract message for base message (Core Data Entity).
    ///
    /// - Parameter task: Task (TaskDefinitionSendBaseMessage or TaskDefinitionSendBallotVoteMessage) with Core Data Entity
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message or nil if could not create
    func getAbstractMessage(
        _ task: TaskDefinitionProtocol,
        _ fromIdentity: String,
        _ toIdentity: String
    ) -> AbstractMessage? {
        
        if let task = task as? TaskDefinitionSendBaseMessage,
           let conversation = task.isGroupMessage ? frameworkInjector.backgroundEntityManager.entityFetcher
           .conversation(
               for: task.groupID!,
               creator: task.groupCreatorIdentity!
           ) : frameworkInjector.backgroundEntityManager.entityFetcher.ownMessage(with: task.messageID)?.conversation,
           let message = frameworkInjector.backgroundEntityManager.entityFetcher.message(
               with: task.messageID,
               conversation: conversation
           ) {

            if let message = message as? TextMessage {
                let msg: AbstractMessage = task.isGroupMessage ? GroupTextMessage() : BoxTextMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                                
                if task.isGroupMessage,
                   let msg = msg as? GroupTextMessage {
                    
                    msg.text = message.quotedMessageID != nil ? QuoteUtil.generateText(
                        message.text,
                        with: message.quotedMessageID
                    ) : message.text
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxTextMessage {
                    msg.text = message.quotedMessageID != nil ? QuoteUtil.generateText(
                        message.text,
                        with: message.quotedMessageID
                    ) : message.text
                }
                return msg
            }
            else if let message = message as? LocationMessage {
                let msg: AbstractMessage = task.isGroupMessage ? GroupLocationMessage() : BoxLocationMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                if task.isGroupMessage,
                   let msg = msg as? GroupLocationMessage {
                    
                    msg.latitude = message.latitude as! Double
                    msg.longitude = message.longitude as! Double
                    msg.accuracy = message.accuracy as! Double
                    msg.poiName = message.poiName
                    if let task = task as? TaskDefinitionSendLocationMessage {
                        msg.poiAddress = task.poiAddress
                    }
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxLocationMessage {
                    msg.latitude = message.latitude as! Double
                    msg.longitude = message.longitude as! Double
                    msg.accuracy = message.accuracy as! Double
                    msg.poiName = message.poiName
                    if let task = task as? TaskDefinitionSendLocationMessage {
                        msg.poiAddress = task.poiAddress
                    }
                }
                return msg
            }
            else if let message = message as? BallotMessage {
                let msg: BoxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(for: message.ballot)
                msg.messageID = message.id
                if let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity,
                   let conversationEntity = frameworkInjector.backgroundGroupManager
                   .getConversation(for: GroupIdentity(id: groupID, creator: groupCreatorIdentity)) {
                    let groupMsg: GroupBallotCreateMessage = BallotMessageEncoder.groupBallotCreateMessage(
                        from: msg,
                        for: conversationEntity
                    )
                    groupMsg.fromIdentity = fromIdentity
                    groupMsg.toIdentity = toIdentity
                    groupMsg.date = message.date
                    return groupMsg
                }
                else {
                    msg.fromIdentity = fromIdentity
                    msg.toIdentity = toIdentity
                    msg.date = message.date
                    return msg
                }
            }
            else if let message = message as? ImageMessageEntity {
                let msg: AbstractMessage = task.isGroupMessage ? GroupImageMessage() : BoxImageMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                if task.isGroupMessage,
                   let msg = msg as? GroupImageMessage {
                    
                    msg.blobID = message.imageBlobID
                    msg.encryptionKey = message.encryptionKey
                    msg.size = UInt32(exactly: message.imageSize)!
                    
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxImageMessage {
                    msg.blobID = message.imageBlobID
                    msg.imageNonce = message.imageNonce
                    msg.size = UInt32(exactly: message.imageSize)!
                }
                return msg
            }
            else if let message = message as? AudioMessageEntity {
                let msg: AbstractMessage = task.isGroupMessage ? GroupAudioMessage() : BoxAudioMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                if task.isGroupMessage,
                   let msg = msg as? GroupAudioMessage {
                    
                    msg.audioBlobID = message.audioBlobID
                    msg.encryptionKey = message.encryptionKey
                    msg.audioSize = UInt32(exactly: message.audioSize)!
                    msg.duration = UInt16(message.duration.floatValue)

                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxAudioMessage {
                    msg.audioBlobID = message.audioBlobID
                    msg.encryptionKey = message.encryptionKey
                    msg.audioSize = UInt32(exactly: message.audioSize)!
                    msg.duration = UInt16(message.duration.floatValue)
                }
                return msg
            }
            else if let message = message as? FileMessageEntity {
                if task.isGroupMessage {
                    let msg: GroupFileMessage = FileMessageEncoder.encodeGroupFileMessageEntity(message)
                    msg.fromIdentity = fromIdentity
                    msg.toIdentity = toIdentity
                    msg.messageID = message.id
                    msg.date = message.date
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                    return msg
                }
                else {
                    let msg: BoxFileMessage = FileMessageEncoder.encode(message)
                    msg.fromIdentity = fromIdentity
                    msg.toIdentity = toIdentity
                    msg.messageID = message.id
                    msg.date = message.date
                    return msg
                }
            }
            else if let message = message as? VideoMessageEntity {
                let msg: AbstractMessage = task.isGroupMessage ? GroupVideoMessage() : BoxVideoMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                if task.isGroupMessage,
                   let msg = msg as? GroupVideoMessage {
                    
                    msg.videoBlobID = message.videoBlobID
                    msg.encryptionKey = message.encryptionKey
                    msg.videoSize = UInt32(exactly: message.videoSize)!
                    msg.duration = UInt16(message.duration.floatValue)
                    if let task = task as? TaskDefinitionSendVideoMessage {
                        msg.thumbnailBlobID = task.thumbnailBlobID
                        if let thumbnailSize = task.thumbnailSize {
                            msg.thumbnailSize = UInt32(exactly: thumbnailSize)!
                        }
                    }

                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxVideoMessage {
                    msg.videoBlobID = message.videoBlobID
                    msg.encryptionKey = message.encryptionKey
                    msg.videoSize = UInt32(exactly: message.videoSize)!
                    msg.duration = UInt16(message.duration.floatValue)
                    if let task = task as? TaskDefinitionSendVideoMessage {
                        msg.thumbnailBlobID = task.thumbnailBlobID
                        if let thumbnailSize = task.thumbnailSize {
                            msg.thumbnailSize = UInt32(exactly: thumbnailSize)!
                        }
                    }
                }
                return msg
            }
        }
        else if let task = task as? TaskDefinitionSendBallotVoteMessage,
                let ballot = frameworkInjector.backgroundEntityManager.entityFetcher
                .ballot(for: task.ballotID) {

            let msg: BoxBallotVoteMessage = BallotMessageEncoder.encodeVoteMessage(for: ballot)
            if let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity,
               let conversationEntity = frameworkInjector.backgroundGroupManager
               .getConversation(for: GroupIdentity(id: groupID, creator: groupCreatorIdentity)) {
                let groupMsg: GroupBallotVoteMessage = BallotMessageEncoder.groupBallotVoteMessage(
                    from: msg,
                    for: conversationEntity
                )
                groupMsg.fromIdentity = fromIdentity
                groupMsg.toIdentity = toIdentity
                return groupMsg
            }
            else {
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                return msg
            }
        }
        
        return nil
    }

    /// Create abstract message for group create.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Parameter groupMembers: Array of group member identities
    /// - Returns: Abstract message
    func getGroupCreateMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toIdentity: String,
        _ groupMembers: [String]
    ) -> GroupCreateMessage {
        
        let msg = GroupCreateMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toIdentity
        msg.groupMembers = groupMembers
        return msg
    }
    
    /// Create abstract message for group leave.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message
    func getGroupLeaveMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toMember: String
    ) -> GroupLeaveMessage {
        let msg = GroupLeaveMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        return msg
    }
    
    /// Create abstract message for group rename.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Parameter name: Name of the group
    /// - Returns: Abstract message
    func getGroupRenameMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toMember: String,
        _ name: String?
    ) -> GroupRenameMessage {
        let msg = GroupRenameMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        msg.name = name
        return msg
    }
    
    /// Create abstract message for group photo.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Parameter size: Image size
    /// - Parameter blobID: Image Blob ID
    /// - Parameter encryptionKey: Encryption key to decrypting blob
    /// - Returns: Abstract message
    func getGroupSetPhotoMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toMember: String,
        _ size: UInt32,
        _ blobID: Data?,
        _ encryptionKey: Data?
    ) -> GroupSetPhotoMessage {
        let msg = GroupSetPhotoMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        msg.size = size
        msg.blobID = blobID
        msg.encryptionKey = encryptionKey
        return msg
    }
    
    /// Create abstract message for group delete photo.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message
    func getGroupDeletePhotoMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toMember: String
    ) -> GroupDeletePhotoMessage {
        let msg = GroupDeletePhotoMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        return msg
    }
    
    /// Create abstract message for group delivery receipt.
    ///
    /// - Parameter groupID: ID of the group
    /// - Parameter groupCreator: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message
    func getGroupDeliveryReceiptMessage(
        _ groupID: Data,
        _ groupCreator: String,
        _ fromIdentity: String,
        _ toMember: String,
        _ receiptType: UInt8,
        _ receiptMessageIDs: [Data]
    ) -> GroupDeliveryReceiptMessage {
        let msg = GroupDeliveryReceiptMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreator
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        msg.receiptType = receiptType
        msg.receiptMessageIDs = receiptMessageIDs
        
        return msg
    }
}
