import Foundation
import ThreemaProtocols

final class TaskDefinitionReflectWorkSyncDelta: TaskDefinition, TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReflectWorkSyncDelta(
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
        .workSyncDelta
    }

    let deltas: [CspE2e_WorkSyncDelta.Delta]
    let determineChanges: ([CspE2e_WorkSyncDelta.Delta]) async throws -> [D2dSync_Contact]
    let changedManagedObjectID: (NSManagedObjectID) -> Void

    init(
        deltas: [CspE2e_WorkSyncDelta.Delta],
        determineChanges: @escaping ([CspE2e_WorkSyncDelta.Delta]) async throws -> [D2dSync_Contact],
        changedManagedObjectID: @escaping (NSManagedObjectID) -> Void
    ) {
        self.deltas = deltas
        self.determineChanges = determineChanges
        self.changedManagedObjectID = changedManagedObjectID

        super.init(type: .volatile)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
