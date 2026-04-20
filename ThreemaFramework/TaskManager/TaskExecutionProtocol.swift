import Foundation
import PromiseKit

/// Task execution handler, process task definition.
protocol TaskExecutionProtocol {
    var taskContext: TaskContextProtocol { get }
    var taskDefinition: TaskDefinitionProtocol { get }
    
    init(
        taskContext: TaskContextProtocol,
        taskDefinition: TaskDefinitionProtocol,
        backgroundFrameworkInjector: FrameworkInjectorProtocol
    )
    init(taskContext: TaskContextProtocol, taskDefinition: TaskDefinitionProtocol)
    
    /// Execute task definition.
    func execute() -> Promise<Void>
}
