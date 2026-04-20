import BackgroundTasks
import Foundation

/// Tasks that can be scheduled with `ThreemaBGTaskManager`
///
/// See `MessagesRetentionBackgroundTask` for a reference implementation.
///
/// Add newly created tasks to the `tasks` property in `ThreemaBGTaskManager`
protocol ThreemaBackgroundTask: Sendable {
    /// Identifier of task
    ///
    /// It should start with `ch.threema.bgtask.` and needs to be added to the `Info.plist` files.
    var identifier: String { get }
    
    /// Minimal interval between scheduling and execution
    var minimalInterval: TimeInterval { get }
    
    /// Should this task actually be scheduled (if it was scheduled before it will be canceled)
    var shouldSchedule: Bool { get }
    
    /// If the task is executed should it be schedules again (with the same `minimalInterval`)
    var shouldReschedule: Bool { get }
    
    /// Execute the task
    func run() async throws
}
