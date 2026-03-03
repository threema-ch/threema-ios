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

enum KeychainProviderError: Error {
    case itemOrAccountMissing
    case deleteFailed(osStatus: Int32)
    case loadFailed(osStatus: Int32)
    case storeFailed(osStatus: Int32)
}

final class KeychainProvider: KeychainProviding {
    func load(
        _ searchItem: KeychainItem?,
        searchAccount: String?
    ) throws -> KeychainItemData? {
        guard searchItem != nil || searchAccount != nil else {
            throw KeychainProviderError.itemOrAccountMissing
        }

        var query = [
            kSecClass: kSecClassGenericPassword,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnAttributes: true,
            kSecReturnData: true,
        ] as [CFString: Any]

        if let searchLabel = searchItem?.label {
            query[kSecAttrLabel] = searchLabel
        }
        if let searchAccount {
            query[kSecAttrAccount] = searchAccount
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let result = result as? [CFString: Any] else {
            guard status != errSecItemNotFound else {
                return nil
            }
            throw KeychainProviderError.loadFailed(osStatus: status)
        }

        var accessible: CFString?
        var label: String?
        var account: String?
        var password: Data?
        var generic: Data?
        var service: String?

        if result.keys.contains(kSecAttrAccessible),
           let value = result[kSecAttrAccessible] as? String {
            accessible = value as CFString
        }
        if result.keys.contains(kSecAttrLabel),
           let value = result[kSecAttrLabel] as? String {
            label = value
        }
        if result.keys.contains(kSecAttrAccount),
           let value = result[kSecAttrAccount] as? String {
            account = value
        }
        if result.keys.contains(kSecValueData) {
            password = result[kSecValueData] as? Data
        }
        if result.keys.contains(kSecAttrGeneric) {
            generic = result[kSecAttrGeneric] as? Data
        }
        if result.keys.contains(kSecAttrService),
           let value = result[kSecAttrService] as? String,
           !value.isEmpty {
            service = value
        }

        return KeychainItemData(
            accessibility: accessible,
            label: label,
            account: account,
            password: password,
            generic: generic,
            service: service
        )
    }
    
    func store(
        searchItem: KeychainItem?,
        searchAccount: String?,
        _ item: KeychainItem,
        account: String?,
        password: Data?,
        generic: Data?,
        service: String?
    ) throws {
        func itemToSearch() -> KeychainItem? {
            if searchItem == nil, searchAccount == nil {
                item
            }
            else {
                searchItem
            }
        }

        var result: KeychainItemData?
        do {
            result = try load(itemToSearch(), searchAccount: searchAccount)
        }
        catch let KeychainProviderError.loadFailed(osStatus: osStatus) {
            guard osStatus == errSecItemNotFound else {
                throw KeychainProviderError.loadFailed(osStatus: osStatus)
            }
        }

        if let result {
            let newData = KeychainItemData(
                accessibility: item.accessibility,
                label: item.label,
                account: account,
                password: password,
                generic: generic,
                service: service
            )
            
            guard result != newData else {
                return
            }

            var query = [
                kSecClass: kSecClassGenericPassword,
            ] as [CFString: Any]

            if let searchLabel = itemToSearch()?.label {
                query[kSecAttrLabel] = searchLabel
            }
            if let searchAccount {
                query[kSecAttrAccount] = searchAccount
            }

            var attributesToUpdate = [
                kSecAttrAccessible: item.accessibility,
                kSecAttrLabel: item.label,
            ] as [CFString: Any]

            if let account {
                attributesToUpdate[kSecAttrAccount] = account
            }
            if let password {
                attributesToUpdate[kSecValueData] = password
            }
            if let generic {
                attributesToUpdate[kSecAttrGeneric] = generic
            }
            if let service {
                attributesToUpdate[kSecAttrService] = service
            }

            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainProviderError.storeFailed(osStatus: status)
            }
        }
        else {
            var attributesToAdd = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccessible: item.accessibility,
                kSecAttrIsInvisible: kCFBooleanTrue!,
                kSecAttrLabel: item.label,
            ] as [CFString: Any]

            if let account {
                attributesToAdd[kSecAttrAccount] = account
            }
            if let password {
                attributesToAdd[kSecValueData] = password
            }
            if let generic {
                attributesToAdd[kSecAttrGeneric] = generic
            }
            if let service {
                attributesToAdd[kSecAttrService] = service
            }

            let status = SecItemAdd(attributesToAdd as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainProviderError.storeFailed(osStatus: status)
            }
        }
    }
    
    func delete(_ searchItem: KeychainItem) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: searchItem.label,
        ] as CFDictionary

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainProviderError.deleteFailed(osStatus: status)
            }
        }
    }
}
