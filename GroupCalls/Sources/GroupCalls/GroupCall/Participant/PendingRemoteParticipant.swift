//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaEssentials
import ThreemaProtocols

@GlobalGroupCallActor
final class PendingRemoteParticipant: RemoteParticipant {
    
    // MARK: - Participant conformance
    
    let participantID: ParticipantID
        
    // MARK: - Private properties
    
    private var handshakeState: HandShakeState {
        didSet {
            DDLogNotice(
                "[GroupCall] Participant \(participantID.id) handshake state changed from \(oldValue) to \(handshakeState)"
            )
        }
    }

    private let dependencies: Dependencies
    
    private(set) var threemaIdentity: ThreemaIdentity?
    private(set) var nickname: String?
    
    // MARK: Crypto

    private let groupCallMessageCrypto: GroupCallMessageCryptoProtocol

    /// Our key pair
    private var keyPair: KeyPair
    
    /// Our Participant Call Cookie
    private var pcck: Data
    private var remoteContext: RemoteContext?

    private var pckRemote: Data?
    private var pcckRemote: Data?
    
    private var nonceCounter = SequenceNumber<UInt64>()
    private var nonceCounterRemote = SequenceNumber<UInt64>()
    
    private var mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]?
    
    // MARK: - Lifecycle

    init(
        participantID: ParticipantID,
        dependencies: Dependencies,
        groupCallMessageCrypto: GroupCallMessageCryptoProtocol,
        isExistingParticipant: Bool
    ) {
        self.participantID = participantID
        self.dependencies = dependencies
        self.groupCallMessageCrypto = groupCallMessageCrypto
        
        guard let keys = self.dependencies.groupCallCrypto.generateKeyPair() else {
            // TODO: (IOS-4124) Improve error handling
            fatalError("Unable to generate key pair")
        }
        self.keyPair = KeyPair(publicKey: keys.publicKey, privateKey: keys.privateKey)
        self.pcck = self.dependencies.groupCallCrypto.randomBytes(of: ProtocolDefines.pcckLength)
        
        /// **Protocol Step: Join/Leave of Other Participants (Join 4.)**
        /// Join 4. Set the _handshake state_ of this participant to `await-np-hello`.
        self.handshakeState = isExistingParticipant ? .await_ep_hello : .await_np_hello
    }
    
    // MARK: - Internal functions
    
    func setRemoteContext(_ remoteContext: RemoteContext) {
        DDLogNotice("[GroupCall] set RemoteContext for PendingRemoteParticipant with id: \(participantID.id)")
        self.remoteContext = remoteContext
    }

    func handle(
        message: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope,
        localParticipant: LocalParticipant
    ) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] Handle message for PendingRemoteParticipant with id: \(participantID.id)")
        
        /// **Protocol Step: ParticipantToParticipant.OuterEnvelope (Receiving 3.)**
        /// 3. Decrypt `encrypted_data` according to the current _handshake state_ and handle the inner envelope:
        ///    - `await-ep-hello` or `await-np-hello`: Expect a `Handshake.HelloEnvelope`.
        ///    - `await-auth`: Expect a `Handshake.AuthEnvelope`.
        ///    - `done`: Expect a post-auth `Envelope`.
        switch handshakeState {
        case .await_np_hello:
            try handleHandshakeHello(message: message)
            
            /// **Protocol Step: Initial handshake message. (Receiving regular 2.)**
            /// 2. If the group call is scoped to a (Threema) group and `identity` is not part of the associated group
            /// (including the user itself), log a warning and abort these steps.
            // TODO: (IOS-4139) Implement step above
            
            /// **Protocol Step: Initial handshake message. (Receiving regular 3.)**
            /// 3. If the sender is a newly joined participant and therefore the _handshake state_ was set to
            /// `await-np-hello` (as described by the _Join/Leave_ section):
            ///    1. Respond by sending a `Hello` message, immediately followed by an `Auth` message.
            ///    2. Set the participant's _handshake state_ to `await-auth` and abort these steps.
            
            let helloMessage = try handshakeHelloMessage(
                for: localParticipant.threemaIdentity,
                localNickname: localParticipant.nickname
            )
            
            let mediaKeys = [
                localParticipant.protocolMediaKeys,
                localParticipant.pendingProtocolMediaKeys,
            ].compactMap { $0 }
            
            let authMessage = try handshakeAuthMessage(with: mediaKeys)
            
            handshakeState = .await_auth
            
            return .epHelloAndAuth(self, (helloMessage, authMessage))
            
        case .await_ep_hello:
            try handleHandshakeHello(message: message)
            
            /// **Protocol Step: Initial handshake message. (Receiving regular 2.)**
            /// 2. If the group call is scoped to a (Threema) group and `identity` is not part of the associated group
            /// (including the user itself), log a warning and abort these steps.
            // TODO: (IOS-4139) Implement step above
            
            /// **Protocol Step: Initial handshake message. (Receiving regular 4.1)**
            /// 4. If the participant's _handshake state_ is `await-ep-hello`:
            ///    1. If the `pck` reflects the local PCK.public or the `pcck` reflects
            ///       the local PCCK, log a warning and abort these steps.
            guard pckRemote != keyPair.publicKey, pcckRemote != pcck else {
                DDLogWarn("[GroupCall] Received PCK or PCCK match local ones")
                throw GroupCallError.badMessage
            }
            
            /// **Protocol Step: Initial handshake message. (Receiving regular 4.2. & 4.3.)**
            ///    4.2. Respond by sending an `Auth` message.
            ///    4.3. Set the participant's _handshake state_ to `await-auth` and abort these steps.
            
            let mediaKeys = [
                localParticipant.protocolMediaKeys,
                localParticipant.pendingProtocolMediaKeys,
            ].compactMap { $0 }
            let authMessage = try handshakeAuthMessage(with: mediaKeys)
            
            handshakeState = .await_auth
            
            return .sendAuth(self, authMessage)
            
        case .await_auth:
            
            try handleAuth(message: message)
            
            /// **Protocol Step: Second and final handshake message. (Receiving 4.)**
            /// 4. Set the participant's _handshake state_ to `done`.
            handshakeState = .done
            
            DDLogNotice("[GroupCall] Promote PendingRemoteParticipant with ID: \(participantID.id)")
            let joinedParticipant = promote()
            return .handshakeCompleted(joinedParticipant)
            
        case .done:
            fatalError("This should not be called for pending")
        }
    }
    
    func handshakeHelloMessage(for localIdentity: ThreemaIdentity, localNickname: String) throws -> Data {
        DDLogNotice(
            "[GroupCall] Create HandshakeHelloMessage for PendingRemoteParticipant with id: \(participantID.id)"
        )

        let helloMessage = Groupcall_ParticipantToParticipant.Handshake.Hello.with {
            $0.identity = localIdentity.string
            $0.nickname = localNickname
            $0.pck = keyPair.publicKey
            $0.pcck = pcck
        }
        
        let envelope = Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.hello = helloMessage
        }
        
        let serializedEnvelope = try envelope.ownSerializedData()
        
        let nonce = dependencies.groupCallCrypto.randomBytes(of: groupCallMessageCrypto.symmetricNonceLength)
        
        guard let encryptedEnvelope = groupCallMessageCrypto.symmetricEncryptByGCHK(serializedEnvelope, nonce: nonce)
        else {
            throw GroupCallError.encryptionFailure
        }
        
        var result = nonce
        result.append(encryptedEnvelope)
        
        return result
    }
    
    // MARK: - Private functions
    
    private func handshakeAuthMessage(with mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]) throws -> Data {
        DDLogNotice("[GroupCall] Create HandshakeAuthMessage for PendingRemoteParticipant with id: \(participantID.id)")

        let handshakeAuth = Groupcall_ParticipantToParticipant.Handshake.Auth.with {
            $0.pck = pckRemote!
            $0.pcck = pcckRemote!
            $0.mediaKeys = mediaKeys
        }
        
        let handshakeAuthEnvelope = Groupcall_ParticipantToParticipant.Handshake.AuthEnvelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.auth = handshakeAuth
        }
        
        let serializedHandshakeAuthEnvelope = try handshakeAuthEnvelope.ownSerializedData()
        
        /// **Protocol Step**
        /// 1. Let `inner-nonce` be a random nonce.
        /// 2. Let `inner-data` be encrypted by:
        ///
        /// ```text
        /// S = X25519HSalsa20(<sender.CK>.secret, <receiver.CK>.public)
        /// GCNHAK = Blake2b(
        ///   key=S, salt='nha', personal='3ma-call', input=GCKH)
        /// XSalsa20-Poly1305(
        ///   key=GCNHAK,
        ///   nonce=<inner-nonce>,
        ///   data=<AuthEnvelope(Auth)>,
        /// )
        /// ```
        
        let innerNonce = dependencies.groupCallCrypto.randomBytes(of: groupCallMessageCrypto.symmetricNonceLength)
        
        guard let sharedSecret = dependencies.groupCallCrypto.sharedSecret(with: threemaIdentity!.string) else {
            // TODO: (IOS-4124) We need should throw here or attempt to fetch the contact.
            // This should be handled by the app, a new contact can join a group call iff it has previously joined the
            // group
            // i.e. the public key should already be known. Thus we can probably safely abort here.
            fatalError()
        }
        
        guard let innerData = try? groupCallMessageCrypto.symmetricEncryptByGCNHAK(
            sharedSecret: sharedSecret,
            plainText: serializedHandshakeAuthEnvelope,
            nonce: innerNonce
        ) else {
            throw GroupCallError.encryptionFailure
        }
        
        /// **Protocol Step**
        /// 3. Let `outer-data` be encrypted by:
        ///
        /// ```text
        /// XSalsa20-Poly1305(
        ///   key=X25519HSalsa20(<sender.PCK>.secret, <receiver.PCK>.public),
        ///   nonce=<sender.PCCK> || <sender.PCSN+>,
        ///   data=<inner-nonce> || <inner-data>,
        /// )
        /// ```
        
        var completeInnerData = innerNonce
        completeInnerData.append(innerData)
        
        var nextPcckNonce = pcck
        nextPcckNonce.append(nonceCounter.next().littleEndianData)
        
        guard let outerData = dependencies.groupCallCrypto.encryptData(
            plaintext: completeInnerData,
            withPublicKey: pckRemote!,
            secretKey: keyPair.privateKey,
            nonce: nextPcckNonce
        ) else {
            throw GroupCallError.encryptionFailure
        }
        
        return outerData
    }
    
    private func handleHandshakeHello(message: Groupcall_ParticipantToParticipant.OuterEnvelope) throws {
        DDLogNotice(
            "[GroupCall] Handle HandshakeHelloMessage for PendingRemoteParticipant with id: \(participantID.id)"
        )

        let data = message.encryptedData
        
        let nonce = data[0..<groupCallMessageCrypto.symmetricNonceLength]
        let cipherText = data.advanced(by: Int(groupCallMessageCrypto.symmetricNonceLength))
       
        guard let decrypted = groupCallMessageCrypto.symmetricDecryptByGCHK(cipherText, nonce: nonce) else {
            throw GroupCallError.decryptionFailure
        }
        
        guard let helloEnvelope = try? Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope(
            serializedData: decrypted
        ) else {
            throw GroupCallError.decryptionFailure
        }
        
        let helloMessage: Groupcall_ParticipantToParticipant.Handshake.Hello
        switch helloEnvelope.content {
        case let .hello(message):
            helloMessage = message
        case .guestHello:
            throw GroupCallError.unsupportedMessage
        case .none:
            throw GroupCallError.badMessage
        }
        
        pckRemote = helloMessage.pck
        pcckRemote = helloMessage.pcck
        threemaIdentity = ThreemaIdentity(helloMessage.identity)
        nickname = helloMessage.nickname != "" ? helloMessage.nickname : helloMessage.identity
    }
    
    private func handleAuth(message: Groupcall_ParticipantToParticipant.OuterEnvelope) throws {
        DDLogNotice("[GroupCall] Handle HandshakeAuthMessage for PendingRemoteParticipant with id: \(participantID.id)")

        let data = message.encryptedData
        
        var nextPcckNonce = pcckRemote!
        nextPcckNonce.append(nonceCounterRemote.next().littleEndianData)
        
        guard let innerData = dependencies.groupCallCrypto.decryptData(
            cipherText: data,
            withKey: keyPair.privateKey,
            signKey: pckRemote!,
            nonce: nextPcckNonce
        ) else {
            throw GroupCallError.decryptionFailure
        }
        
        let innerNonce = innerData[0..<groupCallMessageCrypto.symmetricNonceLength]
        let ciphertext = innerData.advanced(by: Int(groupCallMessageCrypto.symmetricNonceLength))
        
        guard let sharedSecret = dependencies.groupCallCrypto.sharedSecret(with: threemaIdentity!.string) else {
            // TODO: (IOS-4124) We need should throw here or attempt to fetch the contact.
            fatalError()
        }
        
        guard let decrypted = try? groupCallMessageCrypto.symmetricDecryptByGCNHAK(
            sharedSecret: sharedSecret,
            cipherText: ciphertext,
            nonce: innerNonce
        ) else {
            throw GroupCallError.decryptionFailure
        }
        
        guard let authEnvelope = try? Groupcall_ParticipantToParticipant.Handshake.AuthEnvelope(
            serializedData: decrypted
        ) else {
            throw GroupCallError.decryptionFailure
        }
        
        let authMessage: Groupcall_ParticipantToParticipant.Handshake.Auth
        switch authEnvelope.content {
        case let .auth(auth):
            authMessage = auth
        case .guestAuth:
            throw GroupCallError.unsupportedMessage
        case .none:
            throw GroupCallError.badMessage
        }
        
        /// **Protocol Step: Second and final handshake message. (Receiving 2. & 3.)**
        /// 2. If the repeated `pck` does not equal the local `PCK.public` used towards this participant, log a warning
        /// and abort these steps.
        /// 3. If the repeated `pcck` does not equal the local `PCCK` used towards this participant, log a warning and
        /// abort these steps.
        guard authMessage.pck == keyPair.publicKey, authMessage.pcck == pcck else {
            DDLogWarn("Received PCK or PCCK don't match local ones")
            throw GroupCallError.badMessage
        }
        
        mediaKeys = authMessage.mediaKeys
    }
    
    // MARK: - Helper functions
    
    private func promote() -> JoinedRemoteParticipant {
        JoinedRemoteParticipant(
            participantID: participantID,
            dependencies: dependencies,
            threemaIdentity: threemaIdentity!,
            nickname: nickname!,
            keyPair: keyPair,
            pcck: pcck,
            remoteContext: remoteContext!,
            pckRemote: pckRemote!,
            pcckRemote: pcckRemote!,
            nonceCounter: nonceCounter,
            nonceCounterRemote: nonceCounterRemote,
            mediaKeys: mediaKeys!
        )
    }
}

// MARK: - Equatable

extension PendingRemoteParticipant: Equatable {
    static func == (lhs: PendingRemoteParticipant, rhs: PendingRemoteParticipant) -> Bool {
        lhs.participantID == rhs.participantID
    }
}

// MARK: - Hashable

extension PendingRemoteParticipant: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(participantID)
    }
}
