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

/// Reflect group set photo message to mediator server is multi device enbaled
/// and send it to group members (CSP).
class TaskExecutionSendGroupSetPhotoMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupSetPhotoMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect group set photo message if is necessary
            guard doReflect else {
                return Promise()
            }
            
            let msg = self.getGroupSetPhotoMessage(
                groupID,
                groupCreatorIdentity,
                task.fromMember,
                self.frameworkInjector.myIdentityStore.identity,
                task.size,
                task.blobID,
                task.encryptionKey
            )
            try self.reflectMessage(
                message: msg,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )
            
            return Promise()
        }
        .then { _ -> Promise<Void> in
            // Send group set photo messages
            var sendMessages = [Promise<AbstractMessage?>]()
            for toMember in task.toMembers {
                if !toMember.elementsEqual(self.frameworkInjector.myIdentityStore.identity) {
                    let msg = self.getGroupSetPhotoMessage(
                        groupID,
                        groupCreatorIdentity,
                        task.fromMember,
                        toMember,
                        task.size,
                        task.blobID,
                        task.encryptionKey
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
                .done { _ in }
        }
    }
}
