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

/// Reflect group rename message to mediator server is multi device enbaled
/// and send it to group members (CSP).
final class TaskExecutionSendGroupRenameMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupRenameMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard let groupID = task.groupID, let groupCreator = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect group rename message if is necessary
            guard doReflect else {
                return Promise()
            }
            
            let msg = self.getGroupRenameMessage(
                groupID,
                groupCreator,
                task.fromMember,
                self.frameworkInjector.myIdentityStore.identity,
                task.name
            )
            try self.reflectMessage(
                message: msg,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )

            return Promise()
        }
        .then { _ -> Promise<Void> in
            // Send group rename messages
            var sendMessages = [Promise<AbstractMessage?>]()
            for toMember in task.toMembers {
                if !toMember.elementsEqual(self.frameworkInjector.myIdentityStore.identity) {
                    let msg = self.getGroupRenameMessage(groupID, groupCreator, task.fromMember, toMember, task.name)
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
                .done { _ in }
        }
    }
}
