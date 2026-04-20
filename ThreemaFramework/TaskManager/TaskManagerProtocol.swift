import Foundation

/// Called when a task is completed (NOT when adding is completed)
///
/// - This handler is not persisted!
/// - For canceled tasks a `TaskExecutionError.taskDropped` is reported when the task is dropped. If the canceled task
///   is currently executing this is only called when the task actually stopped execution (and without an error if the
///   task run to completion). This might take a while if the network is bad or the task doesn't cooperatively checks
///   for cancelation (dropping). If the cancelation was initiated by the user consider updating the UI before this is
///   called.
/// - Right now there is no guarantee that this will be only called once. Especially if the task fails. This should be
///   improved: IOS-4854
typealias TaskCompletionHandler = (TaskDefinitionProtocol, Error?) -> Void

protocol TaskManagerProtocol {
    /// Add task definition
    /// - Parameter taskDefinition: New task definition to add to queue
    /// - Returns: Cancelable task if task can be canceled
    @discardableResult func add(taskDefinition: TaskDefinitionProtocol) -> CancelableTask?
    
    /// Add task definition and get a wait & optional cancelable task
    /// - Parameter taskDefinition: New task definition to add to queue. This should **not** be a task that can be
    ///                             retried!
    /// - Returns: Wait task & cancelable task if task can be canceled
    @discardableResult func addWithWait(taskDefinition: TaskDefinitionProtocol) -> (WaitTask, CancelableTask?)
    
    /// Add task definition
    /// - Parameters:
    ///   - taskDefinition: New task definition to add to queue
    ///   - completionHandler: Called when the task is completed (NOT when adding is completed). For details see
    ///                        `TaskCompletionHandler`
    /// - Returns: Cancelable task if task can be canceled
    @discardableResult func add(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: @escaping TaskCompletionHandler
    ) -> CancelableTask?
    
    /// Add list of task definitions
    ///
    /// See `add(taskDefinition:completionHandler:)` for details.
    ///
    /// - Parameter taskDefinitionTuples: List of task definitions
    /// - Returns: Array of cancelable task for the tasks that can be canceled. Otherwise the entry is `nil`
    @discardableResult func add(taskDefinitionTuples: [(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler
    )]) -> [CancelableTask?]
    
    /// Execute task immediately, independent of the task queue or which task is already running.
    /// - Parameter taskDefinition: Task to execute
    func executeSubTask(taskDefinition: TaskDefinitionProtocol) async throws

    /// Process all tasks
    func spool()
    
    /// Remove all tasks from queue
    static func removeAllTasks()

    /// Remove current task from queue
    static func removeCurrentTask()

    /// Is task queue empty?
    static func isEmpty() -> Bool
}
