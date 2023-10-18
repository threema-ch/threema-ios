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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaProtocols
import WebRTC

/// Adapter for NaClCrypto from ThreemaFramework
struct GroupCallCrypto: GroupCallCryptoProtocol, Sendable {

    // MARK: - Symmetric Encryption & Decryption
    
    var symmetricNonceLength: Int32 {
        kNaClCryptoNonceSize
    }
    
    func symmetricEncryptData(_ plaintext: Data, withKey key: Data, nonce: Data) -> Data? {
        NaClCrypto.shared().symmetricEncryptData(plaintext, withKey: key, nonce: nonce)
    }
    
    func symmetricDecryptData(_ ciphertext: Data, withSecretKey key: Data, nonce: Data) -> Data? {
        NaClCrypto.shared().symmetricDecryptData(ciphertext, withKey: key, nonce: nonce)
    }
    
    // MARK: - Public Key Encryption & Decryption
    
    func encryptData(plaintext: Data, withPublicKey: Data, secretKey: Data, nonce: Data) -> Data? {
        Data(NaClCrypto.shared().encryptData(plaintext, withPublicKey: withPublicKey, signKey: secretKey, nonce: nonce))
    }
    
    func decryptData(cipherText: Data, withKey: Data, signKey: Data, nonce: Data) -> Data? {
        NaClCrypto.shared().decryptData(cipherText, withSecretKey: withKey, signKey: signKey, nonce: nonce)
    }
    
    // MARK: - Shared Secrets
    
    func sharedSecret(forPublicKey: Data, secretKey: Data) -> Data {
        Data(NaClCrypto.shared().sharedSecret(forPublicKey: forPublicKey, secretKey: secretKey))
    }
    
    /// Returns the shared secret with the given Threema ID
    /// - Parameter identity: A valid Threema ID which is already present in the database
    /// - Returns: The shared secret or nil if it cannot be calculated
    /// crashes if the contact or public key cannot be found
    func sharedSecret(with identity: String) -> Data? {
        let businessInjector = BusinessInjector()
        guard let contact = businessInjector.entityManager.entityFetcher.contact(for: identity) else {
            DDLogError("[GroupCall] Contact not found with id: \(identity)")
            return nil
        }
        
        var publicKey: Data?
        
        businessInjector.entityManager.performBlockAndWait {
            publicKey = contact.publicKey
        }
        
        guard let publicKey else {
            DDLogError("[GroupCall] Public Key not found for contact with id: \(identity)")
            return nil
        }
        
        return businessInjector.myIdentityStore.sharedSecret(withPublicKey: publicKey)
    }
    
    // MARK: - Cryptographic Random Data and Padding
    
    func padding() -> Data {
        BytesUtility.paddingRandom()
    }
    
    func randomBytes(of length: Int32) -> Data {
        NaClCrypto.shared().randomBytes(length)
    }
    
    // MARK: - Key Generation
    
    func generateKeyPair() -> (publicKey: Data, privateKey: Data)? {
        do {
            let keyPair = try NaClCrypto.shared().generateNewKeyPair()
            
            return (keyPair.publicKey, keyPair.privateKey)
        }
        catch {
            DDLogError("Unable to generate key pair: \(error)")
            return nil
        }
    }
}
