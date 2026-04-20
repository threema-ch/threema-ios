import Foundation

extension Task where Success == Never, Failure == Never {
    /// Calls sleep with the given duration
    /// Throws if the task is cancelled while suspended.
    /// - Parameter seconds: The sleep duration in seconds.
    public static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
