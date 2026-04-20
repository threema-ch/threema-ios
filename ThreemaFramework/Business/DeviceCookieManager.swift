import CocoaLumberjackSwift
import Foundation
import Keychain
import Security
import ThreemaEssentials

@objc final class DeviceCookieManager: NSObject {

    private static let deviceCookieSize = 16
    private static let legacyUserDefaultsKey = "LastEphemeralKeyHashes"

    private static var skipNextIndication = false

    /// Obtain the device cookie from the keychain, or generate a new one if there is none.
    /// - Returns: the 16 byte device cookie, or nil on failure
    @objc static func obtainDeviceCookie() -> Data? {
        // Remove legacy user defaults entry
        AppGroup.userDefaults().removeObject(forKey: DeviceCookieManager.legacyUserDefaultsKey)

        let keychainManager = KeychainManager(remoteSecretManager: AppLaunchManager.remoteSecretManager)

        do {
            // Check if we already have a device cookie in the keychain
            if let cookie = try keychainManager.loadDeviceCookie() {
                guard cookie.count == DeviceCookieManager.deviceCookieSize else {
                    DDLogError("Bad Keychain item data")
                    try KeychainManager.deleteDeviceCookie()
                    return nil
                }

                DDLogDebug("Got device cookie from keychain: \(cookie.prefix(2).hexString)...")

                return cookie
            }

            // Generate new device cookie
            let newCookie = BytesUtility.generateRandomBytes(length: DeviceCookieManager.deviceCookieSize)!
            try keychainManager.storeDeviceCookie(newCookie)

            DDLogNotice("Stored new device cookie in Keychain: \(newCookie.prefix(2).hexString)...")

            // Skip the next indication, as we have just generated a new cookie and
            // will get an indication for sure if this is a restored ID (where the
            // server has already stored a device cookie).
            DeviceCookieManager.skipNextIndication = true

            return newCookie
        }
        catch {
            DDLogError("Couldn't get/set device cookie from Keychain: \(error)")
            return nil
        }
    }

    /// Notify that a device cookie change indication has been received. A user alert will be generated.
    /// - Returns: true if the indication should be cleared, false if not
    @objc static func changeIndicationReceived() -> Bool {
        if DeviceCookieManager.skipNextIndication {
            DDLogNotice("Skipping change indication because new device cookie has been generated")
            DeviceCookieManager.skipNextIndication = false
            return true
        }

        if AppGroup.getCurrentType() == AppGroupTypeApp {
            // Post user notification, clear indication only when user confirms
            NotificationCenter.default.post(name: .errorRogueDevice, object: nil)
        }

        return false
    }

    @objc static func deleteDeviceCookie() {
        do {
            try KeychainManager.deleteDeviceCookie()
        }
        catch {
            DDLogError("Couldn't delete device cookie in Keychain: \(error)")
        }
    }
}
