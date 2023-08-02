//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import ThreemaProtocols

final class TaskExecutionSendGroupCallStartMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupCallStartMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }
        
        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            guard doReflect else {
                return Promise()
            }
            
            let msg = self.getGroupCallStartMessage(
                groupID: groupID,
                groupCreatorIdentity: groupCreatorIdentity,
                fromMember: task.fromMember,
                toMember: self.frameworkInjector.myIdentityStore.identity,
                groupCallStartData: task.groupCallStartMessage
            )
            
            try self.reflectMessage(
                message: msg,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )
            
            return Promise()
        }.then { _ -> Promise<Void> in
            var sendMessages = [Promise<AbstractMessage?>]()
            
            for toMember in task.toMembers {
                guard toMember != self.frameworkInjector.myIdentityStore.identity else {
                    continue
                }

                let msg = self.getGroupCallStartMessage(
                    groupID: groupID,
                    groupCreatorIdentity: groupCreatorIdentity,
                    fromMember: task.fromMember,
                    toMember: toMember,
                    groupCallStartData: task.groupCallStartMessage
                )

                sendMessages.append(
                    self.sendMessage(
                        message: msg,
                        ltSend: self.taskContext.logSendMessageToChat,
                        ltAck: self.taskContext.logReceiveMessageAckFromChat
                    )
                )
            }
            
            return when(fulfilled: sendMessages)
                .done { _ in
                }
        }
    }
}

extension TaskExecutionSendGroupCallStartMessage {
    private func getGroupCallStartMessage(
        groupID: Data,
        groupCreatorIdentity: String,
        fromMember: String,
        toMember: String,
        groupCallStartData: CspE2e_GroupCallStart
    ) -> GroupCallStartMessage {
        let groupCallStartMessage = GroupCallStartMessage()
        groupCallStartMessage.groupID = groupID
        groupCallStartMessage.groupCreator = groupCreatorIdentity
        groupCallStartMessage.fromIdentity = fromMember
        groupCallStartMessage.toIdentity = toMember
        groupCallStartMessage.decoded = groupCallStartData
        
        return groupCallStartMessage
    }
}
