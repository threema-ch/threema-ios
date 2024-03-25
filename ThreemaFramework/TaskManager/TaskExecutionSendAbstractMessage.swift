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

/// Reflect message to mediator server (if multi device is enabled) and send
/// message to chat server is receiver identity not my identity.
final class TaskExecutionSendAbstractMessage: TaskExecution, TaskExecutionProtocol {

    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendAbstractMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect message if is necessary
            guard doReflect, MediatorMessageProtocol.doReflectMessage(Int32(task.message.type())) else {
                return Promise()
            }
            try self.reflectMessage(
                message: task.message,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )

            return Promise()
        }
        .then { _ -> Promise<Void> in
            // Send CSP message
            Promise { seal in
                self.frameworkInjector.entityManager.performBlockAndWait {
                    if let toIdentity = task.message.toIdentity,
                       toIdentity != self.frameworkInjector.myIdentityStore.identity,
                       !self.frameworkInjector.userSettings.blacklist.contains(toIdentity) {
                        self.sendMessage(
                            message: task.message,
                            ltSend: self.taskContext.logSendMessageToChat,
                            ltAck: self.taskContext.logReceiveMessageAckFromChat
                        )
                        .done { _ in
                            seal.fulfill_()
                        }
                        .catch { error in
                            seal.reject(error)
                        }
                    }
                    else {
                        seal.reject(TaskExecutionError.messageReceiverBlockedOrUnknown)
                    }
                }
            }
        }
    }
}
