import ThreemaFramework

// MARK: - BootstrapWorkDataFetcherProtocol

@MainActor
protocol BootstrapWorkDataFetcherProtocol {
    func checkUpdateThreemaMDM() async throws
}

// MARK: - BootstrapWorkDataFetcherAdapter

@MainActor
final class BootstrapWorkDataFetcherAdapter: BootstrapWorkDataFetcherProtocol {
    
    struct WorkDataError: Error, LocalizedError {
        let message: String
        var errorDescription: String? {
            message
        }
    }
    
    func checkUpdateThreemaMDM() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            WorkDataFetcher.checkUpdateThreemaMDM {
                continuation.resume()
            } onError: { error in
                let message = error?.localizedDescription ?? "Unknown error"
                continuation.resume(
                    throwing: WorkDataError(message: message)
                )
            }
        }
    }
}
