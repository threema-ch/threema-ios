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
                if toMember == self.frameworkInjector.myIdentityStore.identity {
                    continue
                }
              
                let msg = self.getGroupRenameMessage(groupID, groupCreator, task.fromMember, toMember, task.name)
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
