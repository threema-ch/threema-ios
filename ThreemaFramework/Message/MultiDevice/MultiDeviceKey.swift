//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc class MultiDeviceKey: NSObject {
    /// Derives a mediator path key from a secret key.
    ///
    /// - Parameter secretKey: Secret key of 32 bytes length
    ///
    /// - Returns: Derived mediator path key of 32 bytes length or nil if something is wrong
    @objc func derive(secretKey: Data) -> Data? {
        guard secretKey.count == THREEMA_KDF_KEYBYTES else {
            return nil
        }
        
        let kdf = ThreemaKDF(personal: "3ma-mdev")
        guard let mk = kdf.deriveKey(salt: "mk", secretKey: secretKey) else {
            return nil
        }
        let mpk = kdf.deriveKey(salt: "mpk", secretKey: mk)
        
        return mpk
    }
}
