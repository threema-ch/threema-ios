//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaEssentials

public final class KeychainHelper {

    public enum KeychainItem: CustomStringConvertible {
        case deviceGroupKey
        case threemaSafeKey
        case threemaSafeServer

        var label: String {
            switch self {
            case .deviceGroupKey:
                return "Threema Device Group Key 1"
            case .threemaSafeKey:
                return "Threema Safe Key"
            case .threemaSafeServer:
                return "Threema Safe Server"
            }
        }

        public var description: String {
            "\(label)"
        }

        func account(for identity: ThreemaIdentity) -> String {
            switch self {
            case .deviceGroupKey:
                return "\(identity.string)-dgk"
            case .threemaSafeKey, .threemaSafeServer:
                return "\(identity.string)-safe"
            }
        }
    }

    public enum KeychainHelperError: Error {
        case destroyFailed(item: KeychainItem)
        case storeFailed(item: KeychainItem)
    }

    private let identity: ThreemaIdentity

    public init(identity: ThreemaIdentity) {
        self.identity = identity
    }

    // MARK: - Public functions

    /// Load Password/Key, generic value and service from Keychain item (class type `kSecClassGenericPassword`).
    /// - Parameter item: Keychain item
    /// - Returns: Password/Key, generic value and service attribute
    public func load(item: KeychainItem) -> (password: Data?, generic: Data?, service: String?) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: item.account(for: identity),
            kSecAttrLabel: item.label,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnAttributes: true,
            kSecReturnData: true,
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        guard status == errSecSuccess, let result = result as? [CFString: Any] else {
            DDLogNotice("No item (\(item)) was found in keychain. Error: \(status)")
            return (nil, nil, nil)
        }

        var password: Data?
        var generic: Data?
        var service: String?

        if result.keys.contains(kSecValueData) {
            password = result[kSecValueData] as? Data
        }
        if result.keys.contains(kSecAttrGeneric) {
            generic = result[kSecAttrGeneric] as? Data
        }
        if result.keys.contains(kSecAttrService),
           let value = result[kSecAttrService] as? String,
           value != "" {
            service = value
        }

        return (password, generic, service)
    }

    /// Add or update Password/Key, generic value and service to Keychain item (class type `kSecClassGenericPassword`).
    /// - Parameters:
    ///   - password: Password or Key the data is secret (encrypted), stored as `kSecValueData` attribute
    ///   - generic: Generic value e.g. the username to the password
    ///   - service: Service e.g. URL for given credentials stored as `kSecAttrService` attribute
    ///   - item: Keychain item
    /// - Throws: `KeychainHelperError.storeFailed(item: _)`
    public func store(password: Data, generic: Data? = nil, service: String? = nil, item: KeychainItem) throws {
        let (existingPassword, existingGeneric, existingService) = load(item: item)

        if let existingPassword {
            guard existingPassword != password || existingGeneric != generic || existingService != service else {
                return
            }

            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecAttrAccount: item.account(for: identity),
                kSecAttrLabel: item.label,
            ] as CFDictionary

            var attributesToUpdate = [
                kSecAttrAccount: item.account(for: identity),
                kSecValueData: password,
            ] as [CFString: Any]

            if let generic {
                attributesToUpdate[kSecAttrGeneric] = generic
            }
            if let service {
                attributesToUpdate[kSecAttrService] = service
            }

            let status = SecItemUpdate(query, attributesToUpdate as CFDictionary)
            guard status == errSecSuccess else {
                DDLogError("Update item (\(item)) in keychain failed. Error: \(status)")
                throw KeychainHelperError.storeFailed(item: item)
            }
        }
        else {
            var query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecAttrIsInvisible: kCFBooleanTrue!,
                kSecAttrAccount: item.account(for: identity),
                kSecAttrLabel: item.label,
                kSecValueData: password,
            ] as [CFString: Any]

            if let generic {
                query[kSecAttrGeneric] = generic
            }
            if let service {
                query[kSecAttrService] = service
            }

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                DDLogError("Add item (\(item)) in keychain failed. Error: \(status)")
                throw KeychainHelperError.storeFailed(item: item)
            }
        }
    }

    /// Delete Keychain item.
    /// - Parameter item: Keychain item to delete
    /// - Throws: `KeychainHelperError.destroyFailed(item: _)`
    public func destroy(item: KeychainItem) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: item.account(for: identity),
            kSecAttrLabel: item.label,
        ] as CFDictionary

        if SecItemCopyMatching(query, nil) == errSecSuccess {
            let status = SecItemDelete(query)
            guard status == errSecSuccess else {
                DDLogError("Delete item (\(item)) from keychain failed. Error: \(status)")
                throw KeychainHelperError.destroyFailed(item: item)
            }
        }
    }
}
