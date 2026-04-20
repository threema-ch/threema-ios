import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

@MainActor
final class BootstrapLicenseService {

    private let licenseStore: LicenseStoreProtocol
    private let appLaunchManager: AppLaunchManagerProtocol

    init(
        licenseStore: LicenseStoreProtocol,
        appLaunchManager: AppLaunchManagerProtocol
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
