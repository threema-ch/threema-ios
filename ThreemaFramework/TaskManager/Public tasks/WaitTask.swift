/// Wait for task complete
protocol WaitTask {
    /// Wait until task completes (this might never return if the app is terminated before the task completes)
    func wait() async throws
}
