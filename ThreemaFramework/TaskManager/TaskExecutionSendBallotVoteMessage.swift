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
class TaskExecutionSendBallotVoteMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendBallotVoteMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
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
                            seal.reject(TaskExecutionError.createAbsractMessageFailed)
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
        }.then { _ -> Promise<Data?> in
            Promise { seal in
                self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    if task.isGroupMessage {
                        // Do not send message for note group
                        if task.isNoteGroup ?? false {
                            seal.fulfill(nil)
                        }
                        else if let allGroupMembers = task.allGroupMembers {
                            for member in allGroupMembers {
                                if member != self.frameworkInjector.myIdentityStore.identity,
                                   let msg = self.getAbstractMessage(
                                       task,
                                       self.frameworkInjector.myIdentityStore.identity,
                                       member
                                   ) {

                                    if self.frameworkInjector.userSettings.blacklist.contains(member) {
                                        continue
                                    }
                                   
                                    if let identity = task.groupCreatorIdentity,
                                       !self.canSendGroupMessageToGatewayID(
                                           groupCreatorIdentity: identity,
                                           groupName: task.groupName,
                                           message: msg
                                       ) {
                                        continue
                                    }

                                    do {
                                        try self.sendMessage(
                                            message: msg,
                                            ltSend: self.taskContext.logSendMessageToChat,
                                            ltAck: self.taskContext.logReceiveMessageAckFromChat
                                        )
                                    }
                                    catch {
                                        seal.reject(error)
                                        return
                                    }

                                    if let sendContactProfilePicture = task.sendContactProfilePicture,
                                       sendContactProfilePicture {
                                        // TODO: Inject for testing
                                        ContactPhotoSender(self.frameworkInjector.backgroundEntityManager)
                                            .sendProfilePicture(msg)
                                    }
                                    seal.fulfill(msg.messageID)
                                }
                            }
                        }
                        else {
                            DDLogError("No members for group message")
                            seal.reject(TaskExecutionError.missingGroupInformation)
                        }
                    }
                    else {
                        if let conversation = self.getConversation(task),
                           let contactIdentity = conversation.contact?.identity,
                           contactIdentity != self.frameworkInjector.myIdentityStore.identity,
                           !self.frameworkInjector.userSettings.blacklist.contains(contactIdentity) {

                            if let msg = self.getAbstractMessage(
                                task,
                                self.frameworkInjector.myIdentityStore.identity,
                                contactIdentity
                            ) {

                                do {
                                    try self.sendMessage(
                                        message: msg,
                                        ltSend: self.taskContext.logSendMessageToChat,
                                        ltAck: self.taskContext.logReceiveMessageAckFromChat
                                    )
                                }
                                catch {
                                    seal.reject(error)
                                    return
                                }

                                if let sendContactProfilePicture = task.sendContactProfilePicture,
                                   sendContactProfilePicture {
                                    // TODO: Inject for testing
                                    ContactPhotoSender(self.frameworkInjector.backgroundEntityManager)
                                        .sendProfilePicture(msg)
                                }
                                seal.fulfill(msg.messageID)
                            }
                            else {
                                seal.reject(TaskExecutionError.createAbsractMessageFailed)
                                return
                            }
                        }
                        else {
                            seal.reject(TaskExecutionError.sendMessageFailed(message: "(unknown receiver)"))
                            return
                        }
                    }
                }
            }
        }.then { messageID -> Promise<Void> in
            Promise { seal in
                if let messageID = messageID {
                    self.frameworkInjector.backgroundEntityManager.markMessageAsSent(messageID)
                }
                
                seal.fulfill_()
            }
        }
    }
}
