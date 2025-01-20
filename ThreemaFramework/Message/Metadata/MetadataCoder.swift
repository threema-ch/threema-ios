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
import ThreemaProtocols

enum MetadataCoderError: Error {
    case missingPrivateKey
}

@objc public class MetadataCoder: NSObject {
    private let myIdentityStore: MyIdentityStoreProtocol
    
    init(_ myIdentityStore: MyIdentityStoreProtocol) {
        self.myIdentityStore = myIdentityStore
    }
    
    @objc override public convenience init() {
        self.init(MyIdentityStore.shared())
    }
    
    @objc public func encode(metadata: MessageMetadata, nonce: Data, publicKey: Data) -> Data? {
        var pbMetadata = CspE2e_MessageMetadata()
        
        if let nickname = metadata.nickname {
            pbMetadata.padding = Data(count: max(0, 16 - Data(nickname.utf8).count))
            pbMetadata.nickname = nickname
        }
        if let messageID = metadata.messageID {
            pbMetadata.messageID = messageID.paddedLittleEndian()
        }
        if let createdAt = metadata.createdAt {
            pbMetadata.createdAt = UInt64(createdAt.timeIntervalSince1970 * 1000)
        }
        do {
            let protobuf = try pbMetadata.serializedData()
            return try NaClCrypto.shared()
                .symmetricEncryptData(protobuf, withKey: deriveMetadataKey(publicKey: publicKey), nonce: nonce)
        }
        catch {
            return nil
        }
    }
    
    @objc public func decode(nonce: Data, box: Data, publicKey: Data) throws -> MessageMetadata {
        let protobuf = try NaClCrypto.shared()
            .symmetricDecryptData(box, withKey: deriveMetadataKey(publicKey: publicKey), nonce: nonce)
        let pbMetadata = try CspE2e_MessageMetadata(serializedData: protobuf!)
        
        var nickname: String?
        var messageID: Data?
        var createdAt: Date?
        if !pbMetadata.nickname.isEmpty {
            nickname = pbMetadata.nickname
        }
        if pbMetadata.messageID != 0 {
            messageID = pbMetadata.messageID.littleEndianData
        }
        if pbMetadata.createdAt != 0 {
            createdAt = Date(timeIntervalSince1970: Double(pbMetadata.createdAt) / 1000)
        }
        
        return MessageMetadata(nickname: nickname, messageID: messageID, createdAt: createdAt)
    }
    
    private func deriveMetadataKey(publicKey: Data) throws -> Data {
        guard let sharedSecret = myIdentityStore.sharedSecret(withPublicKey: publicKey) else {
            throw MetadataCoderError.missingPrivateKey
        }
        
        let kdf = ThreemaKDF(personal: "3ma-csp")
        return kdf.deriveKey(salt: "mm", key: sharedSecret)!
    }
}
