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

import Foundation

protocol KeychainProviding: Sendable {
    /// Load password/key, generic value and service from Keychain item (class type `kSecClassGenericPassword`).
    ///
    /// - Note: Normally you should just provide a `searchItem`
    ///
    /// - Parameters:
    ///   - searchItem: Keychain item to search for
    ///   - searchAccount: Account mapped to the `kSecAttrAccount` attribute
    /// - Returns: Account, password/key, generic and service attributes or `nil` if entry not found
    func load(
        _ searchItem: KeychainItem?,
        searchAccount: String?
    ) throws -> KeychainItemData?
    
    /// Add or update Password/Key, generic value and service to Keychain item (class type `kSecClassGenericPassword`).
    ///
    /// - Parameters:
    ///   - searchItem: Keychain item to search over `kSecAttrLabel` attribute
    ///   - searchAccount: Search over `kSecAttrAccount` attribute
    ///   - item: Keychain item with label of the entry, stored as `kSecAttrLabel` attribute (will be used to search if
    /// `searchItem` and `searchAccount` are `nil`)
    ///   - account: Account like user name stored as `kSecAttrAccount` attribute
    ///   - password: Password or Key the data is secret (encrypted), stored as `kSecValueData` attribute
    ///   - generic: Generic value e.g. the username to the password, stored as `kSecAttrGeneric` attribute
    ///   - service: Service e.g. URL for given credentials stored as `kSecAttrService` attribute
    /// - Throws: `KeychainManagerError`
    func store(
        searchItem: KeychainItem?,
        searchAccount: String?,
        _ item: KeychainItem,
        account: String?,
        password: Data?,
        generic: Data?,
        service: String?
    ) throws
    
    /// Delete Keychain item.
    /// - Parameters:
    ///   - searchItem: Keychain item with label of the entry, mapped to the `kSecAttrLabel` attribute
    /// - Throws: `KeychainManagerError`
    func delete(_ searchItem: KeychainItem) throws
}

extension KeychainProviding {
    func load(
        _ searchItem: KeychainItem? = nil,
        searchAccount: String? = nil
    ) throws -> KeychainItemData? {
        try load(searchItem, searchAccount: searchAccount)
    }
    
    func store(
        searchItem: KeychainItem? = nil,
        searchAccount: String? = nil,
        _ item: KeychainItem,
        account: String? = nil,
        password: Data? = nil,
        generic: Data? = nil,
        service: String? = nil
    ) throws {
        try store(
            searchItem: searchItem,
            searchAccount: searchAccount,
            item,
            account: account,
            password: password,
            generic: generic,
            service: service
        )
    }
}
