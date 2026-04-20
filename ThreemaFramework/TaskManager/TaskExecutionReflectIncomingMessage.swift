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
                receivedAt: reflectedAt ?? .now,
                myIdentity: MyIdentityStore.shared().identity
            )

            return Promise()
        }
    }
}
