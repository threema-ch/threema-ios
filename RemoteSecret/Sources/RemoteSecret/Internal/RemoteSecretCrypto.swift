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

import CocoaLumberjackSwift
import Foundation
import libthreemaSwift
import RemoteSecretProtocol
import ThreemaEssentials

final class RemoteSecretCrypto: RemoteSecretCryptoProtocol {
    let isRemoteSecretEnabled = true
    
    static let nonceLength = 24
    static let tagLength = 16
    
    private static let chunkSize = 1024
    // TODO: (IOS-5542) If the app isn't crashed when RS is blocked this needs to be reseted as no more en- and decryption should be possible. For now the app just crashes as soon as the monitor observes a blocking (or any other) error
    private let wonkyFieldCipher: (any WonkyFieldCipherProtocol)?
    
    let coder: any SendableRemoteSecretCodable
    
    init(
        remoteSecret: RemoteSecret,
        coder: any SendableRemoteSecretCodable = RemoteSecretCoder(logErrorMessage: {
            DDLogError("\($0)")
            DDLog.sharedInstance.flushLog()
        })
    ) throws {
        // We should never keep remote secret in memory. Thus we directly create the wonky field cipher
        try self.wonkyFieldCipher = WonkyFieldCipher(remoteSecret: remoteSecret.rawValue)
        self.coder = coder
    }
    
    // MARK: - Encryption / Decryption
    
    // MARK: Data

    func encrypt(_ data: Data) -> Data {
        
        // Must never be called when remote secret is blocked
        guard let wonkyFieldCipher else {
            let message = "[RemoteSecret] `encrypt` must not be called when remote secret is blocked"
            DDLogError("\(message)")
            fatalError(message)
        }
        
        /// The flow to encrypt a database field is as follows:
        ///
        /// 1. Call this function and let `nonce` and `encryptor` as defined in the resulting
        /// `WonkyFieldEncryptorContext`
        let encryptor = wonkyFieldCipher.encryptor()
        let nonce = encryptor.nonce
        
        /// 2. Let `data` be the database field serialized to bytes.
        
        /// 3. Let `encryptedData` be the chunk-wise encryption of `data` using the `encryptor`'s
        /// `ChunkedXChaCha20Poly1305Encryptor.encrypt()` method.
        var encryptedData = Data(capacity: data.count + RemoteSecretCrypto.nonceLength + RemoteSecretCrypto.tagLength)
        var offset = 0
        
        while offset < data.count {
            let endIndex = min(offset + RemoteSecretCrypto.chunkSize, data.count)
            let range = data.index(data.startIndex, offsetBy: offset)..<data.index(data.startIndex, offsetBy: endIndex)
            let chunk = data[range]
            
            do {
                try encryptedData.append(encryptor.encryptor.encrypt(chunk: chunk))
            }
            catch {
                let message = "[RemoteSecret] Chunk-wise encryption failed: \(error)"
                DDLogError("\(message)")
                fatalError(message)
            }
            offset += RemoteSecretCrypto.chunkSize
        }
        
        do {
            /// 4. Let `tag` be the result of calling the `encryptor`'s `ChunkedXChaCha20Poly1305Encryptor.finalize()`
            /// method.
            let tag = try encryptor.encryptor.finalize()
            
            /// 5. Compose the encrypted database field by concatenating `nonce`, `encryptedData`, and `tag`,
            /// i.e.,`encryptedDatabaseField = nonce || encrypted_data || tag`.
            concatenate(nonce: nonce, data: &encryptedData, tag: tag)
        }
        catch {
            let message = "[RemoteSecret] Finalizing encryption failed: \(error)"
            DDLogError("\(message)")
            fatalError(message)
        }
        
        return encryptedData
    }
    
    func decrypt(_ encryptedData: Data) -> Data {
        
        // Must never be called when remote secret is blocked
        guard let wonkyFieldCipher else {
            let message = "[RemoteSecret] `encrypt` must not be called when remote secret is blocked"
            DDLogError("\(message)")
            fatalError(message)
        }
        
        /// The flow to decrypt an encrypted database field is as follows:
        ///
        /// 1. Parse the encrypted database field (stored as bytes) into `nonce || encryptedData || tag` where`nonce` is
        /// 24 bytes long, and `tag` is 16 bytes long.
        let (nonce, tag) = split(data: encryptedData)

        /// 2. Let `decryptor` be the result of calling this function with `nonce` as argument.
        let decryptor: ChunkedXChaCha20Poly1305Decryptor
        do {
            decryptor = try wonkyFieldCipher.decryptor(nonce: nonce)
        }
        catch {
            let message = "[RemoteSecret] Creating decryptor failed: \(error)"
            DDLogError("\(message)")
            fatalError(message)
        }
        
        /// 3. Let `data` be the chunk-wise decryption of `encryptedData` using the `decryptor`'s
        /// `ChunkedXChaCha20Poly1305Decryptor.decrypt()` method.
        var offset = 0

        let decryptedDataCount = encryptedData.count - RemoteSecretCrypto.nonceLength - RemoteSecretCrypto.tagLength
        var decryptedData = Data(capacity: decryptedDataCount)
        
        while offset < decryptedDataCount {
            let endIndex = min(offset + RemoteSecretCrypto.chunkSize, decryptedDataCount)

            let range = encryptedData.index(
                encryptedData.startIndex + RemoteSecretCrypto.nonceLength,
                offsetBy: offset
            )..<encryptedData.index(encryptedData.startIndex + RemoteSecretCrypto.nonceLength, offsetBy: endIndex)
            let chunk = encryptedData[range]

            do {
                try decryptedData.append(decryptor.decrypt(chunk: chunk))
            }
            catch {
                let message = "[RemoteSecret] Chunk-wise decryption failed: \(error)"
                DDLogError("\(message)")
                fatalError(message)
            }
            
            offset += RemoteSecretCrypto.chunkSize
        }
        
        /// 4. Verify the `tag` by calling the `decryptor`'s `ChunkedXChaCha20Poly1305Decryptor.finalizeVerify()`
        /// method. Abort if this fails.
        do {
            try decryptor.finalizeVerify(expectedTag: tag)
        }
        catch {
            let message = "[RemoteSecret] Finalizing decryption failed: \(error)"
            DDLogError("\(message)")
            fatalError(message)
        }
        
        /// 5. Deserialize `data` into the data type of the corresponding database field.
        /// This is done at the call site of this function.
        
        return decryptedData
    }

    // MARK: String
    
    func encrypt(_ string: String) -> Data {
        let data = coder.encode(string)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> String {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Int16
    
    func encrypt(_ int: Int16) -> Data {
        let data = coder.encode(int)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Int16 {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Int32
    
    func encrypt(_ int: Int32) -> Data {
        let data = coder.encode(int)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Int32 {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Int64
    
    func encrypt(_ int: Int64) -> Data {
        let data = coder.encode(int)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Int64 {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Double
    
    func encrypt(_ double: Double) -> Data {
        let data = coder.encode(double)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Double {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Float
    
    func encrypt(_ float: Float) -> Data {
        let data = coder.encode(float)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Float {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Date
    
    func encrypt(_ date: Date) -> Data {
        let data = coder.encode(date)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Date {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: Bool
    
    func encrypt(_ bool: Bool) -> Data {
        let data = coder.encode(bool)
        return encrypt(data)
    }
    
    func decrypt(_ data: Data) -> Bool {
        let decryptedData: Data = decrypt(data)
        return coder.decode(decryptedData)
    }
    
    // MARK: - Helpers
    
    func concatenate(nonce: Data, data: inout Data, tag: Data) {
        data.insert(contentsOf: nonce, at: 0)
        data.append(tag)
    }
    
    func split(data: Data) -> (nonce: Data, tag: Data) {
        let tag = data[data.count - RemoteSecretCrypto.tagLength..<data.count]
        let nonce = data[0..<RemoteSecretCrypto.nonceLength]
        return (nonce, tag)
    }
}
