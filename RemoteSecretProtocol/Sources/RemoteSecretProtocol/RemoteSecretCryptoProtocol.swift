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

public protocol RemoteSecretCryptoProtocol: Sendable {

    // MARK: Data
    
    /// Encrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be encrypted
    /// - Note: Preferably, this function would use an `inout` parameter for data, so we could modify in place.
    /// Sadly this approach was discarded due to time performance issues.
    /// - Returns: Encrypted `Data`
    func encrypt(_ data: Data) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Note: Preferably, this function would use an `inout` parameter for data, so we could modify in place.
    /// Sadly this approach was discarded due to time performance issues.
    /// - Returns: Decrypted `Data`
    func decrypt(_ data: Data) -> Data
    
    // MARK: String
    
    ///  Encrypts non-optional `String` for remote secret using libthreema
    /// - Parameter string: `String` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ string: String) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `String`
    func decrypt(_ data: Data) -> String

    // MARK: Int16
    
    ///  Encrypts non-optional `Int16` for remote secret using libthreema
    /// - Parameter int: `Int16` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ int: Int16) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Int16`
    func decrypt(_ data: Data) -> Int16
    
    // MARK: Int32
    
    ///  Encrypts non-optional `Int32` for remote secret using libthreema
    /// - Parameter int: `Int32` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ int: Int32) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Int32`
    func decrypt(_ data: Data) -> Int32
    
    // MARK: Int64
    
    ///  Encrypts non-optional `Int64` for remote secret using libthreema
    /// - Parameter int: `Int64` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ int: Int64) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Int64`
    func decrypt(_ data: Data) -> Int64
    
    // MARK: Double
    
    ///  Encrypts non-optional `Double` for remote secret using libthreema
    /// - Parameter double: `Double` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ double: Double) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Double`
    func decrypt(_ data: Data) -> Double
    
    // MARK: Float
    
    ///  Encrypts non-optional `Float` for remote secret using libthreema
    /// - Parameter float: `Float` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ float: Float) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Float`
    func decrypt(_ data: Data) -> Float
    
    // MARK: Date
    
    ///  Encrypts non-optional `Date` for remote secret using libthreema
    /// - Parameter date: `Date` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ date: Date) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Date`
    func decrypt(_ data: Data) -> Date
    
    // MARK: Bool
    
    ///  Encrypts non-optional `Bool` for remote secret using libthreema
    /// - Parameter bool: `Bool` to be encrypted
    /// - Returns: Encrypted `Data`
    func encrypt(_ bool: Bool) -> Data
    
    /// Decrypts non-optional `Data` for remote secret using libthreema
    /// - Parameter data: `Data` to be decrypted
    /// - Returns: Decrypted `Bool`
    func decrypt(_ data: Data) -> Bool
}
