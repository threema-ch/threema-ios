import ThreemaFramework

// MARK: - BootstrapWorkDataFetcherProtocol

protocol BootstrapWorkDataFetcherProtocol {
    func checkUpdateThreemaMDM() async throws
}

// MARK: - BootstrapWorkDataFetcherAdapter

final class BootstrapWorkDataFetcherAdapter: BootstrapWorkDataFetcherProtocol {
    
    private let fetcher: any WorkDataThreemaMDMFetcherProtocol
    
    init(licenseStore: LicenseStore = LicenseStore.shared()) {
        self.fetcher = WorkDataThreemaMDMFetcher(licenseStore: licenseStore)
    }
    
    func checkUpdateThreemaMDM() async throws {
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
    }
}
