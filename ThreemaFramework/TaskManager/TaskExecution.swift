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
import ThreemaEssentials
import ThreemaProtocols

enum TaskExecutionError: Error {
    case conversationNotFound(for: TaskDefinitionProtocol)
    case createAbstractMessageFailed
    case createReflectedMessageFailed
    case multiDeviceNotRegistered
    case makeBoxOfMessageFailed
    case messageReceiverBlockedOrUnknown
    case messageTypeMismatch(message: String?)
    case missingGroupInformation
    case missingMessageInformation
    case missingMessageNonce
    case processIncomingMessageFailed(message: String?)
    case reflectMessageFailed(message: String?)
    case reflectMessageTimeout(message: String?)
    case sendMessageFailed(message: String)
    case sendMessageTimeout(message: String)
    case wrongTaskDefinitionType
    case invalidContact(message: String)
    case ownContact(message: String)
    case multiDeviceNotSupported
    case nonceGenerationFailed
    case taskDropped
    case decryptMessageFailed(reflectID: String)
}

extension TaskDefinition {
    /// Check if task is dropped and throws `TaskExecutionError.taskDropped` if this is the case
    func checkDropping() throws {
        if isDropped {
            throw TaskExecutionError.taskDropped
        }
    }
}

class TaskExecution: NSObject {
    var taskContext: TaskContextProtocol
    var taskDefinition: TaskDefinitionProtocol
    let frameworkInjector: FrameworkInjectorProtocol

    private let responseTimeoutInSeconds = 40
    
    required init(
        taskContext: TaskContextProtocol,
        taskDefinition: TaskDefinitionProtocol,
        backgroundFrameworkInjector: FrameworkInjectorProtocol
    ) {
        self.taskContext = taskContext
        self.taskDefinition = taskDefinition
        self.frameworkInjector = backgroundFrameworkInjector
    }
    
    required convenience init(taskContext: TaskContextProtocol, taskDefinition: TaskDefinitionProtocol) {
        self.init(
            taskContext: taskContext,
            taskDefinition: taskDefinition,
            backgroundFrameworkInjector: BusinessInjector(forBackgroundProcess: true)
        )
    }

    // MARK: Promises
    
    func isMultiDeviceRegistered() -> Guarantee<Bool> {
        Guarantee { $0(frameworkInjector.userSettings.enableMultiDevice) }
    }
    
    /// Reflect message to mediator server.
    /// - Parameters:
    ///     - message: Message to reflect
    ///     - ltReflect: Logging Tag for reflect message
    ///     - ltAck: Logging Tag for ack reflect message
    /// - Returns: Reflected at
    /// - Throws: TaskExecutionError.reflectMessageFailed
    @discardableResult
    func reflectMessage(message: AbstractMessage, ltReflect: LoggingTag, ltAck: LoggingTag) throws -> Date {
        assert(ltReflect != .none && ltAck != .none)

        var envelope: D2d_Envelope

        let body: Data? =
            if let quotedMessage = message as? QuotedMessageProtocol {
                quotedMessage.quotedBody()
            }
            else {
                message.body()
            }

        // Get envelope and its Reflect ID. It's sender me, than must be an outgoing message!
        if message.fromIdentity == frameworkInjector.myIdentityStore.identity {
            if message.flagGroupMessage() {
                guard let groupID = (message as? AbstractGroupMessage)?.groupID,
                      let groupCreator = (message as? AbstractGroupMessage)?.groupCreator else {
                    throw TaskExecutionError.reflectMessageFailed(message: message.loggingDescription)
                }

                envelope = try frameworkInjector.mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
                    type: Int32(message.type()),
                    body: body,
                    messageID: message.messageID.littleEndian(),
                    groupID: groupID.littleEndian(),
                    groupCreatorIdentity: groupCreator,
                    createdAt: message.date,
                    nonces: messageNonces(),
                    deviceID: frameworkInjector.multiDeviceManager.thisDevice.deviceID
                )
            }
            else {
                envelope = try frameworkInjector.mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
                    type: Int32(message.type()),
                    body: body,
                    messageID: message.messageID.littleEndian(),
                    receiverIdentity: message.toIdentity,
                    createdAt: message.date,
                    nonce: messageNonce(for: message.toIdentity),
                    deviceID: frameworkInjector.multiDeviceManager.thisDevice.deviceID
                )
            }
        }
        else {
            envelope = try frameworkInjector.mediatorMessageProtocol.getEnvelopeForIncomingMessage(
                type: Int32(message.type()),
                body: body,
                messageID: message.messageID.littleEndian(),
                senderIdentity: message.fromIdentity,
                createdAt: message.date,
                nonce: messageNonce(for: message.fromIdentity)
            )
        }
        
        return try reflectMessage(envelope: envelope, ltReflect: ltReflect, ltAck: ltAck)
    }

    /// Reflect message to mediator server.
    /// - Parameters:
    ///     - envelope: Envelope message for sending to mediator
    ///     - ltReflect: Logging Tag for reflect message
    ///     - ltAck: Logging Tag for ack reflect message
    /// - Returns: Reflected at
    /// - Throws: TaskExecutionError.createReflectedMessageFailed, TaskExecutionError.reflectMessageTimeout
    @discardableResult
    func reflectMessage(envelope: D2d_Envelope, ltReflect: LoggingTag, ltAck: LoggingTag) throws -> Date {
        assert(ltReflect != .none && ltAck != .none)

        let reflectData = frameworkInjector.mediatorMessageProtocol.encodeEnvelope(envelope: envelope)

        guard let reflectID = reflectData.reflectID, let reflectMessage = reflectData.reflectMessage else {
            throw TaskExecutionError.createReflectedMessageFailed
        }

        var reflectedAt: Date?

        let loggingMsgInfo = "(Reflect ID: \(reflectID.hexString) \(envelope.loggingDescription))"

        let mediatorMessageAck = DispatchGroup()
        let notificationCenter = NotificationCenter.default
        var mediatorMessageAckObserver: NSObjectProtocol?

        mediatorMessageAckObserver = notificationCenter.addObserver(
            forName: TaskManager.mediatorMessageAckObserverName(reflectID: reflectID),
            object: nil,
            queue: OperationQueue.current
        ) { notification in
            // Get reflected-ack ID and reflected-ack sent date
            if let messageAckReflectID = notification.object as? Data {
                if messageAckReflectID.elementsEqual(reflectID) {

                    reflectedAt = notification.userInfo?[reflectID] as? Date

                    DDLogNotice("\(ltAck.hexString) \(ltAck) \(loggingMsgInfo)")
                    notificationCenter.removeObserver(mediatorMessageAckObserver!)

                    mediatorMessageAck.leave()
                }
            }
        }
        mediatorMessageAck.enter()

        DDLogNotice("\(ltReflect.hexString) \(ltReflect) \(loggingMsgInfo)")
        if let error = frameworkInjector.serverConnector.reflectMessage(reflectMessage) {
            notificationCenter.removeObserver(mediatorMessageAckObserver!)
            throw error
        }

        guard mediatorMessageAck.wait(timeout: .now() + .seconds(responseTimeoutInSeconds)) == .success else {
            notificationCenter.removeObserver(mediatorMessageAckObserver!)
            throw TaskExecutionError.reflectMessageTimeout(message: loggingMsgInfo)
        }

        guard let reflectedAt else {
            notificationCenter.removeObserver(mediatorMessageAckObserver!)
            throw TaskExecutionError.reflectMessageFailed(message: "Reflected at is nil for \(loggingMsgInfo)")
        }

        return reflectedAt
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
        // This is implemented as a separated promise step as there was no easy way to implement a way to wait for the
        // fetch of the feature mask to complete, if needed.
        // TODO: (IOS-4348) See if we can optimize that more
        firstly { () -> Promise<Void> in
            Promise { seal in
                self.frameworkInjector.entityManager.performBlock {
                    guard let toContact = self.frameworkInjector.entityManager.entityFetcher.contact(
                        for: message.toIdentity
                    ) else {
                        return seal.reject(TaskExecutionError.sendMessageFailed(
                            message: "Contact not found for identity \(message.toIdentity ?? "no identity") (\(message.loggingDescription))"
                        ))
                    }
                    
                    // If the contact has a feature mask that is 0 it was probably never fetched. This can happen if the
                    // field changes after an update to 5.9 (IOS-4220). This is a problem, because eligibility for
                    // sending FS messages is determined base on the feature mask. Thus we try to fetch the feature mask
                    // if it is 0.
                    if toContact.featureMask == 0 {
                        DDLogNotice("Fetch feature mask of \(toContact.identity), because it is currently 0.")
                        self.frameworkInjector.contactStore.updateFeatureMasks(forIdentities: [toContact.identity]) {
                            seal.fulfill_()
                        } onError: { _ in
                            DDLogWarn(
                                "Failed to update feature mask of \(toContact.identity). Current value \(toContact.featureMask)"
                            )
                            // This is a best effort, thus we will always succeed
                            seal.fulfill_()
                        }
                    }
                    else {
                        seal.fulfill_()
                    }
                }
            }
        }
        .then { _ in
            self.sendMessageInternal(message: message, ltSend: ltSend, ltAck: ltAck)
        }
    }
    
    /// Internal part of `sendMessage(message:ltSend:ltAck:)`
    ///
    /// This is left as is to reduce the changes introduced with the feature mask check in
    /// `sendMessage(message:ltSend:ltAck:)` with IOS-4475
    /// TODO: (IOS-4348) Try to clean this up
    private func sendMessageInternal(
        message: AbstractMessage,
        ltSend: LoggingTag,
        ltAck: LoggingTag
    ) -> Promise<AbstractMessage?> {
        Promise { seal in
            assert(ltSend != .none && ltAck != .none)
            
            guard message.toIdentity != self.frameworkInjector.myIdentityStore.identity else {
                seal.reject(TaskExecutionError.sendMessageFailed(
                    message: "Do not sending message to own identity \(String(describing: message.toIdentity)) (\(String(describing: message.loggingDescription)))"
                ))
                return
            }

            frameworkInjector.entityManager.performBlock {
                guard let toContact = self.frameworkInjector.entityManager.entityFetcher
                    .contact(for: message.toIdentity) else {
                    seal.reject(TaskExecutionError.sendMessageFailed(
                        message: "Contact not found for identity \(message.toIdentity ?? "no identity") (\(message.loggingDescription))"
                    ))
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
                            "Message already sent to \(toIdentity)) (\(String(describing: message.loggingDescription)))"
                        )
                        seal.fulfill(message)
                        return
                    }
                }

                var auxMessage: ForwardSecurityEnvelopeMessage?
                var messageToSend = message

                // Check whether the message is not already an FS message and the destination contact supports forward
                // security (Common Send Steps (6.1))
                if ThreemaEnvironment.supportsForwardSecurity,
                   !(message is ForwardSecurityEnvelopeMessage),
                   toContact.isForwardSecurityAvailable() {
                    do {
                        let fsContact = ForwardSecurityContact(
                            identity: toContact.identity,
                            publicKey: toContact.publicKey
                        )
                        
                        (auxMessage, messageToSend) = try self.frameworkInjector.fsmp.makeMessage(
                            receiver: fsContact,
                            innerMessage: message
                        )
                    }
                    catch {
                        seal.reject(error)
                        return
                    }
                }
                else {
                    if !ThreemaEnvironment.supportsForwardSecurity {
                        DDLogDebug(
                            "[ForwardSecurity] Don't try sending \(message.loggingDescription) with FS, because FS is not supported"
                        )
                    }
                    else if message is ForwardSecurityEnvelopeMessage {
                        DDLogDebug(
                            "[ForwardSecurity] Don't try sending \(message.loggingDescription) with FS, because it is already an FS message"
                        )
                    }
                    else if !toContact.isForwardSecurityAvailable() {
                        DDLogNotice(
                            "[ForwardSecurity] Don't try sending \(message.loggingDescription) with FS, because \(toContact.identity) doesn't support it: featureMask=\(toContact.featureMask)"
                        )
                    }
                }

                // TODO: (IOS-4348) Optimize messages sending
                // Sending can be optimized, because the messages need to be sent in order, but we only need to wait at
                // the end for all server acks. One possible implementation is to do the sending in order an then return
                // a promise that resolves when the server ack is received. So after sending all the messages we wait
                // for all the server acks.
                
                // Send message in own thread, because of possible network latency
                DispatchQueue.global().async {
                    if let auxMessage {
                        
                        let failure = {
                            let err = TaskExecutionError.sendMessageFailed(message: auxMessage.loggingDescription)
                            seal.reject(err)
                        }
                        
                        guard let nonce = NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.nonceLength)) else {
                            seal.reject(TaskExecutionError.nonceGenerationFailed)
                            return
                        }
                        
                        // We have an auxiliary (control) message to send before the actual message
                        guard let boxAuxMsg = self.frameworkInjector.entityManager.performAndWait({
                            auxMessage.makeBox(
                                toContact,
                                myIdentityStore: self.frameworkInjector.myIdentityStore,
                                nonce: nonce
                            )
                        }) else {
                            failure()
                            return
                        }
                        
                        // TODO: (IOS-4751) Check as described in protocol, see ticket for more information
                        if !auxMessage.flagDontQueue() {
                            do {
                                try self.frameworkInjector.nonceGuard.processed(boxedMessage: boxAuxMsg)
                            }
                            catch {
                                seal.reject(error)
                                return
                            }
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
                            failure()
                            return
                        }
                    }
                    
                    self.frameworkInjector.entityManager.performBlock {
                        var nonce: Data
                        do {
                            nonce = try self.messageNonce(for: toContact.identity)
                        }
                        catch {
                            seal.reject(
                                TaskExecutionError.sendMessageFailed(message: "\(error) \(message.loggingDescription)")
                            )
                            return
                        }

                        guard let boxMsg = messageToSend.makeBox(
                            toContact,
                            myIdentityStore: self.frameworkInjector.myIdentityStore,
                            nonce: nonce
                        ) else {
                            seal.reject(TaskExecutionError.sendMessageFailed(message: message.loggingDescription))
                            return
                        }

                        // TODO: (IOS-4751) Check as described in protocol, see ticket for more information
                        if !message.flagDontQueue() {
                            do {
                                try self.frameworkInjector.nonceGuard.processed(boxedMessage: boxMsg)
                            }
                            catch {
                                seal.reject(error)
                                return
                            }
                        }

                        // TODO: (IOS-4348) Why is this `.utility`, but aux `.default`?
                        DispatchQueue.global(qos: .utility).async {
                            do {
                                try self.sendAndWait(
                                    abstractMessage: messageToSend,
                                    boxMessage: boxMsg,
                                    ltSend: ltSend,
                                    ltAck: ltAck,
                                    isAuxMessage: false
                                )
                            }
                            catch {
                                seal.reject(error)
                                return
                            }
                            
                            // Commit new session (if needed) and update last message sent date if any message was an FS
                            // message.
                            // We do these checks independent of the `ForwardSecurityMessageProcessor` call because a
                            // message passed to `sendMessage(message:ltSend:ltAck:)` (most likely an FS control
                            // message) might already be of type `ForwardSecurityEnvelopeMessage`.
                            if let auxMessage {
                                self.commitNewSessionAndUpdateLastMessageSentDate(for: auxMessage)
                            }
                            else if let sentMessage = messageToSend as? ForwardSecurityEnvelopeMessage {
                                self.commitNewSessionAndUpdateLastMessageSentDate(for: sentMessage)
                            }

                            // We now know the FS mode so we also set it for the "inner" message
                            message.forwardSecurityMode = messageToSend.forwardSecurityMode
                            seal.fulfill(message)
                        }
                    }
                }
            }
        }
    }
    
    /// Send an `empty` message in the passed FS session
    ///
    /// Only use if you specifically want to send an `empty` message to enforce an session upgrade if possible. In
    /// general use `sendMessage()`.
    ///
    /// - Parameter session: Session to send `empty` message in
    /// - Returns: Promise that fulfills if sending completed with server ack and updated own ratchets, last sent and
    /// versions in `session`. Throws various errors if validation or sending fails
    func sendEmptyFSMessage(in session: DHSession) -> Promise<Void> {
        Promise { seal in
            let message: ForwardSecurityEnvelopeMessage
            do {
                message = try self.frameworkInjector.fsmp.makeEmptyMessage(for: session)
            }
            catch {
                seal.reject(error)
                return
            }
            
            guard message.toIdentity != self.frameworkInjector.myIdentityStore.identity else {
                seal.reject(TaskExecutionError.sendMessageFailed(
                    message: "Do not sending message to own identity \(message.toIdentity ?? "no identity") (\(message.loggingDescription))"
                ))
                return
            }
                
            // TODO: (IOS-4348) Maybe optimize messages sending here, too
            
            // Send message in own thread, because of possible network latency
            DispatchQueue.global().async {
                self.frameworkInjector.entityManager.performBlock {
                    guard let toContact = self.frameworkInjector.entityManager.entityFetcher
                        .contact(for: message.toIdentity) else {
                        seal.reject(TaskExecutionError.sendMessageFailed(
                            message: "Contact not found for identity \(message.toIdentity ?? "no identity") (\(message.loggingDescription))"
                        ))
                        return
                    }
                    
                    guard toContact.isValid() else {
                        let msg =
                            "Do not sending message to invalid identity \(message.toIdentity ?? "no identity") (\(message.loggingDescription))"
                        seal.reject(TaskExecutionError.invalidContact(message: msg))
                        return
                    }
                    
                    guard let nonce = NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.nonceLength)) else {
                        
                        seal.reject(TaskExecutionError.nonceGenerationFailed)
                        return
                    }

                    guard let boxMsg = message.makeBox(
                        toContact,
                        myIdentityStore: self.frameworkInjector.myIdentityStore,
                        nonce: nonce
                    ) else {
                        seal.reject(TaskExecutionError.sendMessageFailed(message: message.loggingDescription))
                        return
                    }
                    
                    // TODO: (IOS-4751) Check as described in protocol, see ticket for more information
                    if !message.flagDontQueue() {
                        do {
                            try self.frameworkInjector.nonceGuard.processed(boxedMessage: boxMsg)
                        }
                        catch {
                            seal.reject(error)
                            return
                        }
                    }
                    
                    do {
                        try self.sendAndWait(
                            abstractMessage: message,
                            boxMessage: boxMsg,
                            ltSend: .sendOutgoingMessageToChat,
                            ltAck: .receiveOutgoingMessageAckFromChat,
                            isAuxMessage: true
                        )
                    }
                    catch {
                        seal.reject(error)
                        return
                    }
                    
                    // Commit update last message sent date and versions
                    do {
                        session.lastMessageSent = .now
                        try self.frameworkInjector.dhSessionStore
                            .updateNewSessionCommitLastMessageSentDateAndVersions(session: session)
                    }
                    catch {
                        DDLogError(
                            "[ForwardSecrecy] Unable to persist send date and versions for sent empty message"
                        )
                    }
                    
                    seal.fulfill_()
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
                
        messageAckObserver = notificationCenter.addObserver(
            forName: TaskManager.chatMessageAckObserverName(
                messageID: abstractMessage.messageID,
                toIdentity: abstractMessage.toIdentity
            ),
            object: nil,
            queue: OperationQueue.current
        ) { _ in
            DDLogNotice(
                "\(ltAck.hexString) \(ltAck) \(abstractMessage.loggingDescription) from \(abstractMessage.toIdentity ?? "?")"
            )
            notificationCenter.removeObserver(messageAckObserver!)
            chatMessageAck.leave()
        }
        
        chatMessageAck.enter()
        
        DDLogNotice(
            "\(ltSend.hexString) \(ltSend) \(abstractMessage.loggingDescription) to \(abstractMessage.toIdentity ?? "?")"
        )
        if frameworkInjector.serverConnector.send(boxMessage) {
            if abstractMessage.flagDontAck() {
                notificationCenter.removeObserver(messageAckObserver!)
            }
            else {
                let result = chatMessageAck.wait(timeout: .now() + .seconds(responseTimeoutInSeconds))
                if result == .success {
                    if !isAuxMessage, let toIdentity = abstractMessage.toIdentity {
                        // Only non-AuxMessages need their nonces to be reflected and are thus stored
                        try messageAlreadySentTo(identity: toIdentity, nonce: messageNonce(for: toIdentity))
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

    private func commitNewSessionAndUpdateLastMessageSentDate(for message: ForwardSecurityEnvelopeMessage) {
        do {
            if let session = try frameworkInjector.dhSessionStore.exactDHSession(
                myIdentity: frameworkInjector.myIdentityStore.identity,
                peerIdentity: message.toIdentity,
                sessionID: message.data.sessionID
            ) {
                assert(
                    session.newSessionCommitted || message.data is ForwardSecurityDataInit,
                    "If the session was not committed before we should have sent out an Init"
                )

                // At this point we commit the session
                session.newSessionCommitted = true
                session.lastMessageSent = .now
                
                try frameworkInjector.dhSessionStore.updateNewSessionCommitLastMessageSentDateAndVersions(
                    session: session
                )
            }
            else {
                DDLogError("No session found for DH session with ID \(message.data.sessionID)")
            }
        }
        catch {
            DDLogError("Unable to commit and update session last message state: \(error)")
        }
    }
    
    private func isMessageAlreadySentTo(identity: String) -> Bool {
        guard let task = taskDefinition as? TaskDefinitionSendMessageProtocol else {
            return false
        }

        var isMessageAlreadySentTo = false
        task.messageAlreadySentToQueue.sync {
            isMessageAlreadySentTo = task.messageAlreadySentTo.map(\.key).contains(identity)
        }
        return isMessageAlreadySentTo
    }

    private func messageAlreadySentTo(identity: String, nonce: Data) {
        guard var task = taskDefinition as? TaskDefinitionSendMessageProtocol else {
            return
        }

        task.messageAlreadySentToQueue.sync {
            task.messageAlreadySentTo[identity] = nonce
        }
    }

    /// Generates new message nonces for the message receivers of the task.
    ///
    /// - Parameter task: Task must implement `TaskDefinitionSendMessageNonceProtocol`
    /// - Throws: `TaskExecutionError.missingMessageNonce` if task doesn't support nonces
    func generateMessageNonces(for task: TaskDefinitionProtocol) throws {
        guard task is TaskDefinitionSendMessageNonceProtocol else {
            throw TaskExecutionError.missingMessageNonce
        }

        // Get message receivers for this task
        var identities: Set<String>
        if let task = task as? TaskDefinitionSendAbstractMessage {
            identities = Set<String>([task.message.toIdentity])
        }
        else if let task = task as? TaskDefinitionSendDeliveryReceiptsMessage {
            identities = Set<String>([task.toIdentity])
        }
        else if let task = task as? TaskDefinitionGroupDissolve {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupCallStartMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupCreateMessage {
            identities = Set(task.toMembers)
            if let removeMembers = task.removedMembers {
                for member in removeMembers {
                    identities.insert(member)
                }
            }
        }
        else if let task = task as? TaskDefinitionSendGroupDeletePhotoMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupDeliveryReceiptsMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupLeaveMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupRenameMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendGroupSetPhotoMessage {
            identities = Set<String>(task.toMembers)
        }
        else if let task = task as? TaskDefinitionSendMessage {
            if task.isGroupMessage {
                guard let members = task.receivingGroupMembers else {
                    throw TaskExecutionError.missingGroupInformation
                }
                identities = members
            }
            else {
                guard let identity = try frameworkInjector.entityManager.performAndWait({
                    try self.getConversation(for: task).contact?.identity
                }) else {
                    throw TaskExecutionError.missingMessageInformation
                }
                identities = [identity]
            }
        }
        else if let task = task as? TaskDefinitionRunForwardSecurityRefreshSteps {
            identities = Set(task.contactIdentities.map(\.string))
        }
        else {
            throw TaskExecutionError.missingMessageNonce
        }

        DDLogNotice("\(task) generate nonces")
        try generateMessageNonces(for: identities)
    }

    /// Generates new message nonces to encrypt message for receivers (Threema ID). If is the message for the receiver
    /// already sent, using stored nonce instead.
    ///
    /// - Parameter identities: Message nonces for receivers
    /// - Throws: `TaskExecutionError.missingMessageNonce` if task doesn't support nonces
    private func generateMessageNonces(for identities: Set<String>) throws {
        guard var taskNonce = taskDefinition as? TaskDefinitionSendMessageNonceProtocol else {
            throw TaskExecutionError.missingMessageNonce
        }

        taskNonce.nonces.removeAll()

        var excludeReceivers = TaskReceiverNonce()
        if let taskSend = taskDefinition as? TaskDefinitionSendMessageProtocol, !taskSend.messageAlreadySentTo.isEmpty {
            DDLogVerbose(
                "\(taskSend) message already sent to \(taskSend.messageAlreadySentTo.map(\.key).joined(separator: ","))"
            )
            excludeReceivers = taskSend.messageAlreadySentTo
        }

        for (key, value) in excludeReceivers {
            taskNonce.nonces[key] = value
        }

        for identity in identities
            .filter({
                $0 != self.frameworkInjector.myIdentityStore.identity && !excludeReceivers.map(\.key).contains($0) }) {
            taskNonce.nonces[identity] = NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.nonceLength))
        }
    }

    /// Get all message nonces.
    /// - Returns: All nonces of this task
    /// - Throws: `TaskExecutionError.missingMessageNonce` if task doesn't support nonces
    private func messageNonces() throws -> [Data] {
        guard let taskNonce = taskDefinition as? TaskDefinitionSendMessageNonceProtocol else {
            throw TaskExecutionError.missingMessageNonce
        }

        return taskNonce.nonces.map(\.value)
    }

    /// Get message nonce for receiver.
    /// - Parameter identity: Receiver of the message
    /// - Returns: Message nonce for a receiver
    /// - Throws: `TaskExecutionError.missingMessageNonce` if task doesn't support nonces
    private func messageNonce(for identity: String) throws -> Data {
        guard let taskNonce = taskDefinition as? TaskDefinitionSendMessageNonceProtocol else {
            throw TaskExecutionError.missingMessageNonce
        }

        guard let nonce = taskNonce.nonces[identity] else {
            throw TaskExecutionError.missingMessageNonce
        }

        return nonce
    }

    /// If group creator an gateway id and receiver and store-incoming-message is not set (group name without ☁), then
    /// the message (except leave and request sync) will not be send.
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
           !(groupName?.hasPrefix(Constants.messageStoringGatewayGroupPrefix) ?? false),
           !(message is GroupLeaveMessage),
           !(message is GroupRequestSyncMessage) {
            DDLogWarn("Drop message to gateway id without store-incoming-message")

            return false
        }

        return true
    }

    /// Get conversation for TaskDefinitionSendBaseMessage, TaskDefinitionSendBallotVoteMessage,
    /// TaskDefinitionReflectIncomingMessage or TaskDefinitionSendAbstractMessage.
    ///
    /// - Parameter task: Task definition
    /// - Returns: Conversation or nil
    func getConversation(for task: TaskDefinitionProtocol) throws -> ConversationEntity {
        var conversation: ConversationEntity?

        if let task = task as? TaskDefinitionSendBaseMessage,
           let groupCreatorIdentity = task.groupCreatorIdentity ?? frameworkInjector.myIdentityStore.identity {
            conversation = task.isGroupMessage ? frameworkInjector.entityManager.entityFetcher
                .conversationEntity(
                    for: task.groupID!,
                    creator: groupCreatorIdentity
                ) : frameworkInjector.entityManager.entityFetcher
                .conversationEntity(forIdentity: task.receiverIdentity)
        }
        else if let task = task as? TaskDefinitionSendDeleteEditMessage,
                let groupCreatorIdentity = task.groupCreatorIdentity ?? frameworkInjector.myIdentityStore.identity {
            conversation = task.isGroupMessage ? frameworkInjector.entityManager.entityFetcher
                .conversationEntity(
                    for: task.groupID!,
                    creator: groupCreatorIdentity
                ) : frameworkInjector.entityManager.entityFetcher
                .conversationEntity(forIdentity: task.receiverIdentity)
        }
        else if let task = task as? TaskDefinitionSendBallotVoteMessage {
            conversation = frameworkInjector.entityManager.entityFetcher
                .ballot(for: task.ballotID)?.conversation
        }
        else if let task = task as? TaskDefinitionReflectIncomingMessage {
            conversation = frameworkInjector.entityManager.conversation(forMessage: task.message)
        }
        else if let task = task as? TaskDefinitionSendAbstractMessage {
            conversation = frameworkInjector.entityManager.conversation(forMessage: task.message)
        }
        else if let task = task as? TaskDefinitionSendDeliveryReceiptsMessage {
            if task.toIdentity != frameworkInjector.myIdentityStore.identity {
                conversation = frameworkInjector.entityManager.entityFetcher
                    .conversationEntity(forIdentity: task.toIdentity)
            }
            else if task.fromIdentity != frameworkInjector.myIdentityStore.identity {
                conversation = frameworkInjector.entityManager.entityFetcher
                    .conversationEntity(forIdentity: task.fromIdentity)
            }
        }
        else if let task = task as? TaskDefinitionSendGroupDeliveryReceiptsMessage,
                let groupID = task.groupID, let creator = task.groupCreatorIdentity {
            conversation = frameworkInjector.entityManager.entityFetcher.conversationEntity(
                for: groupID,
                creator: creator
            )
        }

        guard let conversation else {
            throw TaskExecutionError.conversationNotFound(for: task)
        }

        return conversation
    }
    
    // MARK: Abstract Message Types
    
    /// Create abstract message for base message (Core Data Entity).
    ///
    /// - Parameter task: Task (TaskDefinitionSendBaseMessage or TaskDefinitionSendBallotVoteMessage) with Core Data
    ///                   Entity
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message or nil if could not create
    func getAbstractMessage(
        _ task: TaskDefinitionProtocol,
        _ fromIdentity: String,
        _ toIdentity: String
    ) -> AbstractMessage? {
        
        if let task = task as? TaskDefinitionSendBaseMessage,
           let conversation = task.isGroupMessage ? frameworkInjector.entityManager.entityFetcher
           .conversationEntity(
               for: task.groupID!,
               creator: task.groupCreatorIdentity!
           ) : frameworkInjector.entityManager.entityFetcher
           .conversationEntity(forIdentity: task.receiverIdentity),
           let message = frameworkInjector.entityManager.entityFetcher.message(
               with: task.messageID,
               conversation: conversation
           ) {
            task.messageType = "\(type(of: message))"

            if let message = message as? TextMessageEntity {
                let msg: AbstractMessage = task.isGroupMessage ? GroupTextMessage() : BoxTextMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date

                if task.isGroupMessage,
                   let msg = msg as? GroupTextMessage {
                    
                    msg.text = message.text
                    // swiftformat:disable:next acronyms
                    msg.quotedMessageID = message.quotedMessageId
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxTextMessage {
                    msg.text = message.text
                    // swiftformat:disable:next acronyms
                    msg.quotedMessageID = message.quotedMessageId
                }
                return msg
            }
            else if let message = message as? LocationMessageEntity {
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
                let msg: BoxBallotCreateMessage = BallotMessageEncoder.encodeCreateMessage(for: message.ballot!)
                msg.messageID = message.id

                guard let groupID = task.groupID,
                      let groupCreatorIdentity = task.groupCreatorIdentity,
                      frameworkInjector.groupManager
                      .getConversation(for: GroupIdentity(
                          id: groupID,
                          creator: ThreemaIdentity(groupCreatorIdentity)
                      )) != nil else {
                    msg.fromIdentity = fromIdentity
                    msg.toIdentity = toIdentity
                    msg.date = message.date
                    return msg
                }

                let groupMsg: GroupBallotCreateMessage = BallotMessageEncoder.groupBallotCreateMessage(
                    from: msg,
                    groupID: groupID,
                    groupCreatorIdentity: groupCreatorIdentity
                )
                groupMsg.fromIdentity = fromIdentity
                groupMsg.toIdentity = toIdentity
                groupMsg.date = message.date
                return groupMsg
            }
            else if let message = message as? ImageMessageEntity {
                let msg: AbstractMessage = task.isGroupMessage ? GroupImageMessage() : BoxImageMessage()
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                msg.messageID = message.id
                msg.date = message.date
                if task.isGroupMessage,
                   let msg = msg as? GroupImageMessage {
                    // swiftformat:disable:next acronyms
                    msg.blobID = message.imageBlobId
                    msg.encryptionKey = message.encryptionKey
                    msg.size = UInt32(exactly: message.imageSize!)!
                    
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxImageMessage {
                    // swiftformat:disable:next acronyms
                    msg.blobID = message.imageBlobId
                    msg.imageNonce = message.imageNonce
                    msg.size = UInt32(exactly: message.imageSize!)!
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
                    // swiftformat:disable:next acronyms
                    msg.audioBlobID = message.audioBlobId
                    msg.encryptionKey = message.encryptionKey
                    msg.audioSize = UInt32(exactly: message.audioSize!)!
                    msg.duration = UInt16(message.duration.floatValue)

                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxAudioMessage {
                    // swiftformat:disable:next acronyms
                    msg.audioBlobID = message.audioBlobId
                    msg.encryptionKey = message.encryptionKey
                    msg.audioSize = UInt32(exactly: message.audioSize!)!
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
                    // swiftformat:disable:next acronyms
                    msg.videoBlobID = message.videoBlobId
                    msg.encryptionKey = message.encryptionKey
                    msg.videoSize = UInt32(exactly: message.videoSize!)!
                    msg.duration = UInt16(message.duration.floatValue)
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                }
                else if let msg = msg as? BoxVideoMessage {
                    // swiftformat:disable:next acronyms
                    msg.videoBlobID = message.videoBlobId
                    msg.encryptionKey = message.encryptionKey
                    msg.videoSize = UInt32(exactly: message.videoSize!)!
                    msg.duration = UInt16(message.duration.floatValue)
                }
                return msg
            }
        }
        else if let task = task as? TaskDefinitionSendBallotVoteMessage,
                let ballot = frameworkInjector.entityManager.entityFetcher
                .ballot(for: task.ballotID) {

            let msg: BoxBallotVoteMessage = BallotMessageEncoder.encodeVoteMessage(for: ballot)
            guard let groupID = task.groupID,
                  let groupCreatorIdentity = task.groupCreatorIdentity,
                  frameworkInjector.groupManager
                  .getConversation(for: GroupIdentity(
                      id: groupID,
                      creator: ThreemaIdentity(groupCreatorIdentity)
                  )) !=
                  nil else {
                msg.fromIdentity = fromIdentity
                msg.toIdentity = toIdentity
                return msg
            }

            let groupMsg: GroupBallotVoteMessage = BallotMessageEncoder.groupBallotVoteMessage(
                from: msg,
                groupID: groupID,
                groupCreatorIdentity: groupCreatorIdentity
            )
            groupMsg.fromIdentity = fromIdentity
            groupMsg.toIdentity = toIdentity
            return groupMsg
        }
        else if let task = task as? TaskDefinitionSendDeleteEditMessage {
            assert(task.deleteMessage != nil || task.editMessage != nil)

            if let groupID = task.groupID,
               let groupCreatorIdentity = task.groupCreatorIdentity,
               frameworkInjector.groupManager
               .getConversation(for: GroupIdentity(
                   id: groupID,
                   creator: ThreemaIdentity(groupCreatorIdentity)
               )) !=
               nil {

                if let deleteMessage = task.deleteMessage {
                    let msg = DeleteGroupMessage()
                    msg.fromIdentity = frameworkInjector.myIdentityStore.identity
                    msg.toIdentity = toIdentity
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                    msg.decoded = deleteMessage
                    return msg
                }
                else if let editMessage = task.editMessage {
                    let msg = EditGroupMessage()
                    msg.fromIdentity = frameworkInjector.myIdentityStore.identity
                    msg.toIdentity = toIdentity
                    msg.groupID = task.groupID
                    msg.groupCreator = task.groupCreatorIdentity
                    msg.decoded = editMessage
                    return msg
                }
            }
            else if let receiverIdentity = task.receiverIdentity {
                if let deleteMessage = task.deleteMessage {
                    let msg = DeleteMessage()
                    msg.fromIdentity = frameworkInjector.myIdentityStore.identity
                    msg.toIdentity = receiverIdentity
                    msg.decoded = deleteMessage
                    return msg
                }
                else if let editMessage = task.editMessage {
                    let msg = EditMessage()
                    msg.fromIdentity = frameworkInjector.myIdentityStore.identity
                    msg.toIdentity = receiverIdentity
                    msg.decoded = editMessage
                    return msg
                }
            }
        }

        return nil
    }

    /// Create abstract message for delivery receipt.
    ///
    /// - Parameters:
    ///   - fromIdentity: Message sender identity
    ///   - toIdentity: Message receiver identity
    ///   - receiptType: Receipt type
    ///   - receiptMessageIDs: Receipt for message IDs
    /// - Returns: Abstract message
    func getDeliveryReceiptMessage(
        _ fromIdentity: String,
        _ toIdentity: String,
        _ receiptType: ReceiptType,
        _ receiptMessageIDs: [Data]
    ) -> DeliveryReceiptMessage {
        let msg = DeliveryReceiptMessage()
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toIdentity
        msg.receiptType = receiptType
        msg.receiptMessageIDs = receiptMessageIDs
        return msg
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
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toIdentity: String,
        _ groupMembers: [String]
    ) -> GroupCreateMessage {
        
        let msg = GroupCreateMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
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
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toMember: String
    ) -> GroupLeaveMessage {
        let msg = GroupLeaveMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
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
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toMember: String,
        _ name: String?
    ) -> GroupRenameMessage {
        let msg = GroupRenameMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
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
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toMember: String,
        _ size: UInt32,
        _ blobID: Data?,
        _ encryptionKey: Data?
    ) -> GroupSetPhotoMessage {
        let msg = GroupSetPhotoMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
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
    /// - Parameter groupCreatorIdentity: Creator of the group
    /// - Parameter fromIdentity: Message sender identity
    /// - Parameter toIdentity: Message receiver identity
    /// - Returns: Abstract message
    func getGroupDeletePhotoMessage(
        _ groupID: Data,
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toMember: String
    ) -> GroupDeletePhotoMessage {
        let msg = GroupDeletePhotoMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toMember
        return msg
    }
    
    /// Create abstract message for group delivery receipt.
    ///
    /// - Parameters:
    ///   - groupID: ID of the group
    ///   - groupCreatorIdentity: Creator of the group
    ///   - fromIdentity: Message sender identity
    ///   - toIdentity: Message receiver identity
    ///   - receiptType: Receipt type for group can be read (reflect only), ack and decline
    ///   - receiptMessageIDs: Receipt for message IDs
    /// - Returns: Abstract message
    func getGroupDeliveryReceiptMessage(
        _ groupID: Data,
        _ groupCreatorIdentity: String,
        _ fromIdentity: String,
        _ toIdentity: String,
        _ receiptType: ReceiptType,
        _ receiptMessageIDs: [Data]
    ) -> GroupDeliveryReceiptMessage {
        assert(receiptType == .read || receiptType == .ack || receiptType == .decline)

        let msg = GroupDeliveryReceiptMessage()
        msg.groupID = groupID
        msg.groupCreator = groupCreatorIdentity
        msg.fromIdentity = fromIdentity
        msg.toIdentity = toIdentity
        msg.receiptType = receiptType.rawValue
        msg.receiptMessageIDs = receiptMessageIDs
        return msg
    }
}
