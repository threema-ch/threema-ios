//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

/// Dissolve group reflect group leave message to mediator server is multi device enabled
/// and send group create messages with empty members to all group members (CSP).
class TaskExecutionGroupDissolve: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionGroupDissolve else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        guard let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect group leave message of own group
            guard doReflect else {
                return Promise()
            }

            guard groupCreatorIdentity == self.frameworkInjector.myIdentityStore.identity else {
                return Promise(
                    error: TaskExecutionError
                        .reflectMessageFailed(message: "Dissolve not allwoed, i'm not creator of the group")
                )
            }

            let msg = self.getGroupLeaveMessage(
                groupID,
                groupCreatorIdentity,
                self.frameworkInjector.myIdentityStore.identity,
                self.frameworkInjector.myIdentityStore.identity
            )
            try self.reflectMessage(
                message: msg,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )

            return Promise()
        }
        .then { _ -> Promise<Void> in
            // Send group create messages with empty members to group members
            var sendMessages = [Promise<AbstractMessage?>]()

            self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                for toMember in task.toMembers {
                    guard toMember != self.frameworkInjector.myIdentityStore.identity else {
                        continue
                    }

                    let msg = self.getGroupCreateMessage(
                        groupID,
                        groupCreatorIdentity,
                        self.frameworkInjector.myIdentityStore.identity,
                        toMember,
                        []
                    )

                    sendMessages.append(
                        self.sendMessage(
                            message: msg,
                            ltSend: self.taskContext.logSendMessageToChat,
                            ltAck: self.taskContext.logReceiveMessageAckFromChat
                        )
                    )
                }
            }

            return when(fulfilled: sendMessages)
                .then { _ in
                    Promise()
                }
        }
    }
}
