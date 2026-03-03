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
import Keychain
import ThreemaEssentials
import ThreemaEssentialsTestHelper

// MARK: - Helper to make mock sendable

private final class SendableRemoteSecretInfo: @unchecked Sendable {
    var value: (authenticationToken: Data, identityHash: Data)? {
        get { accessQueue.sync { internalValue } }
        set { accessQueue.sync { internalValue = newValue } }
    }
    
    private let accessQueue = DispatchQueue(label: "ch.threema.SendableRemoteSecretInfo")
    private var internalValue: (authenticationToken: Data, identityHash: Data)?
}

// MARK: - The actual mock

public final class KeychainManagerMock: KeychainManagerProtocol, @unchecked Sendable {
    
    @Atomic
    public private(set) var loadMultiDeviceGroupKeyCalls = 0
    
    @Atomic
    public private(set) var storeMultiDeviceGroupKeyCalls = [Data]()
    
    @Atomic
    public private(set) var storeMultiDeviceIDCalls = [Data]()
    
    @Atomic
    public private(set) var storeLicenseCalls = [String]()
    
    @Atomic
    public private(set) var migrateToDowngradeCalls = 0
    
    @Atomic
    public private(set) var migrateToVersion0Calls = 0
    
    @Atomic
    public private(set) var migrateToVersion1Calls = 0

    private static let remoteSecretInfo = SendableRemoteSecretInfo()
    
    public init() {
        // no-op
    }
    
    public static func loadRemoteSecret() throws -> (
        authenticationToken: Data,
        identityHash: Data
    )? {
        remoteSecretInfo.value
    }
    
    public static func storeRemoteSecret(authenticationToken: Data, identityHash: Data) throws {
        remoteSecretInfo.value = (authenticationToken, identityHash)
    }
    
    public static func deleteRemoteSecret() throws {
        remoteSecretInfo.value = nil
    }
    
    public static func loadThreemaIdentity() throws -> ThreemaIdentity? {
        ThreemaIdentity("ABCDEFGH")
    }

    public func loadIdentity() throws -> MyIdentity? {
        nil
    }

    public func storeIdentity(_ myIdentity: MyIdentity) throws {
        // no-op
    }

    public func deleteIdentity() throws {
        // no-op
    }

    public static func loadIdentityBackup() throws -> String {
        ""
    }

    public static func storeIdentityBackup(_ data: String) throws {
        // no-op
    }

    public static func deleteIdentityBackup() throws {
        // no-op
    }

    public func loadDeviceCookie() throws -> Data? {
        nil
    }

    public func storeDeviceCookie(_ cookie: Data) throws {
        // no-op
    }

    public func deleteDeviceCookie() throws {
        // no-op
    }

    public func loadMultiDeviceGroupKey() throws -> Data? {
        loadMultiDeviceGroupKeyCalls += 1
        return storeMultiDeviceGroupKeyCalls.first
    }

    public func storeMultiDeviceGroupKey(key: Data) throws {
        $storeMultiDeviceGroupKeyCalls.append(key)
    }

    public static func deleteMultiDeviceGroupKey() throws {
        // no-op
    }

    public func loadMultiDeviceID() -> Data? {
        nil
    }

    public func storeMultiDeviceID(id: Data) throws {
        $storeMultiDeviceIDCalls.append(id)
    }

    public func deleteMultiDeviceID() throws {
        // no-op
    }

    public func loadForwardSecurityWrappingKey() throws -> Data? {
        nil
    }

    public func storeForwardSecurityWrappingKey(_ key: Data) throws {
        // no-op
    }

    public func deleteForwardSecurityKey() throws {
        // no-op
    }

    public static func loadOnPremServer() throws -> String? {
        nil
    }

    public func loadLicense() throws -> ThreemaLicense? {
        nil
    }

    public func storeLicense(_ license: ThreemaLicense) throws {
        $storeLicenseCalls.append(license.password)
    }

    public func deleteLicense() throws {
        // no-op
    }

    public func loadThreemaSafeKey() throws -> Data? {
        nil
    }

    public func storeThreemaSafeKey(key: Data) throws {
        // no-op
    }

    public func deleteThreemaSafeKey() throws {
        // no-op
    }

    public func loadThreemaSafeServer() throws -> ThreemaSafeServerInfo? {
        nil
    }

    public func storeThreemaSafeServer(_ safeServer: ThreemaSafeServerInfo) throws {
        // no-op
    }

    public func deleteThreemaSafeServer() throws {
        // no-op
    }

    public func migrateToDowngrade() throws {
        $migrateToDowngradeCalls += 1
    }

    public func migrateToVersion0() throws {
        $migrateToVersion0Calls += 1
    }

    public func migrateToVersion1(myIdentity: ThreemaEssentials.ThreemaIdentity) throws {
        $migrateToVersion1Calls += 1
    }
}
