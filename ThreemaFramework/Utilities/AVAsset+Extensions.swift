import AVFoundation.AVAsset

extension AVAsset {

    /// Method to get the AVAsset isExportable synchronously wrapping an async call.
    /// It blocks the Main Thread using a semaphore, but with a timeout of 0.1 seconds
    /// Only use this  if the  async version `await asset.load(isExportable)` is temporarily not possible
    func loadIsExportableSynchronously(timeout: TimeInterval = 0.1) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        Task {
            result = await (try? self.load(.isExportable)) ?? false
            semaphore.signal()
        }

        let timeoutResult = semaphore.wait(
            timeout: .now() + timeout
        )

        if timeoutResult == .timedOut {
            return false
        }

        return result
    }
}
