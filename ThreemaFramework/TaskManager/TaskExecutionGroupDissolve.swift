import Foundation
import PromiseKit

/// Dissolve group reflect group leave message to mediator server is multi device enabled
/// and send group create messages with empty members to all group members (CSP).
final class TaskExecutionGroupDissolve: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionGroupDissolve else {
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
            // Reflect group leave message of own group
            guard doReflect else {
                return Promise()
            }

            guard groupCreatorIdentity == self.frameworkInjector.myIdentityStore.identity else {
                return Promise(
                    error: TaskExecutionError
                        .reflectMessageFailed(message: "Dissolve not allowed, i'm not creator of the group")
                )
            }

            let msg = self.getGroupLeaveMessage(
                groupID,
                groupCreatorIdentity,
                self.frameworkInjector.myIdentityStore.identity,
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
            // Send group create messages with empty members to group members
            var sendMessages = [Promise<AbstractMessage?>]()

            self.frameworkInjector.entityManager.performAndWait {
                for toMember in task.toMembers {
                    guard toMember != self.frameworkInjector.myIdentityStore.identity else {
                        continue
                    }

                    let msg = self.getGroupCreateMessage(
                        groupID,
                        groupCreatorIdentity,
                        self.frameworkInjector.myIdentityStore.identity,
                        toMember,
                        []
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
                .then { _ in
                    Promise()
                }
        }
    }
}
