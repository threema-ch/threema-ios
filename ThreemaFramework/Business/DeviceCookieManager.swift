//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import Security

@objc class DeviceCookieManager: NSObject {
    
    private static let keychainService = "Threema device cookie"
    private static let keychainAccount = "Threema device cookie"
    private static let deviceCookieSize = 16
    private static let legacyUserDefaultsKey = "LastEphemeralKeyHashes"
    
    private static var skipNextIndication = false
    
    /// Obtain the device cookie from the keychain, or generate a new one if there is none.
    /// - Returns: the 16 byte device cookie, or nil on failure
    @objc static func obtainDeviceCookie() -> Data? {
        // Remove legacy user defaults entry
        AppGroup.userDefaults().removeObject(forKey: DeviceCookieManager.legacyUserDefaultsKey)
        
        // Check if we already have a device cookie in the keychain
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: DeviceCookieManager.keychainService,
            kSecAttrAccount: DeviceCookieManager.keychainAccount,
            kSecReturnData: true,
        ] as CFDictionary
        
        var item: AnyObject?
        
        let result = SecItemCopyMatching(query, &item)
        switch result {
        case errSecItemNotFound:
            break
        case errSecSuccess:
            guard let itemData = item as? Data, itemData.count == DeviceCookieManager.deviceCookieSize else {
                DDLogError("Bad keychain item data")
                deleteDeviceCookie()
                return nil
            }
            DDLogDebug("Got device cookie from keychain: \(itemData.prefix(2).hexString)...")
            return itemData
        default:
            DDLogError("Keychain query failed: \(result)")
            return nil
        }
        
        // Generate new device cookie
        let newCookie = BytesUtility.generateRandomBytes(length: DeviceCookieManager.deviceCookieSize)!
        
        let addQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: DeviceCookieManager.keychainService,
            kSecAttrAccount: DeviceCookieManager.keychainAccount,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: newCookie,
        ] as CFDictionary
        
        let addResult = SecItemAdd(addQuery, nil)
        guard addResult == errSecSuccess else {
            DDLogError("Keychain store failed: \(addResult)")
            return nil
        }
        
        DDLogNotice("Stored new device cookie in keychain: \(newCookie.prefix(2).hexString)...")
        
        // Skip the next indication, as we have just generated a new cookie and
        // will get an indication for sure if this is a restored ID (where the
        // server has already stored a device cookie).
        DeviceCookieManager.skipNextIndication = true
        
        return newCookie
    }
    
    /// Notify that a device cookie change indication has been received. A user alert will be generated.
    /// - Returns: true if the indication should be cleared, false if not
    @objc static func changeIndicationReceived() -> Bool {
        if DeviceCookieManager.skipNextIndication {
            DDLogNotice("Skipping change indication because new cookie has been generated")
            DeviceCookieManager.skipNextIndication = false
            return true
        }
        
        if AppGroup.getCurrentType() == AppGroupTypeApp {
            // Post user notification, clear indication only when user confirms
            NotificationCenter.default.post(name: Notification.Name(kNotificationErrorRogueDevice), object: nil)
        }
        
        return false
    }
    
    @objc static func deleteDeviceCookie() {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: DeviceCookieManager.keychainService,
            kSecAttrAccount: DeviceCookieManager.keychainAccount,
        ] as CFDictionary
        
        let result = SecItemDelete(query)
        if result != errSecSuccess {
            DDLogError("Couldn't delete device cookie in keychain: \(result)")
        }
    }
}
