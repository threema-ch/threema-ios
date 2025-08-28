//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

enum KeychainMigration {

    public enum KeychainMigrationError: Error {
        case loadAllItemsFailed, deleteItemFailed
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
    private static func allItems(of secClass: CFString) throws -> [[CFString: Any]]? {
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
}
