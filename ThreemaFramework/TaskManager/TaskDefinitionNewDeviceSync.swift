import Foundation
import ThreemaProtocols

final class TaskDefinitionNewDeviceSync: TaskDefinition,
    TaskDefinitionTransactionProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionNewDeviceSync(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }
    
    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .none,
                logReceiveMessageAckFromMediator: .none,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )
        )
    }
    
    override var description: String {
        "<\(Swift.type(of: self))>"
    }
    
    typealias JoinHandler = (CancelableTask) async throws -> Void
    
    var scope: D2d_TransactionScope.Scope {
        .newDeviceSync
    }
    
    /// Closure executed during transaction
    let join: JoinHandler
    
    /// Create new device sync transaction task
    /// - Parameter join: Closure to execute during transaction. If it throws the transaction will be aborted.
    init(join: @escaping JoinHandler) {
        self.join = join
        
        super.init(type: .dropOnDisconnect)
        
        self.retry = false
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("This task should never be persisted")
    }
}
