//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

protocol DeviceGroupKeyManagerProtocol {
    var dgk: Data? { get }
    func load() -> Data?
    func destroy() -> Bool
    func store(dgk: Data) -> Bool
}

public class DeviceGroupKeyManager: NSObject, DeviceGroupKeyManagerProtocol {
    private let keychainLabel = "Threema Device Group Key 1"

    private let myIdentityStore: MyIdentityStoreProtocol

    @objc public required init(myIdentityStore: MyIdentityStoreProtocol) {
        self.myIdentityStore = myIdentityStore
    }

    /// Device Group Key stored in keychain.
    @objc public var dgk: Data? {
        load()
    }

    /// Create new DGK and store it (override) in keychain.
    public func create() -> Data? {
        guard let key = BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen)) else {
            return nil
        }
        guard store(dgk: key) else {
            return nil
        }
        return key
    }

    /// Load DGK from Keychain
    /// - Returns: DGK or nil if not found
    public func load() -> Data? {
        guard let account = accountForDgk() else {
            return nil
        }

        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: keychainLabel.data(using: .utf8)!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(matchQuery as CFDictionary, &result)
        guard status == errSecSuccess else {
            DDLogError("Device Group Key not found: \(status)")
            return nil
        }

        guard let resultAccount = result?[kSecAttrAccount] as? Data,
              let resultKey = result?[kSecValueData] as? Data else {
            DDLogError("Device Group Key failed to extract account and key")
            return nil
        }

        guard account.elementsEqual(resultAccount) else {
            DDLogError("Device Group Key failed account mismatch")
            return nil
        }

        return resultKey
    }

    /// Destroy DGK from Keychain.
    /// - Returns: True if key founded and destroyed
    @discardableResult @objc public func destroy() -> Bool {
        guard let account = accountForDgk() else {
            return false
        }

        let matchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        if SecItemCopyMatching(matchQuery as CFDictionary, nil) == errSecSuccess {
            SecItemDelete(matchQuery as CFDictionary)
        }

        return true
    }

    /// Store DGK into Keychain.
    /// - Parameter dgk: Device Group Key
    /// - Returns: True DGK stored successfully
    @discardableResult public func store(dgk: Data) -> Bool {
        guard let account = accountForDgk() else {
            return false
        }

        destroy()

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: keychainLabel.data(using: .utf8)!,
            kSecValueData as String: dgk,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            DDLogError("Storing Device Group Key failed: \(status)")
            return false
        }

        return true
    }

    private func accountForDgk() -> Data? {
        guard let identity = myIdentityStore.identity, let account: Data = "\(identity)-dgk".data(using: .utf8) else {
            DDLogError("Loading Device Group Key failed, because of missing identity")
            return nil
        }
        return account
    }
}
