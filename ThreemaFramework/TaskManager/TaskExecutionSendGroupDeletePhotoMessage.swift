import CocoaLumberjackSwift
import Foundation
import PromiseKit

/// Reflect group delete photo message to mediator server is multi device enbaled
/// and send it to group members (CSP).
final class TaskExecutionSendGroupDeletePhotoMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupDeletePhotoMessage else {
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
            // Reflect group delete photo message if is necessary
            guard doReflect else {
                return Promise()
            }
            
            let msg = self.getGroupDeletePhotoMessage(
                groupID,
                groupCreatorIdentity,
                task.fromMember,
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
            // Send group delete photo messages
            var sendMessages = [Promise<AbstractMessage?>]()
            for toMember in task.toMembers {
                if toMember == self.frameworkInjector.myIdentityStore.identity {
                    continue
                }
                
                let msg = self.getGroupDeletePhotoMessage(groupID, groupCreatorIdentity, task.fromMember, toMember)
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
