/// Proxy type to cancel a task
///
/// Use this if you want to cancel a task. Canceling is cooperative and thus a task might not stop immediately and even
/// run to completion.
protocol CancelableTask {
    /// Is this task canceled?
    var isCanceled: Bool { get }
    
    /// Cancel this task
    func cancel()
}
