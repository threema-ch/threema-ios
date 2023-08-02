//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class DeviceGroupDerivedKey: NSObject {

    enum DeviceGroupKeyDeriverError: Error {
        case deriveKeyFailed
    }

    private enum DeviceGroupKeyDeriver {
        case dgpk
        case dgrk
        case dgdik
        case dgsddk
        case dgtsk

        func derive(dgk: Data) throws -> Data {
            switch self {
            case .dgpk: return try derive(dgk: dgk, salt: "p")
            case .dgrk: return try derive(dgk: dgk, salt: "r")
            case .dgdik: return try derive(dgk: dgk, salt: "di")
            case .dgsddk: return try derive(dgk: dgk, salt: "sdd")
            case .dgtsk: return try derive(dgk: dgk, salt: "ts")
            }
        }

        private func derive(dgk: Data, salt: String) throws -> Data {
            guard dgk.count == ThreemaKDF.THREEMA_KDF_KEYBYTES else {
                throw DeviceGroupKeyDeriverError.deriveKeyFailed
            }

            let kdf = ThreemaKDF(personal: "3ma-mdev")
            guard let key = kdf.deriveKey(salt: salt, key: dgk) else {
                throw DeviceGroupKeyDeriverError.deriveKeyFailed
            }

            return key
        }
    }

    /// Device Group Path Key
    @objc var dgpk: Data

    /// Device Group Reflect Key
    @objc var dgrk: Data

    /// Device Group Device Info Key
    @objc var dgdik: Data

    /// Device Group Shared Device Data Key
    @objc var dgsddk: Data

    /// Device Group Transaction Scope Key
    @objc var dgtsk: Data

    /// Derive all device group keys.
    ///
    /// - Parameter dgk: Device Group Key (32 bytes length)
    @objc required init(dgk: Data) throws {
        guard dgk.count == ThreemaKDF.THREEMA_KDF_KEYBYTES else {
            throw DeviceGroupKeyDeriverError.deriveKeyFailed
        }

        self.dgpk = try DeviceGroupKeyDeriver.dgpk.derive(dgk: dgk)
        self.dgrk = try DeviceGroupKeyDeriver.dgrk.derive(dgk: dgk)
        self.dgdik = try DeviceGroupKeyDeriver.dgdik.derive(dgk: dgk)
        self.dgsddk = try DeviceGroupKeyDeriver.dgsddk.derive(dgk: dgk)
        self.dgtsk = try DeviceGroupKeyDeriver.dgtsk.derive(dgk: dgk)

        super.init()
    }
}
