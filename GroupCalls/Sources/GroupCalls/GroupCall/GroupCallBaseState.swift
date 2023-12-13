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
@preconcurrency import WebRTC

protocol GroupCallMessageCryptoProtocol: Sendable {
    var symmetricNonceLength: Int32 { get }
    
    func symmetricDecryptByGCHK(_ cipherText: Data, nonce: Data) -> Data?
    func symmetricEncryptByGCHK(_ plainText: Data, nonce: Data) -> Data?
    
    func symmetricDecryptByGCNHAK(sharedSecret: Data, cipherText: Data, nonce: Data) throws -> Data?
    func symmetricEncryptByGCNHAK(sharedSecret: Data, plainText: Data, nonce: Data) throws -> Data?
}

protocol GroupCallFrameCryptoAdapterProtocol: Sendable {
    func attachEncryptor(to transceiver: RTCRtpTransceiver, myParticipantID: ParticipantID) throws
    func applyMediaKeys(from localParticipant: LocalParticipant) async throws
}

/// Contains the base state for the group call
/// Contains all keys that won't change over the lifetime of the group call
struct GroupCallBaseState {
    let group: GroupCallsThreemaGroupModel
    let callID: GroupCallID
    let startedAt: Date
    let maxParticipants: Int
    
    let sfuBaseURL: String
    let protocolVersion: UInt32
    
    private let keys: GroupCallKeys
    private let dependencies: Dependencies
    private let groupCallStartData: GroupCallStartData
    
    private let frameCryptoContext: ThreemaGroupCallFrameCryptoContextProtocol
    private let frameCryptoContextLock = NSLock()
    
    init(
        group: GroupCallsThreemaGroupModel,
        startedAt: Date,
        maxParticipants: Int,
        dependencies: Dependencies,
        groupCallStartData: GroupCallStartData
    ) throws {
        self.group = group
        
        self.startedAt = startedAt
        self.maxParticipants = maxParticipants
        self.dependencies = dependencies
        self.groupCallStartData = groupCallStartData
        
        self.sfuBaseURL = groupCallStartData.sfuBaseURL
        self.protocolVersion = groupCallStartData.protocolVersion
        
        self.callID = try GroupCallID(
            groupIdentity: group.groupIdentity,
            callStartData: groupCallStartData,
            dependencies: dependencies
        )
        
        self.keys = try GroupCallKeys(gck: groupCallStartData.gck)
        
        self.frameCryptoContext = ThreemaGroupCallFrameCryptoContext(gckh: keys.gckh)
    }
}

// MARK: - GroupCallFrameCryptoAdapterProtocol

extension GroupCallBaseState: GroupCallFrameCryptoAdapterProtocol {
    func attachEncryptor(to transceiver: RTCRtpTransceiver, myParticipantID: ParticipantID) throws {
        frameCryptoContextLock.withLock {
            let logMediaKind = transceiver.mediaType == .audio ? "opus" : "vp8"
            let logTag = "\(myParticipantID.id).\(transceiver.mid).\(logMediaKind).sender"
            self.frameCryptoContext.getEncryptor()
                .attach(transceiver.sender, mediaType: transceiver.mediaType, tag: logTag)
        }
    }
    
    @GlobalGroupCallActor
    func applyMediaKeys(from localParticipant: LocalParticipant) throws {
        try frameCryptoContextLock.withLock {
            try localParticipant.applyMediaKeys(to: self.frameCryptoContext.getEncryptor())
        }
    }
    
    @GlobalGroupCallActor
    func apply(mediaKeys: MediaKeys, for participantID: ParticipantID) throws {
        try frameCryptoContextLock.withLock {
            guard participantID.id < UInt16.max else {
                throw GroupCallError.localProtocolViolation
            }
            
            let uint16RemoteParticipantID = UInt16(participantID.id)
            
            guard let decryptor = frameCryptoContext.getDecryptorFor(uint16RemoteParticipantID) else {
                throw GroupCallError.frameCryptoFailure
            }
            
            try mediaKeys.applyMediaKeys(to: decryptor)
        }
    }
    
    @GlobalGroupCallActor
    func addDecryptor(to participant: RemoteParticipant) async throws {
        try frameCryptoContextLock.withLock {
            guard participant.participantID.id < UInt16.max else {
                throw GroupCallError.localProtocolViolation
            }
            
            let uint16RemoteParticipantID = UInt16(participant.participantID.id)
            
            let decryptor = frameCryptoContext.addDecryptor(for: uint16RemoteParticipantID)
            try participant.addUsingGroupCallActor(decryptor: decryptor)
        }
    }
    
    @GlobalGroupCallActor
    func removeDecryptor(for participant: ParticipantID) throws {
        try frameCryptoContextLock.withLock {
            guard participant.id < UInt16.max else {
                throw GroupCallError.localProtocolViolation
            }
            
            let uInt16ParticipantID = UInt16(participant.id)
            
            frameCryptoContext.removeDecryptor(for: uInt16ParticipantID)
        }
    }
    
    func disposeFrameCryptoContext() {
        frameCryptoContextLock.withLock {
            frameCryptoContext.dispose()
        }
    }
}

// MARK: - GroupCallMessageCryptoProtocol

extension GroupCallBaseState: GroupCallMessageCryptoProtocol {
    var symmetricNonceLength: Int32 {
        dependencies.groupCallCrypto.symmetricNonceLength
    }
    
    func symmetricDecryptByGCHK(_ cipherText: Data, nonce: Data) -> Data? {
        dependencies.groupCallCrypto.symmetricDecryptData(
            cipherText,
            withSecretKey: keys.gchk,
            nonce: nonce
        )
    }
    
    func symmetricEncryptByGCHK(_ plainText: Data, nonce: Data) -> Data? {
        symmetricEncrypt(by: keys.gchk, plainText: plainText, nonce: nonce)
    }
    
    func symmetricDecryptByGSCK(_ cipherText: Data, nonce: Data) -> Data? {
        dependencies.groupCallCrypto.symmetricDecryptData(
            cipherText,
            withSecretKey: keys.gcsk,
            nonce: nonce
        )
    }
    
    func symmetricEncryptByGSCK(_ plainText: Data, nonce: Data) -> Data? {
        symmetricEncrypt(by: keys.gcsk, plainText: plainText, nonce: nonce)
    }
    
    fileprivate func symmetricEncrypt(by key: Data, plainText: Data, nonce: Data) -> Data? {
        dependencies.groupCallCrypto.symmetricEncryptData(
            plainText,
            withKey: key,
            nonce: nonce
        )
    }
    
    fileprivate func symmetricDecrypt(by key: Data, cipherText: Data, nonce: Data) -> Data? {
        dependencies.groupCallCrypto.symmetricDecryptData(
            cipherText,
            withSecretKey: key,
            nonce: nonce
        )
    }
    
    func symmetricEncryptByGCNHAK(sharedSecret: Data, plainText: Data, nonce: Data) throws -> Data? {
        do {
            let gcnhak = try keys.deriveGCNHAK(from: sharedSecret)
            return symmetricEncrypt(by: gcnhak, plainText: plainText, nonce: nonce)
        }
        catch {
            let msg = "Could not encrypt cipher text because of an error \(error)"
            DDLogError(msg)
            assertionFailure(msg)
            
            throw GroupCallError.encryptionFailure
        }
    }
    
    func symmetricDecryptByGCNHAK(sharedSecret: Data, cipherText: Data, nonce: Data) throws -> Data? {
        do {
            let gcnhak = try keys.deriveGCNHAK(from: sharedSecret)
            return symmetricDecrypt(by: gcnhak, cipherText: cipherText, nonce: nonce)
        }
        catch {
            let msg = "Could not decrypt cipher text because of an error \(error)"
            DDLogError(msg)
            assertionFailure(msg)
            
            throw GroupCallError.encryptionFailure
        }
    }
}

// MARK: - Equatable

extension GroupCallBaseState: Equatable {
    static func == (lhs: GroupCallBaseState, rhs: GroupCallBaseState) -> Bool {
        lhs.group == rhs.group &&
            lhs.callID == rhs.callID &&
            lhs.startedAt == rhs.startedAt &&
            lhs.maxParticipants == rhs.maxParticipants
    }
}
