import ThreemaFramework

// MARK: - BootstrapWorkDataFetcherProtocol

protocol BootstrapWorkDataFetcherProtocol {
    func checkUpdateThreemaMDM() async throws
}

// MARK: - BootstrapWorkDataFetcherAdapter

final class BootstrapWorkDataFetcherAdapter: BootstrapWorkDataFetcherProtocol {

    private let makeFetcher: () -> any WorkDataThreemaMDMFetcherProtocol

    /// - Parameter makeFetcher: Called once per `checkUpdateThreemaMDM()`.
    ///
    ///   The fetcher must not be created up front and reused: `WorkDataAPICaller` snapshots the license
    ///   credentials when it is created, and this adapter is created with the `BootstrapContainer` at app
    ///   launch, at which point a fresh install has no license yet. A single instance would keep sending
    ///   the empty credentials captured back then and fail with `WorkDataFetchError.missingCredentials`
    ///   once the user enters a license during onboarding.
    init(makeFetcher: @escaping () -> any WorkDataThreemaMDMFetcherProtocol) {
        self.makeFetcher = makeFetcher
    }

    func checkUpdateThreemaMDM() async throws {
        try await makeFetcher().checkUpdateThreemaMDM(forceSend: false)
    }
}
