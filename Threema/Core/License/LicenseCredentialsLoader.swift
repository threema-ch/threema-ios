import CocoaLumberjackSwift
import Foundation
import Keychain

// MARK: - OnboardingLicenseCredentialsLoading

/// Source of license credentials that were stored by a previous installation of this app
protocol OnboardingLicenseCredentialsLoading {
    /// Credentials that can be used before the app is set up, `nil` if there are none
    func loadCredentials() throws -> LicenseCredentials?
}

// MARK: - KeychainLicenseCredentialsLoader

struct KeychainLicenseCredentialsLoader: OnboardingLicenseCredentialsLoading {

    func loadCredentials() throws -> LicenseCredentials? {
        guard let license = try KeychainManager.loadUnencryptedLicense() else {
            DDLogNotice("[LicenseCredentialsLoader] No (unencrypted) license in keychain")
            return nil
        }

        return LicenseCredentials(
            username: license.user,
            password: license.password,
            server: license.onPremServer,
            deviceID: license.deviceID
        )
    }
}
