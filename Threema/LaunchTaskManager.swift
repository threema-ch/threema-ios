import Collections
import Foundation

/// Due to having asynchronicity setting up the business during setup, we have to postpone some work from various
/// delegate methods called in `AppDelegate` to the point when the business is initialized.
@objc final class LaunchTaskManager: NSObject {
    
    // Note: Using a `Deque` is most likely overkill for this situation. According to benchmarks, it only is more
    // efficient than an Array the item count reaches approximately 32 elements.
    private var deque = Deque<LaunchTaskItem>()
    
    // MARK: - Lifecycle
    
    @objc override init() { }
    
    // MARK: - Task creation
    
    /// Adds a task to the queue that will be run when calling `runTasks()`
    /// - Parameter task: Code to be run
    func add(_ task: @escaping () -> Void) {
        let item = LaunchTaskItem(task: task)
        deque.append(item)
    }
    
    // MARK: - Task running
    
    /// Runs all the task in the queue in the order they were added.
    @objc func runTasks() {
        while let task = deque.popFirst() {
            task.run()
        }
    }
}

private struct LaunchTaskItem {
    
    // MARK: - Properties
    
    let task: () -> Void
    
    // MARK: - Lifecycle
    
    init(task: @escaping () -> Void) {
        self.task = task
    }
    
    // MARK: - Functions
    
    func run() {
        task()
    }
}
