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
                self.frameworkInjector.entityManager.performAndWait {
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
