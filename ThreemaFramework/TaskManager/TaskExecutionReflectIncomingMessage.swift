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
import PromiseKit

final class TaskExecutionReflectIncomingMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReflectIncomingMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            DDLogNotice("\(task) use nonce of incoming message")
            guard var taskNonce = taskDefinition as? TaskDefinitionSendMessageNonceProtocol,
                  let nonce = task.message.nonce else {
                throw TaskExecutionError.missingMessageNonce
            }
            taskNonce.nonces[task.message.fromIdentity] = nonce

            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Date?> in
            Promise { seal in
                // Reflect message if is necessary
                guard doReflect, MediatorMessageProtocol.doReflectMessage(Int32(task.message.type())) else {
                    seal.fulfill(nil)
                    return
                }

                let reflectedAt = try self.reflectMessage(
                    message: task.message,
                    ltReflect: self.taskContext.logReflectMessageToMediator,
                    ltAck: self.taskContext.logReceiveMessageAckFromMediator
                )

                seal.fulfill(reflectedAt)
            }
        }
        .then { reflectedAt in
            guard !task.message.flagDontQueue(),
                  !((task.message as? AbstractGroupMessage)?.isGroupControlMessage() ?? false) else {
                return Promise()
            }

            // Set received date (delivery date) for incoming message
            self.frameworkInjector.entityManager.markMessageAsReceived(
                task.message,
                receivedAt: reflectedAt ?? .now
            )

            return Promise()
        }
    }
}
