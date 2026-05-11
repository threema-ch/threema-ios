import CocoaLumberjackSwift
import Foundation

public final class WorkDataThreemaMDMFetcher: WorkDataThreemaMDMFetcherProtocol {
    // MARK: - Private properties
    
    private let mdmSetup: any MDMSetupProtocol
    private let licenseStore: any LicenseStoreProtocol
    private let appFlavorService: any AppFlavorServiceProtocol
    private let workDataAPICaller: any WorkDataAPICallerProtocol
    
    // MARK: - Lifecycle
    
    public init(
        mdmSetup: any MDMSetupProtocol,
        licenseStore: any LicenseStoreProtocol,
        appFlavorService: any AppFlavorServiceProtocol,
        workDataAPICaller: any WorkDataAPICallerProtocol
    ) {
        self.mdmSetup = mdmSetup
        self.licenseStore = licenseStore
        self.appFlavorService = appFlavorService
        self.workDataAPICaller = workDataAPICaller
    }
    
    public convenience init(licenseStore: any LicenseStoreProtocol) {
        self.init(
            mdmSetup: MDMSetup(),
            licenseStore: licenseStore,
            appFlavorService: AppFlavorService(),
            workDataAPICaller: WorkDataAPICaller(licenseStore: licenseStore)
        )
    }
    
    // MARK: - WorkDataThreemaMDMFetcherProtocol
    
    public func checkUpdateThreemaMDM(forceSend: Bool = false) async throws {
        guard appFlavorService.isBusinessApp else {
            return
        }
        guard licenseStore.licenseUsername != nil,
              licenseStore.licensePassword != nil else {
            let error = ThreemaError.threemaError("Missing credentials (user name or password)")!
            DDLogError("[WorkDataFetcher]: Work API fetch failed: \(error)")
            throw error
        }

        let data = try await workDataAPICaller.fetchWorkData(with: [])

        try await processAndApply(data, forceSend: forceSend)
    }
    
    public func processAndApply(_ data: Data, forceSend: Bool = false) async throws {
        // Parse raw dictionary for MDM and check for "error" key
        guard let rawDictionary = try JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] else {
            throw WorkDataFetchError.invalidResponse
        }

        if let errorMessage = rawDictionary["error"] as? String {
            DDLogError("[WorkDataFetcher]: Work API returned an error: \(errorMessage)")
            throw WorkDataFetchError.serverError(errorMessage)
        }
        
        mdmSetup.applyThreemaMdm(rawDictionary, sendForce: forceSend)
    }
}
