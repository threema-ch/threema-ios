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
@testable import GroupCalls

final class MockGroupCallCrypto: GroupCallCryptoProtocol {
    var symmetricNonceLength: Int32 {
        24
    }
    
    func symmetricEncryptData(_ plaintext: Data, withKey key: Data, nonce: Data) -> Data? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        var returnData = nonce
        returnData.append(key)
        returnData.append(plaintext)
        
        print("Ciphertext \(returnData.count) \(returnData.hexEncodedString())")
        return returnData
    }
    
    func symmetricDecryptData(_ ciphertext: Data, withSecretKey key: Data, nonce: Data) -> Data? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        print("Ciphertext \(ciphertext.count) \(ciphertext.hexEncodedString())")
        
        return ciphertext.advanced(by: nonce.count).advanced(by: key.count)
    }
    
    func randomBytes(of length: Int32) -> Data {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
      
        return Data(repeating: 0x01, count: 32)
    }
    
    func generateKeyPair() -> (publicKey: Data, privateKey: Data)? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        return (Data(), Data())
    }
    
    func encryptData(plaintext: Data, withPublicKey: Data, secretKey: Data, nonce: Data) -> Data? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        var returnData = nonce
        returnData.append(secretKey)
        returnData.append(withPublicKey)
        returnData.append(plaintext)
        
        return returnData
    }
    
    func decryptData(cipherText: Data, withKey: Data, signKey: Data, nonce: Data) -> Data? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        return cipherText.advanced(by: nonce.count).advanced(by: signKey.count).advanced(by: withKey.count)
    }
    
    func sharedSecret(forPublicKey: Data, secretKey: Data) -> Data {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        return Data()
    }
    
    func sharedSecret(with identity: String) -> Data? {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        var sharedSecret = identity.hexadecimal!
        
        sharedSecret.append(Data(repeating: 0x01, count: 32 - sharedSecret.count))
        
        return sharedSecret
    }
    
    func padding() -> Data {
        #if !DEBUG
            // This may only
            fatalError()
        #endif
        
        return Data()
    }
}
