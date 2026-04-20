import Foundation
@testable import ThreemaFramework

final class TaskManagerMock: NSObject, TaskManagerProtocol {

    typealias TaskAddedCallback = () -> Void
    
    var addedTasks = [TaskDefinitionProtocol]() {
        didSet {
            taskAdded?()
        }
    }
    
    /// Called on each task added
    var taskAdded: TaskAddedCallback?
    
    init(taskAdded: TaskAddedCallback? = nil) {
        self.taskAdded = taskAdded
    }
    
    // MARK: Mocks
    
    func add(taskDefinition: TaskDefinitionProtocol) -> CancelableTask? {
        addedTasks.append(taskDefinition)
        return nil
    }
    
    func addWithWait(taskDefinition: TaskDefinitionProtocol) -> (WaitTask, CancelableTask?) {
        addedTasks.append(taskDefinition)
        return (DefaultWaitTask(completionTask: Task { }), nil)
    }

    func add(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: @escaping TaskCompletionHandler
    ) -> CancelableTask? {
        addedTasks.append(taskDefinition)
        completionHandler(taskDefinition, nil)
        return nil
    }
    
    func add(taskDefinitionTuples: [(
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler
    )]) -> [CancelableTask?] {
        var cancelableTasks = [CancelableTask?]()
        
        for tuple in taskDefinitionTuples {
            let cancelableTask = add(taskDefinition: tuple.taskDefinition, completionHandler: tuple.completionHandler)
            cancelableTasks.append(cancelableTask)
        }
        
        return cancelableTasks
    }
    
    func executeSubTask(taskDefinition: any ThreemaFramework.TaskDefinitionProtocol) async throws {
        // no-op
    }

    static func removeAllTasks() {
        // no-op
    }

    static func removeCurrentTask() { }

    static func isEmpty() -> Bool {
        false
    }
    
    func spool() { }
    
    func save() { }
}
