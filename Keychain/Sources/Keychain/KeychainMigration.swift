import Foundation
import ThreemaEssentials

enum KeychainMigration {

    public enum KeychainMigrationError: Error {
        case loadAllItemsFailed
        case deleteItemFailed
        case itemNotFound
        case passwordMissing
        case serviceMissing
    }

    /// Delete all (incompatible) Keychain items expect "Threema identity 1" and all Passcode items.
    static func migrateToDowngrade() throws {
        guard let items = try KeychainMigration.allItems(of: kSecClassGenericPassword) else {
            return
        }

        for item in items {
            guard item[kSecAttrLabel] as? String != "Threema identity 1" else {
                continue
            }

            guard (item[kSecAttrAccount] as? String)?.suffix("passcode_on".count) != "passcode_on",
                  (item[kSecAttrAccount] as? String)?.suffix("erase_data_on".count) != "erase_data_on",
                  (item[kSecAttrAccount] as? String)?.suffix("grace_period".count) != "grace_period",
                  (item[kSecAttrAccount] as? String)?.suffix("touch_id_on".count) != "touch_id_on" else {
                continue
            }

            var deleteQuery = [kSecClass: kSecClassGenericPassword] as [CFString: Any]

            if item.keys.contains(kSecAttrLabel), let label = item[kSecAttrLabel] as? String, !label.isEmpty {
                deleteQuery[kSecAttrLabel] = item[kSecAttrLabel]
            }
            if item.keys.contains(kSecAttrAccount), let account = item[kSecAttrAccount] as? String, !account.isEmpty {
                deleteQuery[kSecAttrAccount] = item[kSecAttrAccount]
            }
            if item.keys.contains(kSecAttrService), let service = item[kSecAttrService] as? String, !service.isEmpty {
                deleteQuery[kSecAttrService] = item[kSecAttrService]
            }

            let status = SecItemDelete(deleteQuery as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainMigrationError.deleteItemFailed
            }
        }
    }

    /// All Keychain items of the current App Entitlement.
    /// - Parameter secClass: Get items of type kSecClass
    /// - Returns: Keychain items
    static func allItems(of secClass: CFString) throws -> [[CFString: Any]]? {
        let query = [
            kSecClass: secClass,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
        ] as CFDictionary

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)

        guard status == errSecSuccess else {
            switch status {
            case errSecItemNotFound:
                return nil
            default:
                throw KeychainMigrationError.loadAllItemsFailed
            }
        }

        return result as? [[CFString: Any]]
    }

    /// Migrate attribute `kSecAttrAccessible` to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` of Keychain item
    /// Identity.
    static func migrateToVersion0(using keychainProvider: KeychainProviding = KeychainProvider()) throws {
        guard let result = try keychainProvider.load(.identity(.v0)) else {
            throw KeychainMigrationError.itemNotFound
        }

        try keychainProvider.store(
            searchItem: KeychainItem.identity(.v0),
            .identity(.v0),
            account: result.account,
            password: result.password,
            generic: result.generic,
            service: result.service
        )
    }

    /// Migrate all exists Keychain items, except Identity, to uniform and unique labels.
    /// After this we are able to implement additional encryption to all other attributes,
    /// that's needed for Remote Secret!
    static func migrateToVersion1(
        myIdentity: ThreemaIdentity,
        keychainProvider: KeychainProviding = KeychainProvider()
    ) throws {
        // Migrate Identity Backup
        if let result = try keychainProvider.load(KeychainItem.identityBackup(.v0)) {
            guard let password = result.password else {
                throw KeychainMigrationError.passwordMissing
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.identityBackup(.v1))

            try keychainProvider.store(
                searchItem: KeychainItem.identityBackup(.v0),
                .identityBackup(.v1),
                account: KeychainItem.identityBackup(.v1).label,
                password: password
            )
        }

        // Migrate Device Cookie
        if let result = try keychainProvider.load(searchAccount: KeychainItem.deviceCookie(.v0).label) {
            guard let password = result.password else {
                throw KeychainMigrationError.passwordMissing
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.deviceCookie(.v1))

            try keychainProvider.store(
                searchAccount: KeychainItem.deviceCookie(.v0).label,
                .deviceCookie(.v1),
                account: KeychainItem.deviceCookie(.v1).label,
                password: password
            )
        }

        // Migrate Device Group Key
        let searchAccountForDeviceGroupKey = "\(myIdentity.rawValue)-dgk"
        if let result = try keychainProvider.load(
            .multiDeviceGroupKey(.v0),
            searchAccount: searchAccountForDeviceGroupKey
        ) {
            guard let password = result.password else {
                throw KeychainMigrationError.passwordMissing
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.multiDeviceGroupKey(.v1))

            try keychainProvider.store(
                searchItem: .multiDeviceGroupKey(.v0),
                searchAccount: searchAccountForDeviceGroupKey,
                .multiDeviceGroupKey(.v1),
                account: KeychainItem.multiDeviceGroupKey(.v1).label,
                password: password
            )
        }

        // Migrate Forward Security Wrapping Key
        let searchAccountForForwardSecurityWrappingKey = "Threema FS wrapping key"
        if let result = try keychainProvider.load(searchAccount: searchAccountForForwardSecurityWrappingKey) {
            guard let password = result.password else {
                throw KeychainMigrationError.passwordMissing
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.forwardSecurityWrappingKey(.v1))

            try keychainProvider.store(
                searchAccount: searchAccountForForwardSecurityWrappingKey,
                .forwardSecurityWrappingKey(.v1),
                account: KeychainItem.forwardSecurityWrappingKey(.v1).label,
                password: password
            )
        }

        // Migrate Threema Safe Key
        let searchAccountForThreemaSafe = "\(myIdentity.rawValue)-safe"

        if let result = try keychainProvider.load(
            .threemaSafeKey(.v0),
            searchAccount: searchAccountForThreemaSafe
        ) {
            guard let password = result.password else {
                throw KeychainMigrationError.passwordMissing
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.threemaSafeKey(.v1))

            try keychainProvider.store(
                searchItem: .threemaSafeKey(.v0),
                searchAccount: searchAccountForThreemaSafe,
                .threemaSafeKey(.v1),
                account: KeychainItem.threemaSafeKey(.v1).label,
                password: password
            )
        }

        // Migrate Threema Safe Server
        if let result = try keychainProvider.load(
            .threemaSafeServer(.v0),
            searchAccount: searchAccountForThreemaSafe
        ) {
            guard let service = result.service else {
                throw KeychainMigrationError.serviceMissing
            }

            var account: String?
            if let generic = result.generic {
                account = String(data: generic, encoding: .utf8)
            }
            
            // Delete existing item we want to migrate to, if needed
            // This might happen if a user downgrades from 6.9+ to 6.8.8- by deleting the app on the home screen and
            // then upgrades again to 6.9+ (IOS-5855)
            try keychainProvider.delete(.threemaSafeServer(.v1))

            try keychainProvider.store(
                searchItem: .threemaSafeServer(.v0),
                searchAccount: searchAccountForThreemaSafe,
                .threemaSafeServer(.v1),
                account: account,
                password: result.password,
                generic: Data(), // Override with empty bytes, because update to `nil` is not possible
                service: service
            )
        }
    }
}
