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

                self.frameworkInjector.backgroundEntityManager.performBlock {
                    guard let conversation = self.getConversation(task) else {
                        seal.reject(TaskExecutionError.createAbstractMessageFailed)
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

                self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    if task.isGroupMessage {
                        // Do not send message for note group
                        if task.isNoteGroup ?? false {
                            task.sendContactProfilePicture = false
                            if let messageID = (task as? TaskDefinitionSendBaseMessage)?.messageID {
                                self.frameworkInjector.backgroundEntityManager.markMessageAsSent(
                                    messageID,
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
                        else if let allGroupMembers = task.allGroupMembers {
                            for member in allGroupMembers {
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
                        guard let conversation = self.getConversation(task),
                              let contactIdentity = conversation.contact?.identity,
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
        .then { reflectedAt, sendMessages -> Promise<[AbstractMessage?]> in
            // Send messages parallel
            when(fulfilled: sendMessages)
                .then { sentMessages -> Promise<[AbstractMessage?]> in
                    // Mark (group) message as sent
                    if let msg = sentMessages.compactMap({ $0 }).first {
                        self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                            self.frameworkInjector.backgroundEntityManager.markMessageAsSent(
                                msg.messageID,
                                sentAt: reflectedAt ?? .now
                            )
                        }
                    }
                    return Promise { $0.fulfill(sentMessages) }
                }
        }
        .then { sentMessages -> Promise<Void> in
            // Get receiver, group or contact, from messages ware sent to all group members or one message to contact
            var messageSentMessageID: Data?
            // swiftformat:disable:next all
            var messageConversationID: D2d_ConversationId?

            for sentMessage in sentMessages.filter({ msg in
                msg != nil
            }) {
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
                    else if let msg = sentMessage,
                            task.groupID == nil,
                            task.groupCreatorIdentity == nil {
                        messageSentMessageID = msg.messageID
                        // swiftformat:disable:next all
                        messageConversationID = D2d_ConversationId()
                        messageConversationID?.contact = msg.toIdentity
                    }
                    else {
                        return Promise(error: TaskExecutionError.sendMessageFailed(message: "Could not eval message"))
                    }
                }

                // Send profile picture to all message receiver
                if let sendContactProfilePicture = task.sendContactProfilePicture,
                   sendContactProfilePicture {
                    // TODO: Inject for testing
                    self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                        ContactPhotoSender(self.frameworkInjector.backgroundEntityManager)
                            .sendProfilePicture(message: sentMessage!)
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
                        conversationID: receiver
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
}
