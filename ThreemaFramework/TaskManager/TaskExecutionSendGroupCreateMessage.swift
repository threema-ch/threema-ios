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

/// Reflect group create message to mediator server is multi device enbaled
/// and send it to group members (CSP).
class TaskExecutionSendGroupCreateMessage: TaskExecution, TaskExecutionProtocol {
    
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupCreateMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect group create message if is necessary
            guard doReflect else {
                return Promise()
            }
            
            let msg = self.getGroupCreateMessage(
                groupID,
                groupCreatorIdentity,
                self.frameworkInjector.myIdentityStore.identity,
                self.frameworkInjector.myIdentityStore.identity,
                Array(task.members)
            )
            try self.reflectMessage(
                message: msg,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )

            return Promise()
        }
        .then { _ -> Promise<Void> in
            // Send group create messages
            var msgSend = [GroupCreateMessage]()
            
            if let removedMembers = task.removedMembers {
                for removedMember in removedMembers {
                    // Send only group admin as group member (is needed to work correctly on Android)!
                    msgSend.append(self.getGroupCreateMessage(
                        task.groupID!,
                        task.groupCreatorIdentity!,
                        self.frameworkInjector.myIdentityStore.identity,
                        removedMember,
                        [task.groupCreatorIdentity!]
                    ))
                }
            }
        
            for member in task.toMembers {
                msgSend.append(self.getGroupCreateMessage(
                    groupID,
                    groupCreatorIdentity,
                    self.frameworkInjector.myIdentityStore.identity,
                    member,
                    Array(task.members)
                ))
            }

            var sendMessages = [Promise<AbstractMessage?>]()
            for msg in msgSend {
                sendMessages.append(
                    self.sendMessage(
                        message: msg,
                        ltSend: self.taskContext.logSendMessageToChat,
                        ltAck: self.taskContext.logReceiveMessageAckFromChat
                    )
                )
            }

            return when(fulfilled: sendMessages)
                .done { _ in }
        }
    }
}
