//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

/// Reflect message to mediator server (if multi device is enabled) and send
/// message to chat server is receiver identity not my identity.
final class TaskExecutionSendDeleteEditMessage: TaskExecution, TaskExecutionProtocol {

    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendDeleteEditMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            guard doReflect else {
                return Promise()
            }

            guard let abstractMessage = self.getAbstractMessage(
                task,
                self.frameworkInjector.myIdentityStore.identity,
                self.frameworkInjector.myIdentityStore.identity
            ) else {
                return Promise(error: TaskExecutionError.createAbstractMessageFailed)
            }

            try self.reflectMessage(
                message: abstractMessage,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )

            return Promise()
        }
        .then { _ -> Promise<[Promise<AbstractMessage?>]> in
            // Send CSP message
            Promise { seal in
                self.frameworkInjector.entityManager.performAndWait {
                    var sendMessages = [Promise<AbstractMessage?>]()

                    if task.isGroupMessage {
                        guard !(task.isNoteGroup ?? false) else {
                            seal.fulfill(sendMessages)
                            return
                        }

                        if let receivingGroupMembers = task.receivingGroupMembers {
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
                    }
                    else if let receiverIdentity = task.receiverIdentity {
                        guard receiverIdentity != self.frameworkInjector.myIdentityStore.identity else {
                            seal.fulfill(sendMessages)
                            return
                        }

                        guard !self.frameworkInjector.userSettings.blacklist.contains(receiverIdentity) else {
                            seal.fulfill(sendMessages)
                            return
                        }

                        guard let abstractMessage = self.getAbstractMessage(
                            task,
                            self.frameworkInjector.myIdentityStore.identity,
                            receiverIdentity
                        ) else {
                            seal.reject(TaskExecutionError.createAbstractMessageFailed)
                            return
                        }

                        sendMessages.append(
                            self.sendMessage(
                                message: abstractMessage,
                                ltSend: self.taskContext.logSendMessageToChat,
                                ltAck: self.taskContext.logReceiveMessageAckFromChat
                            )
                        )
                    }

                    seal.fulfill(sendMessages)
                }
            }
        }
        .then { sendMessages -> Promise<Void> in
            when(fulfilled: sendMessages)
                .then { _ -> Promise<Void> in
                    // Set last edited at for (group) message
                    self.frameworkInjector.entityManager.performAndWaitSave {
                        guard let messageID = task.deleteMessage?.messageID.littleEndianData ??
                            task.editMessage?.messageID.littleEndianData else {
                            DDLogError("Message ID is missing")
                            return
                        }

                        var conversation: ConversationEntity
                        do {
                            conversation = try self.getConversation(for: task)
                        }
                        catch {
                            DDLogError("Conversation for message ID \(messageID.hexString) not found")
                            return
                        }

                        let message = self.frameworkInjector.entityManager.entityFetcher.message(
                            with: messageID,
                            conversation: conversation
                        )

                        if task.deleteMessage != nil {
                            if let message {
                                message.deletedAt = Date()
                                message.lastEditedAt = nil

                                do {
                                    try self.frameworkInjector.entityManager.entityDestroyer
                                        .deleteMessageContent(of: message)
                                }
                                catch {
                                    DDLogError("Delete message content failed: \(error)")
                                }

                                message.conversation.updateLastDisplayMessage(
                                    with: self.frameworkInjector.entityManager
                                )
                            }
                        }
                        else if task.editMessage != nil {
                            message?.lastEditedAt = Date()
                        }
                    }

                    return Promise()
                }
        }
    }
}
