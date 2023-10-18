//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

/// Various functions related to cryptography
public protocol GroupCallCryptoProtocol: Sendable {
    var symmetricNonceLength: Int32 { get }
    
    func symmetricEncryptData(_ plaintext: Data, withKey key: Data, nonce: Data) -> Data?
    func symmetricDecryptData(_ ciphertext: Data, withSecretKey key: Data, nonce: Data) -> Data?
    
    func randomBytes(of length: Int32) -> Data
    
    func generateKeyPair() -> (publicKey: Data, privateKey: Data)?
    func encryptData(plaintext: Data, withPublicKey: Data, secretKey: Data, nonce: Data) -> Data?
    func decryptData(cipherText: Data, withKey: Data, signKey: Data, nonce: Data) -> Data?
    
    func sharedSecret(forPublicKey: Data, secretKey: Data) -> Data
    
    /// Returns the shared secret with a given Threema ID
    /// - Parameter identity: The Threema ID of the contact for which we want to calculate the shared secret with.
    /// The contact for this Threema ID must already be present in the database.
    /// - Returns: Shared Secret with the Threema ID passed into `identity`.
    /// Nil if the contact for this identity does not exist or something went wrong
    func sharedSecret(with identity: String) -> Data?
    
    func padding() -> Data
}
