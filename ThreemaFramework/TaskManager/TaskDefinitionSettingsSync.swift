import Foundation
import ThreemaProtocols

final class TaskDefinitionSettingsSync: TaskDefinition, TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSettingsSync(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )
        )
    }

    override var description: String {
        "<\(Swift.type(of: self))>"
    }

    var scope: D2d_TransactionScope.Scope {
        .settingsSync
    }

    var syncSettings: D2dSync_Settings

    init(syncSettings: D2dSync_Settings) {
        self.syncSettings = syncSettings

        super.init(type: .volatile)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
