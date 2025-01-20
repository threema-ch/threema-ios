//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaBlake2b

@available(*, deprecated, message: "In Swift use ThreemaBlake2b instead", renamed: "ThreemaBlake2b")
@objc class ThreemaKDF: NSObject {
    static let THREEMA_KDF_KEYBYTES = 32
    
    private let personal: Data
    
    @objc init(personal: String) {
        self.personal = Data(personal.utf8)
    }
    
    @available(*, deprecated, renamed: "ThreemaBlake2b(personal:)")
    init(personal: Data) {
        self.personal = personal
    }
    
    /// Derives a key from a key and a salt with BLAKE2b.
    ///
    /// - Parameter salt: Salt for key derivation
    /// - Parameter key: Key of 32..64 bytes length to derive new key from
    ///
    /// - Returns: Derived key of 32 bytes length
    @available(*, deprecated, renamed: "driveKey(from:with:)")
    public func deriveKey(salt: Data, key: Data) -> Data? {
        guard key.count >= 32, key.count <= 64 else {
            return nil
        }
        
        return try? ThreemaBlake2b.deriveKey(from: key, with: salt, personal: personal, derivedKeyLength: .b32)
    }
    
    @objc public func deriveKey(salt: String, key: Data) -> Data? {
        deriveKey(salt: Data(salt.utf8), key: key)
    }
    
    /// Calculates a keyed MAC using BLAKE2b.
    ///
    /// - Parameter key: Key of 32 bytes length
    /// - Parameter input: Input data of arbitrary length
    ///
    /// - Returns: MAC of 32 bytes length
    @available(
        *,
        deprecated,
        message: "In Swift use ThreemaBlake2b instead",
        renamed: "ThreemaBlake2b.mac(for:with:macLength:)"
    )
    @objc public static func calculateMac(key: Data, input: Data) -> Data? {
        try? ThreemaBlake2b.hash(input, key: key, hashLength: .b32)
    }
    
    /// Calculates a simple hash with variable output length using BLAKE2b.
    ///
    /// - Parameter input: Input data of arbitrary length
    /// - Parameter outputLen: Desired output length (32 or 64 bytes)
    ///
    /// - Returns: hash of desired length
    @available(*, deprecated, renamed: "ThreemaBlake2b.hash(_:hashLength:)")
    static func hash(input: Data, outputLen: ThreemaBlake2b.DigestLength) -> Data? {
        try? ThreemaBlake2b.hash(input, hashLength: outputLen)
    }
}
