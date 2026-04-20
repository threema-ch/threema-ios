import CocoaLumberjackSwift
import Foundation
import Keychain
import UIKit

extension EnterLicenseViewController {
    /// Tries to save the passed parameters to Keychain, will fail **Silently** if business is not ready
    /// - Parameters:
    ///   - user: Username
    ///   - password: Password
    ///   - deviceID: DeviceID
    ///   - onPremServer: OnPrem Server
    @objc public func storeToKeychain(user: String, password: String, deviceID: String?, onPremServer: String?) {

        do {
            let business = try AppLaunchManager.shared.business(forBackgroundProcess: false)
            let keychainManager = business.keychainManager
            
            try keychainManager.storeLicense(ThreemaLicense(
                user: user,
                password: password,
                deviceID: deviceID,
                onPremServer: onPremServer
            ))
        }
        catch {
            DDLogInfo("[EnterLicenseViewController] Failed to store license info to keychain: \(error)")
        }
    }
}
