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
import ThreemaProtocols

/// Reflect outgoing message to mediator server (if multi device is enabled) and send
/// message to chat server (and reflect message sent to mediator) is receiver identity
/// not my identity.
///
/// Additionally my profile picture will be send to message receiver if is necessary.
final class TaskExecutionSendMessage: TaskExecution, TaskExecutionProtocol {
    
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        guard (taskDefinition as? TaskDefinitionSendBaseMessage)?.messageID != nil else {
            return Promise(error: TaskExecutionError.missingMessageInformation)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return self.isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Date?> in
            // Reflect CSP (group) message
            Promise { seal in
                guard doReflect else {
                    seal.fulfill(nil)
                    return
                }

                self.frameworkInjector.entityManager.performBlock {
                    var conversation: Conversation
                    do {
                        conversation = try self.getConversation(for: task)
                    }
                    catch {
                        seal.reject(error)
                        return
                    }
                    
                    var identity: String
                    if task.isGroupMessage {
                        identity = self.frameworkInjector.myIdentityStore.identity
                    }
                    else {
                        guard let contact = conversation.contact else {
                            seal.reject(TaskExecutionError.messageReceiverBlockedOrUnknown)
                            return
                        }
                        identity = contact.identity
                    }

                    guard let msg = self.getAbstractMessage(
                        task,
                        self.frameworkInjector.myIdentityStore.identity,
                        identity
                    ) else {
                        seal.reject(TaskExecutionError.createAbstractMessageFailed)
                        return
                    }

                    do {
                        let reflectedAt = try self.reflectMessage(
                            message: msg,
                            ltReflect: self.taskContext.logReflectMessageToMediator,
                            ltAck: self.taskContext.logReceiveMessageAckFromMediator
                        )
                        seal.fulfill(reflectedAt)
                    }
                    catch {
                        seal.reject(error)
                    }
                }
            }
        }
        .then { reflectedAt -> Promise<(Date?, [Promise<AbstractMessage?>])> in
            // Send CSP (group) message(s)
            Promise { seal in
                var sendMessages = [Promise<AbstractMessage?>]()

                self.frameworkInjector.entityManager.performBlockAndWait {
                    if task.isGroupMessage {
                        // Do not send message for note group
                        if task.isNoteGroup ?? false {
                            task.sendContactProfilePicture = false

                            var conversation: Conversation
                            do {
                                conversation = try self.getConversation(for: task)
                            }
                            catch {
                                seal.reject(error)
                                return
                            }

                            if let messageID = (task as? TaskDefinitionSendBaseMessage)?.messageID {
                                self.frameworkInjector.entityManager.markMessageAsSent(
                                    messageID,
                                    in: conversation,
                                    sentAt: reflectedAt ?? .now,
                                    isLocal: true
                                )
                            }
                            else {
                                DDLogError("MessageID missing for supposedly successfully sent note group message.")
                                seal.reject(TaskExecutionError.missingMessageInformation)
                                return
                            }
                        }
                        else if let receivingGroupMembers = task.receivingGroupMembers {
                            for member in receivingGroupMembers {
                                if member == self.frameworkInjector.myIdentityStore.identity {
                                    continue
                                }

                                if self.frameworkInjector.userSettings.blacklist.contains(member) {
                                    continue
                                }

                                guard let msg = self.getAbstractMessage(
                                    task,
                                    self.frameworkInjector.myIdentityStore.identity,
                                    member
                                ) else {
                                    seal.reject(TaskExecutionError.createAbstractMessageFailed)
                                    return
                                }

                                if let identity = task.groupCreatorIdentity,
                                   !self.canSendGroupMessageToGatewayID(
                                       groupCreatorIdentity: identity,
                                       groupName: task.groupName,
                                       message: msg
                                   ) {
                                    continue
                                }

                                sendMessages.append(
                                    self.sendMessage(
                                        message: msg,
                                        ltSend: self.taskContext.logSendMessageToChat,
                                        ltAck: self.taskContext.logReceiveMessageAckFromChat
                                    )
                                )
                            }
                        }
                        else {
                            DDLogError("No members for group message")
                        }
                    }
                    else {
                        var conversation: Conversation
                        do {
                            conversation = try self.getConversation(for: task)
                        }
                        catch {
                            seal.reject(error)
                            return
                        }

                        guard let contactIdentity = conversation.contact?.identity,
                              contactIdentity != self.frameworkInjector.myIdentityStore.identity,
                              !self.frameworkInjector.userSettings.blacklist.contains(contactIdentity)
                        else {
                            seal.reject(TaskExecutionError.messageReceiverBlockedOrUnknown)
                            return
                        }

                        guard let msg = self.getAbstractMessage(
                            task,
                            self.frameworkInjector.myIdentityStore.identity,
                            contactIdentity
                        ) else {
                            seal.reject(TaskExecutionError.createAbstractMessageFailed)
                            return
                        }

                        sendMessages.append(
                            self.sendMessage(
                                message: msg,
                                ltSend: self.taskContext.logSendMessageToChat,
                                ltAck: self.taskContext.logReceiveMessageAckFromChat
                            )
                        )
                    }

                    seal.fulfill((reflectedAt, sendMessages))
                }
            }
        }
        .then { reflectedAt, sendMessages -> Promise<[AbstractMessage]> in
            // Send messages parallel
            when(fulfilled: sendMessages)
                .then { sentMessages -> Promise<[AbstractMessage]> in
                    let filteredSentMessages = sentMessages.compactMap { $0 }
                    
                    // Mark (group) message as sent
                    if let msg = filteredSentMessages.first {
                        self.frameworkInjector.entityManager.performBlockAndWait {
                            var conversation: Conversation
                            do {
                                conversation = try self.getConversation(for: task)
                            }
                            catch {
                                DDLogError("Conversation for message ID \(msg.messageID.hexString) not found")
                                return
                            }

                            self.frameworkInjector.entityManager.markMessageAsSent(
                                msg.messageID,
                                in: conversation,
                                sentAt: reflectedAt ?? .now
                            )
                        }
                    }
                    return Promise { $0.fulfill(filteredSentMessages) }
                }
        }
        .then { (sentMessages: [AbstractMessage]) -> Promise<[AbstractMessage]> in
            // Set/update FS mode
            guard let abstractMessage = sentMessages.first else {
                DDLogWarn("No message found to update FS mode")
                return Promise { $0.fulfill(sentMessages) }
            }

            do {
                try self.frameworkInjector.entityManager.performAndWait {
                    let conversation = try self.getConversation(for: task)

                    let newMode: ForwardSecurityMode =
                        if !abstractMessage.flagGroupMessage() {
                            abstractMessage.forwardSecurityMode
                        }
                        else {
                            try self.newOutgoingGroupForwardSecurityMode(
                                for: abstractMessage,
                                and: sentMessages,
                                in: conversation
                            )
                        }
                    
                    self.frameworkInjector.entityManager.setForwardSecurityMode(
                        abstractMessage.messageID,
                        in: conversation,
                        forwardSecurityMode: newMode
                    )
                }
            }
            catch {
                DDLogWarn("Failed to set/update FS mode: \(error)")
            }

            return Promise { $0.fulfill(sentMessages) }
        }
        .then { (sentMessages: [AbstractMessage]) -> Promise<[AbstractMessage]> in
            // Remove all group receivers from rejected list
            if let msg = sentMessages.first,
               let receivingGroupMembers = task.receivingGroupMembers {
                self.frameworkInjector.entityManager.performAndWait {
                    do {
                        let conversation = try self.getConversation(for: task)
                        
                        self.frameworkInjector.entityManager.removeContacts(
                            with: receivingGroupMembers,
                            fromRejectedListOfMessageWith: msg.messageID,
                            in: conversation
                        )
                    }
                    catch {
                        DDLogError("Conversation for message ID \(msg.messageID.hexString) not found")
                        return
                    }
                }
            }
            
            return Promise { $0.fulfill(sentMessages) }
        }
        .then { (sentMessages: [AbstractMessage]) -> Promise<Void> in
            // Get receiver, group or contact, from messages ware sent to all group members or one message to contact
            var messageSentMessageID: Data?
            // swiftformat:disable:next all
            var messageConversationID: D2d_ConversationId?

            for sentMessage in sentMessages {
                if messageConversationID == nil {
                    if let msg = sentMessage as? AbstractGroupMessage,
                       let groupID = task.groupID,
                       let groupCreatorIdentity = task.groupCreatorIdentity {
                        messageSentMessageID = msg.messageID
                        // swiftformat:disable:next all
                        messageConversationID = D2d_ConversationId()
                        messageConversationID?.group.groupID = try groupID.littleEndian()
                        messageConversationID?.group.creatorIdentity = groupCreatorIdentity
                    }
                    else if task.groupID == nil,
                            task.groupCreatorIdentity == nil {
                        messageSentMessageID = sentMessage.messageID
                        // swiftformat:disable:next all
                        messageConversationID = D2d_ConversationId()
                        messageConversationID?.contact = sentMessage.toIdentity
                    }
                    else {
                        return Promise(error: TaskExecutionError.sendMessageFailed(message: "Could not eval message"))
                    }
                }

                // Send profile picture to all message receiver
                if let sendContactProfilePicture = task.sendContactProfilePicture,
                   sendContactProfilePicture {
                    // TODO: (IOS-4495) Inject for testing
                    self.frameworkInjector.entityManager.performBlockAndWait {
                        ContactPhotoSender(self.frameworkInjector.entityManager)
                            .sendProfilePicture(message: sentMessage)
                    }
                }
            }

            // Reflect outgoing message sent
            if self.frameworkInjector.userSettings.enableMultiDevice,
               let messageID = messageSentMessageID,
               let receiver = messageConversationID {

                let envelope = self.frameworkInjector.mediatorMessageProtocol
                    .getEnvelopeForOutgoingMessageUpdate(
                        messageID: messageID,
                        conversationID: receiver,
                        deviceID: self.frameworkInjector.multiDeviceManager.thisDevice.deviceID
                    )

                do {
                    try self.reflectMessage(
                        envelope: envelope,
                        ltReflect: .reflectOutgoingMessageUpdateToMediator,
                        ltAck: .receiveOutgoingMessageUpdateAckFromMediator
                    )
                }
                catch {
                    return Promise(error: error)
                }
            }

            return Promise()
        }
    }
    
    // MARK: - Private helper
    
    /// Get new outgoing forward security mode for an outgoing group message
    /// - Parameters:
    ///   - abstractMessage: One of the abstract messages for the outgoing message
    ///   - sentMessages: All sent abstract messages
    ///   - conversation: Group conversation
    /// - Returns: New outgoing forward security mode
    private func newOutgoingGroupForwardSecurityMode(
        for abstractMessage: AbstractMessage,
        and sentMessages: [AbstractMessage],
        in conversation: Conversation
    ) throws -> ForwardSecurityMode {
        guard
            let message = frameworkInjector.entityManager.entityFetcher.message(
                with: abstractMessage.messageID,
                conversation: conversation
            ),
            let initialForwardSecurityMode = ForwardSecurityMode(
                rawValue: message.forwardSecurityMode.uintValue
            )
        else {
            throw TaskExecutionError.missingMessageInformation
        }
            
        return determineOutgoingGroupForwardSecurityMode(
            for: sentMessages,
            with: initialForwardSecurityMode
        )
    }
    
    /// Determine forward security mode for an outing group message
    /// - Parameters:
    ///   - sentMessages: All sent abstract messages
    ///   - initialMode: Initial mode. `.none`, `.outgoingGroupNone`, `outgoingGroupPartial` or `.outgoingGroupFull` is
    ///                  expected
    /// - Returns: Determined new outgoing forward security mode
    private func determineOutgoingGroupForwardSecurityMode(
        for sentMessages: [AbstractMessage],
        with initialMode: ForwardSecurityMode
    ) -> ForwardSecurityMode {
        // If `initialMode` is `.none` we assume the message was not sent before and thus every state can be reached.
        // If `initialMode` is `.outgoingGroupFull` or `.outgoingGroupPartial` state we cannot reach
        // `.outgoingGroupNone` as we don't know who got the message in which mode before.
        
        var currentMode = initialMode
        
        for message in sentMessages {
            guard message.flagGroupMessage() else {
                DDLogWarn("Non group message in abstract messages list of outgoing group message. Skip.")
                continue
            }
                        
            if message.forwardSecurityMode == .fourDH { // Full or partial
                // If none or full was before we're still full
                if currentMode == .outgoingGroupFull || currentMode == .none {
                    currentMode = .outgoingGroupFull
                }
                // Otherwise we are now partial
                else if currentMode == .outgoingGroupPartial || currentMode == .outgoingGroupNone {
                    currentMode = .outgoingGroupPartial
                }
                else {
                    DDLogWarn("This state should not exist for outgoing group messages")
                    currentMode = .outgoingGroupNone
                }
            }
            else { // Partial or none
                // This message was not sent with FS, but if some before were we're still partial.
                if currentMode == .outgoingGroupFull || currentMode == .outgoingGroupPartial {
                    currentMode = .outgoingGroupPartial
                }
                else {
                    // This state basically captures the case when the first messages was sent without FS, but all
                    // others were. Then it should reach partial after the first iteration, but not full.
                    currentMode = .outgoingGroupNone
                }
            }
        }
        
        return currentMode
    }
}
