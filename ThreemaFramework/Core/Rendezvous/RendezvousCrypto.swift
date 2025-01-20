//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

/// Cryptographic functions for Rendezvous protocol
protocol RendezvousCrypto: AnyObject {
    /// Encrypt the data
    /// - Parameter data: Data to encrypt
    /// - Returns: Encrypted data
    func encrypt(_ data: Data) throws -> Data
    
    /// Decrypt the data
    /// - Parameter data: Data to decrypt
    /// - Returns: Decrypted data
    func decrypt(_ data: Data) throws -> Data
    
    /// Switch to transport keys
    ///
    /// This should only be called once.
    ///
    /// - Parameters:
    ///   - localEphemeralTransportKeyPair: Local ephemeral transport key
    ///   - remotePublicEphemeralTransportKey: Remote public ephemeral transport key
    /// - Returns: Rendezvous path hash
    func switchToTransportKeys(
        localEphemeralTransportKeyPair: NaClCrypto.KeyPair,
        remotePublicEphemeralTransportKey: Data
    ) throws -> Data
}

enum RendezvousCryptoError: Swift.Error {
    case transportKeysAlreadyUsed
    case noAuthenticationKey
    case unableToDeriveKeys
}
