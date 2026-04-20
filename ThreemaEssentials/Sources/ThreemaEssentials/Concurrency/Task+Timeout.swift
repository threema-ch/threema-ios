import Foundation

extension Task where Success == Never, Failure == Never {
    public enum TimeoutResult<Result: Sendable>: Sendable {
        case timeout
        case result(Result)
        case error(Error?)
    }
    
    public static func timeout<Output>(
        _ task: Task<Output, Error>,
        _ seconds: TimeInterval
    ) async throws -> TimeoutResult<Output> {
        try await withThrowingTaskGroup(of: TimeoutResult<Output>.self, body: { taskGroup -> TimeoutResult<Output> in
            defer { taskGroup.cancelAll() }
            
            taskGroup.addTask {
                try await .result(task.value)
            }
            taskGroup.addTask {
                try await Task.sleep(seconds: seconds)
                return .timeout
            }
            
            guard let firstResult = try await taskGroup.next() else {
                return .error(nil)
            }
            
            return firstResult
        })
    }
}
