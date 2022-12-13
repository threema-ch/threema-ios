//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

/// Reflect outgoing message to mediator server (if multi device is enabled) and send
/// message to chat server (and reflect message sent to mediator) is receiver identity
/// not my identity.
///
/// Additionally my profile picture will be send to message receiver if is necessary.
class TaskExecutionSendMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        guard (taskDefinition as? TaskDefinitionSendBaseMessage)?.messageID != nil else {
            return Promise(error: TaskExecutionError.missingMessageInformation)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect CSP (group) message
            Promise { seal in
                guard doReflect else {
                    seal.fulfill_()
                    return
                }

                self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    guard let conversation = self.getConversation(task) else {
                        seal.reject(TaskExecutionError.createAbsractMessageFailed)
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
                    if let msg = self.getAbstractMessage(
                        task,
                        self.frameworkInjector.myIdentityStore.identity,
                        identity
                    ) {

                        do {
                            try self.reflectMessage(
                                message: msg,
                                ltReflect: self.taskContext.logReflectMessageToMediator,
                                ltAck: self.taskContext.logReceiveMessageAckFromMediator
                            )
                        }
                        catch {
                            seal.reject(error)
                            return
                        }
                    }
                }

                seal.fulfill_()
            }
        }
        .then { _ -> Promise<[Promise<AbstractMessage?>]> in
            // Send CSP (group) message(s)
            Promise { seal in
                var sendMessages = [Promise<AbstractMessage?>]()

                self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    if task.isGroupMessage {
                        // Do not send message for note group
                        if task.isNoteGroup ?? false {
                            task.sendContactProfilePicture = false
                            if let messageID = (task as? TaskDefinitionSendBaseMessage)?.messageID {
                                self.frameworkInjector.backgroundEntityManager.markMessageAsSent(messageID)
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
                                    seal.reject(TaskExecutionError.createAbsractMessageFailed)
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
                            seal.reject(TaskExecutionError.createAbsractMessageFailed)
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

                    seal.fulfill(sendMessages)
                }
            }
        }
        .then { sendMessages -> Promise<[AbstractMessage?]> in
            // Send messages parallel
            when(fulfilled: sendMessages)
                .then { sentMessages -> Promise<[AbstractMessage?]> in
                    // Mark (group) message as sent
                    if let msg = sentMessages.compactMap({ $0 }).first {
                        self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                            self.frameworkInjector.backgroundEntityManager.markMessageAsSent(msg.messageID)
                        }
                    }
                    return Promise { $0.fulfill(sentMessages) }
                }
        }
        .then { sentMessages -> Promise<Void> in
            // Get receiver, group or contact, from messages ware sent to all group members or one message to contact
            var messageSentMessageID: Data?
            var messageSentReceiver: D2d_MessageReceiver?

            for sentMessage in sentMessages.filter({ msg in
                msg != nil
            }) {
                if messageSentReceiver == nil {
                    if let msg = sentMessage as? AbstractGroupMessage,
                       let groupID = task.groupID,
                       let groupCreatorIdentity = task.groupCreatorIdentity {
                        messageSentMessageID = msg.messageID
                        messageSentReceiver = D2d_MessageReceiver()
                        messageSentReceiver?.group.groupID = groupID.convert()
                        messageSentReceiver?.group.creatorIdentity = groupCreatorIdentity
                    }
                    else if let msg = sentMessage,
                            task.groupID == nil,
                            task.groupCreatorIdentity == nil {
                        messageSentMessageID = msg.messageID
                        messageSentReceiver = D2d_MessageReceiver()
                        messageSentReceiver?.identity = msg.toIdentity
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
                            .sendProfilePicture(sentMessage!)
                    }
                }
            }

            // Reflect outgoing message sent
            if self.frameworkInjector.serverConnector.isMultiDeviceActivated,
               let messageID = messageSentMessageID,
               let receiver = messageSentReceiver {

                let envelope = self.frameworkInjector.mediatorMessageProtocol
                    .getEnvelopeForOutgoingMessageSent(
                        messageID: messageID,
                        receiver: receiver
                    )

                do {
                    try self.reflectMessage(
                        envelope: envelope,
                        ltReflect: .reflectOutgoingMessageSentToMediator,
                        ltAck: .receiveOutgoingMessageSentAckFromMediator
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
