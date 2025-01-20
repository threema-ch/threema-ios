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
import ThreemaEssentials

protocol DeviceGroupKeyManagerProtocol {
    var dgk: Data? { get }
    func load() -> Data?
    func destroy() -> Bool
    func store(dgk: Data) -> Bool
}

public class DeviceGroupKeyManager: NSObject, DeviceGroupKeyManagerProtocol {
    private let keychainLabel = "Threema Device Group Key 1"

    private let myIdentityStore: MyIdentityStoreProtocol

    var keychainHelper: KeychainHelper? {
        guard let identity = myIdentityStore.identity else {
            return nil
        }

        return KeychainHelper(identity: ThreemaIdentity(identity))
    }

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
        guard let keychainHelper else {
            return nil
        }

        let (key, _, _) = keychainHelper.load(item: .deviceGroupKey)
        return key
    }

    /// Destroy DGK from Keychain.
    /// - Returns: True if key founded and destroyed
    @discardableResult @objc public func destroy() -> Bool {
        guard let keychainHelper else {
            return false
        }

        do {
            try keychainHelper.destroy(item: .deviceGroupKey)
            return true
        }
        catch {
            return false
        }
    }

    /// Store DGK into Keychain.
    /// - Parameter dgk: Device Group Key
    /// - Returns: True DGK stored successfully
    @discardableResult public func store(dgk: Data) -> Bool {
        guard let keychainHelper else {
            return false
        }

        do {
            try keychainHelper.store(password: dgk, item: .deviceGroupKey)
            return true
        }
        catch {
            return false
        }
    }
}
