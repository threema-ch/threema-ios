import CocoaLumberjackSwift
import Foundation
import PromiseKit

final class TaskExecutionSendCallOfferAnswerMessage: TaskExecutionTransaction {
    
    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendCallOfferAnswerMessage else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
                
        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Void> in
            // Reflect message if necessary
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
                       toIdentity != self.frameworkInjector.profileStore.profile.myIdentity.rawValue,
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
    
    override func writeLocal() -> Promise<Void> {
        // No need to write anything
        Promise()
    }
}
