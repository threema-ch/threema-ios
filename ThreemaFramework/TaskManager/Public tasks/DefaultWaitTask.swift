/// Wait task with simple task
final class DefaultWaitTask: WaitTask {
    private let completionTask: Task<Void, Error>

    init(completionTask: Task<Void, Error>) {
        self.completionTask = completionTask
    }

    func wait() async throws {
        try await completionTask.value
    }
}
