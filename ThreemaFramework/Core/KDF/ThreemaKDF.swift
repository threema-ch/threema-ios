//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class ThreemaKDF {
    private let personal: String
    
    init(personal: String) {
        self.personal = personal
    }
    
    /// Derives a key from a secret key and a salt with BLAKE2b.
    ///
    /// - Parameter salt: Salt for key derivation
    /// - Parameter secretKey: Secret key of 32 bytes length to derive new key from
    ///
    /// - Returns: Derived key of 32 bytes length
    public func deriveKey(salt: String, secretKey: Data) -> Data? {
        guard secretKey.count == THREEMA_KDF_KEYBYTES else {
            return nil
        }
        
        let personalBytes = BytesUtility.padding(
            [UInt8](personal.utf8),
            pad: 0x00,
            length: Int(BLAKE2B_PERSONALBYTES.rawValue)
        )
        let saltBytes = BytesUtility.padding([UInt8](salt.utf8), pad: 0x00, length: Int(BLAKE2B_SALTBYTES.rawValue))

        let pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: Int(THREEMA_KDF_KEYBYTES))

        defer {
            pOut.deallocate()
        }
        
        if blake2b_key_salt_personal(Array(secretKey), saltBytes, personalBytes, pOut) != 0 {
            return nil
        }
        
        return Data(UnsafeMutableBufferPointer(start: pOut, count: Int(THREEMA_KDF_KEYBYTES)))
    }
}
