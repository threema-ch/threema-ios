import Foundation

enum TaskExecutionState: String, Codable {
    case pending
    case executing
    case interrupted
}

enum TaskType {
    /// Task is persisted on disk and reloaded on relaunch
    case persistent
    /// Task lives on until the app is terminated (i.e. it will be kept on backgrounding)
    case volatile
    /// Task is dropped on next chat/mediator server disconnect
    case dropOnDisconnect
}

protocol TaskDefinitionProtocol {
    /// Class name for serialize and deserialize task.
    var className: String { get }

    var type: TaskType { get }

    var state: TaskExecutionState { get set }

    /// Retry task execution on failure
    var retry: Bool { get }

    /// Retry count of task execution
    var retryCount: Int { get set }

    /// Create task execution handler for task definition.
    /// - Parameters:
    ///     - frameworkInjector: Framework business injector (necessary for unit testing)
    ///     - taskContext: Context where the task is created
    /// - Returns: Task execution handler
    func create(frameworkInjector: FrameworkInjectorProtocol, taskContext: TaskContextProtocol)
        -> TaskExecutionProtocol

    func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol
}
