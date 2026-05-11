import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

@MainActor
final class BootstrapLicenseService {

    private let licenseStore: any LicenseStoreAdapterProtocol
    private let appLaunchManager: any AppLaunchManagerProtocol

    init(
        licenseStore: any LicenseStoreAdapterProtocol,
        appLaunchManager: any AppLaunchManagerProtocol
    ) {
        self.licenseStore = licenseStore
        self.appLaunchManager = appLaunchManager
    }

    func checkLicense() async -> Bool {
        guard appLaunchManager.isBusinessApp else {
            return true
        }
        
        guard licenseStore.isValid else {
            return await licenseStore.performLicenseCheck()
        }
        
        return true
    }
}
