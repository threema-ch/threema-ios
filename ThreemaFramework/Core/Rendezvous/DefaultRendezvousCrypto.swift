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

import CocoaLumberjackSwift
import CryptoKit
import Foundation
import ThreemaBlake2b

/// Default implementation of the Connection Rendezvous Protocol cryptography according to the Threema protocol
/// specification
final class DefaultRendezvousCrypto: RendezvousCrypto {
    
    private enum KeysState {
        /// Initial state
        case authentication
        /// State after successful handshake
        case transport
    }
    
    // MARK: - Internal state
    
    // This can only once switch to `.transport`
    private var keyState: KeysState = .authentication {
        didSet {
            assert(oldValue == .authentication && keyState == .transport)
        }
    }
    
    // This should be non-nil if key state is `authentication`
    private var authenticationKey: Data?

    private var initiatorKey: SymmetricKey
    private var responderKey: SymmetricKey
    
    private var initiatorSequenceNumber: UInt32 = 1
    private var responderSequenceNumber: UInt32 = 1
    
    private let role: Rendezvous.Role
    private let pathID: UInt32
    
    private let threemaBlake2b: ThreemaBlake2b
    
    /// Create a new instance with the keys in authentication state
    /// - Parameters:
    ///   - role: Role of this client
    ///   - authenticationKey: Authentication key used to derive initial keys
    ///   - pathID: Path ID
    /// - Throws: `ThreemaBlake2b.Error`
    init(role: Rendezvous.Role, authenticationKey: Data, pathID: UInt32) throws {
        self.role = role
        self.authenticationKey = authenticationKey
        self.pathID = pathID
        
        let localThreemaBlake2b = try ThreemaBlake2b(personal: "3ma-rendezvous")
        self.threemaBlake2b = localThreemaBlake2b
        
        // RIDAK = BLAKE2b(key=AK.secret, salt='rida', personal='3ma-rendezvous')
        // RRDAK = BLAKE2b(key=AK.secret, salt='rrda', personal='3ma-rendezvous')
        let ridak = try threemaBlake2b.deriveKey(from: authenticationKey, with: "rida", derivedKeyLength: .b32)
        let rrdak = try threemaBlake2b.deriveKey(from: authenticationKey, with: "rrda", derivedKeyLength: .b32)
        
        self.initiatorKey = SymmetricKey(data: ridak)
        self.responderKey = SymmetricKey(data: rrdak)
    }
    
    // MARK: - En- and decryption
    
    // RID's encryption scheme is defined in the following way:
    //
    //    ChaCha20-Poly1305(
    //        key=<RID*K.secret>,
    //        nonce=u32-le(PID) || u32-le(RIDSN+) || <4 zero bytes>,
    //    )
    //
    // RRD's encryption scheme is defined in the following way:
    //
    //    ChaCha20-Poly1305(
    //        key=<RRD*K.secret>,
    //        nonce=u32-le(PID) || u32-le(RRDSN+) || <4 zero bytes>,
    //    )
    
    func encrypt(_ data: Data) throws -> Data {
        let key: SymmetricKey
        let sequenceNumber: UInt32
        // This needs to be called before every return (but not throw) of this function
        let updateSequenceNumber: () -> Void

        switch role {
        case .initiator:
            key = initiatorKey
            
            sequenceNumber = initiatorSequenceNumber
            updateSequenceNumber = {
                self.initiatorSequenceNumber += 1
            }
        case .responder:
            key = responderKey

            sequenceNumber = responderSequenceNumber
            updateSequenceNumber = {
                self.responderSequenceNumber += 1
            }
        }
        
        let nonceData = nonce(with: sequenceNumber)
        
        let nonce = try ChaChaPoly.Nonce(data: nonceData)
        let sealedBox = try ChaChaPoly.seal(data, using: key, nonce: nonce)
        
        // `sealedBox.combined` also contains the nonce which we don't send
        var outData = Data(sealedBox.ciphertext)
        outData.append(sealedBox.tag)
        
        updateSequenceNumber()
        
        return outData
    }
    
    func decrypt(_ data: Data) throws -> Data {
        let key: SymmetricKey
        let sequenceNumber: UInt32
        // This needs to be called before every return (but not throw) of this function
        let updateSequenceNumber: () -> Void

        switch role {
        case .initiator:
            key = responderKey
            
            sequenceNumber = responderSequenceNumber
            updateSequenceNumber = {
                self.responderSequenceNumber += 1
            }
        case .responder:
            key = initiatorKey
            
            sequenceNumber = initiatorSequenceNumber
            updateSequenceNumber = {
                self.initiatorSequenceNumber += 1
            }
        }
        
        // The combined data expected by `ChaChaPoly` also has the nonce prepended
        var combinedData = nonce(with: sequenceNumber)
        combinedData.append(data)
        
        let sealedBox = try ChaChaPoly.SealedBox(combined: combinedData)
        let outData = try ChaChaPoly.open(sealedBox, using: key)
        
        updateSequenceNumber()
        
        return Data(outData)
    }
    
    // MARK: Helper
    
    private func nonce(with sequenceNumber: UInt32) -> Data {
        // nonce=u32-le(PID) || u32-le(RIDSN+) || <4 zero bytes>
        var nonceData = pathID.littleEndianData
        nonceData.append(sequenceNumber.littleEndianData)
        nonceData.append(Data(repeating: 0x0, count: 4))
        
        return nonceData
    }
    
    // MARK: - Switch keys
    
    func switchToTransportKeys(
        localEphemeralTransportKeyPair: NaClCrypto.KeyPair,
        remotePublicEphemeralTransportKey: Data
    ) throws -> Data {
        guard keyState == .authentication else {
            throw RendezvousCryptoError.transportKeysAlreadyUsed
        }
        
        guard let authenticationKey else {
            throw RendezvousCryptoError.noAuthenticationKey
        }
        
        // Derives keys
        
        // STK = BLAKE2b(
        //     key=
        //         AK.secret
        //      || X25519HSalsa20(<local.ETK>.secret, <remote.ETK>.public)
        //     salt='st',
        //     personal='3ma-rendezvous'
        // )
        
        guard let derivedEphemeralTransportKey = NaClCrypto.shared().sharedSecret(
            forPublicKey: remotePublicEphemeralTransportKey,
            secretKey: localEphemeralTransportKeyPair.privateKey
        ) else {
            throw RendezvousCryptoError.unableToDeriveKeys
        }
        
        let sharedTransportKey = try threemaBlake2b.deriveKey(
            from: authenticationKey + derivedEphemeralTransportKey,
            with: "st",
            derivedKeyLength: .b32
        )
        
        // RIDTK = BLAKE2b(key=STK.secret, salt='ridt', personal='3ma-rendezvous')
        let ridtk = try threemaBlake2b.deriveKey(
            from: sharedTransportKey,
            with: "ridt",
            derivedKeyLength: .b32
        )
        
        // RRDTK = BLAKE2b(key=STK.secret, salt='rrdt', personal='3ma-rendezvous')
        let rrdtk = try threemaBlake2b.deriveKey(
            from: sharedTransportKey,
            with: "rrdt",
            derivedKeyLength: .b32
        )
                
        // Update state
        
        keyState = .transport
        initiatorKey = SymmetricKey(data: ridtk)
        responderKey = SymmetricKey(data: rrdtk)
        
        // Sequence numbers are not reset
        
        // RPH = BLAKE2b(
        //    out-length=32,
        //    salt='ph',
        //    personal='3ma-rendezvous',
        //    input=STK.secret,
        // )
        let rendezvousPathHash = try ThreemaBlake2b.hash(
            sharedTransportKey,
            salt: "ph",
            personal: "3ma-rendezvous",
            hashLength: .b32
        )
                
        return rendezvousPathHash
    }
}
