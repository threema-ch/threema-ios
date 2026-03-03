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
import ThreemaEssentials

public protocol KeychainManagerProtocol: Sendable {
    static func loadRemoteSecret() throws -> (
        authenticationToken: Data,
        identityHash: Data
    )?
    static func storeRemoteSecret(authenticationToken: Data, identityHash: Data) throws
    static func deleteRemoteSecret() throws
    
    static func loadThreemaIdentity() throws -> ThreemaIdentity?
    
    func loadIdentity() throws -> MyIdentity?
    func storeIdentity(_ myIdentity: MyIdentity) throws
    func deleteIdentity() throws

    static func loadIdentityBackup() throws -> String
    static func storeIdentityBackup(_ data: String) throws
    static func deleteIdentityBackup() throws

    func loadDeviceCookie() throws -> Data?
    func storeDeviceCookie(_ cookie: Data) throws
    func deleteDeviceCookie() throws

    func loadMultiDeviceGroupKey() throws -> Data?
    func storeMultiDeviceGroupKey(key: Data) throws
    /// This function is static, since we must be able to delete the key in setup
    static func deleteMultiDeviceGroupKey() throws
    
    func loadMultiDeviceID() throws -> Data?
    func storeMultiDeviceID(id: Data) throws
    func deleteMultiDeviceID() throws

    func loadForwardSecurityWrappingKey() throws -> Data?
    func storeForwardSecurityWrappingKey(_ key: Data) throws
    func deleteForwardSecurityKey() throws

    static func loadOnPremServer() throws -> String?

    func loadLicense() throws -> ThreemaLicense?
    func storeLicense(_ license: ThreemaLicense) throws
    func deleteLicense() throws

    func loadThreemaSafeKey() throws -> Data?
    func storeThreemaSafeKey(key: Data) throws
    func deleteThreemaSafeKey() throws

    func loadThreemaSafeServer() throws -> ThreemaSafeServerInfo?
    func storeThreemaSafeServer(_ safeServer: ThreemaSafeServerInfo) throws
    func deleteThreemaSafeServer() throws

    func migrateToDowngrade() throws
    func migrateToVersion0() throws
    func migrateToVersion1(myIdentity: ThreemaIdentity) throws
}
