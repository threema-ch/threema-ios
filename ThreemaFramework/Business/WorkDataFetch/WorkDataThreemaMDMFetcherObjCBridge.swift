import Foundation

@objcMembers public final class WorkDataThreemaMDMFetcherObjCBridge: NSObject {
    
    private let fetcher: WorkDataThreemaMDMFetcherProtocol
    
    public init(licenseStore: LicenseStore) {
        let apiCaller = WorkDataAPICaller(licenseStore: licenseStore)
        let mdmFetcher = WorkDataThreemaMDMFetcher(
            mdmSetup: MDMSetup(),
            licenseStore: licenseStore,
            appFlavorService: AppFlavorService(),
            workDataAPICaller: apiCaller
        )
        self.fetcher = mdmFetcher
        super.init()
    }
    
    @MainActor
    public func checkUpdateThreemaMDM() async throws {
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
    }
}
