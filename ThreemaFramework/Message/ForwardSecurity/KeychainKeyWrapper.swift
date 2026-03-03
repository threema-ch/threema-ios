//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import Keychain

/// Encrypt Forward Security keys with a keychain key that cannot be restored on a different device.
@objc class KeychainKeyWrapper: NSObject, KeyWrapperProtocol {
    public static let unwrappedKeyLength = 32
    
    private var cachedWrappingKey: Data?
    
    func wrap(key: Data?) throws -> Data? {
        guard let key else {
            return nil
        }
        
        if key.isEmpty {
            return key
        }
        else if key.count != KeychainKeyWrapper.unwrappedKeyLength {
            throw KeyWrappingError.badKeyLength
        }
        
        let nonce = NaClCrypto.shared().randomBytes(kNaClCryptoSymmNonceSize)!
        guard let wrappedKey = try NaClCrypto.shared()
            .symmetricEncryptData(key, withKey: obtainWrappingKey(), nonce: nonce) else {
            throw KeyWrappingError.encryptionFailed
        }
        
        return nonce + wrappedKey
    }
    
    func unwrap(key: Data?) throws -> Data? {
        guard let key else {
            return nil
        }
        
        if key.isEmpty || key.count == KeychainKeyWrapper.unwrappedKeyLength {
            // Not wrapped
            return key
        }
        else if key
            .count != (Int(kNaClCryptoSymmNonceSize) + Int(kNaClBoxOverhead) + KeychainKeyWrapper.unwrappedKeyLength) {
            throw KeyWrappingError.badWrappedKeyLength
        }
        
        let nonce = key[0..<kNaClCryptoSymmNonceSize]
        let wrappedKey = key[kNaClCryptoSymmNonceSize...]
        guard let unwrappedKey = try NaClCrypto.shared()
            .symmetricDecryptData(wrappedKey, withKey: obtainWrappingKey(), nonce: nonce) else {
            throw KeyWrappingError.decryptionFailed
        }
        
        return unwrappedKey
    }
    
    private func obtainWrappingKey() throws -> Data {
        if let wrappingKey = cachedWrappingKey {
            return wrappingKey
        }

        let keychainManager = KeychainManager(remoteSecretManager: AppLaunchManager.remoteSecretManager)

        // Check if we already have a wrapping key in the keychain
        if let wrappingKey = try keychainManager.loadForwardSecurityWrappingKey() {
            guard wrappingKey.count == kNaClCryptoSymmKeySize else {
                DDLogError("Bad Keychain item data")
                deleteWrappingKey()
                throw KeyWrappingError.keychainError
            }

            cachedWrappingKey = wrappingKey
            return wrappingKey
        }

        // Generate new wrapping key
        let newWrappingKey = NaClCrypto.shared().randomBytes(kNaClCryptoSymmKeySize)!
        try keychainManager.storeForwardSecurityWrappingKey(newWrappingKey)

        DDLogDebug("Generated new wrapping key")
        cachedWrappingKey = newWrappingKey
        return newWrappingKey
    }
    
    @objc func deleteWrappingKey() {
        let keychainManager = KeychainManager(remoteSecretManager: AppLaunchManager.remoteSecretManager)

        do {
            try keychainManager.deleteForwardSecurityKey()
        }
        catch {
            DDLogError("Couldn't delete wrapping key in Keychain: \(error)")
        }
    }
}
