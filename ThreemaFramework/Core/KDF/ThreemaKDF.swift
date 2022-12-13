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

@objc class ThreemaKDF: NSObject {
    private let personal: String
    
    @objc init(personal: String) {
        self.personal = personal
    }
    
    /// Derives a key from a key and a salt with BLAKE2b.
    ///
    /// - Parameter salt: Salt for key derivation
    /// - Parameter key: Key of 32 bytes length to derive new key from
    ///
    /// - Returns: Derived key of 32 bytes length
    @objc public func deriveKey(salt: String, key: Data) -> Data? {
        guard key.count == THREEMA_KDF_KEYBYTES else {
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
        
        if blake2b_key_salt_personal(Array(key), saltBytes, personalBytes, pOut) != 0 {
            return nil
        }
        
        return Data(UnsafeMutableBufferPointer(start: pOut, count: Int(THREEMA_KDF_KEYBYTES)))
    }
    
    /// Calculates a keyed MAC using BLAKE2b.
    ///
    /// - Parameter key: Key of 32 bytes length
    /// - Parameter input: Input data of arbitrary length
    ///
    /// - Returns: MAC of 32 bytes length
    @objc public static func calculateMac(key: Data, input: Data) -> Data? {
        guard key.count == THREEMA_KDF_SUBKEYBYTES else {
            return nil
        }
        
        let pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: Int(THREEMA_KDF_MAC_LENGTH))
        
        defer {
            pOut.deallocate()
        }
        
        if blake2b_mac(Array(key), Array(input), input.count, pOut) != 0 {
            return nil
        }
        
        return Data(UnsafeMutableBufferPointer(start: pOut, count: Int(THREEMA_KDF_MAC_LENGTH)))
    }
    
    /// Calculates a simple hash using BLAKE2b.
    ///
    /// - Parameter input: Input data of arbitrary length
    ///
    /// - Returns: hash of 32 bytes length
    @objc public static func hash(input: Data) -> Data? {
        let pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: Int(THREEMA_KDF_HASH_LENGTH))
        
        defer {
            pOut.deallocate()
        }
        
        if blake2b_hash(Array(input), input.count, pOut) != 0 {
            return nil
        }
        
        return Data(UnsafeMutableBufferPointer(start: pOut, count: Int(THREEMA_KDF_HASH_LENGTH)))
    }
    
    static func blake2bSelfTest() -> Int32 {
        blake2b_self_test()
    }
}
