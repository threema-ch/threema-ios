//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import AVFoundation
import CocoaLumberjackSwift
import Foundation
import SwiftProtobuf
import ThreemaEssentials
import ThreemaProtocols
import WebRTC

@GlobalGroupCallActor
final class RemoteParticipant: Participant {
    
    // MARK: - Types
    
    enum MessageResponseAction {
        case none
        
        case epHelloAndAuth(RemoteParticipant, (Data, Data))
        case sendAuth(RemoteParticipant, Data)
        case handshakeCompleted(RemoteParticipant)
        
        case participantToSFU(Groupcall_ParticipantToSfu.Envelope, RemoteParticipant, ParticipantStateChange)
        case participantToParticipant(RemoteParticipant, Data)
        
        case muteStateChanged(RemoteParticipant, ParticipantStateChange)
        case rekeyReceived(RemoteParticipant, MediaKeys)
    }

    // TODO: (IOS-4059) Have a mute state on Participant, only yield .participantChanged and retrieve current value in UIUpdate

    // MARK: - Private Variables
    
    private let groupCallMessageCrypto: GroupCallMessageCryptoProtocol
    
    // TODO: (IOS-4059) Make these non-optional to prevent force-unwrapping
    private var pckRemote: Data?
    private var pcckRemote: Data?
    
    /// Our key pair
    private var keyPair: KeyPair
    
    /// Our Participant Call Cookie
    private var pcck: Data
    
    private var nonceCounter = SequenceNumber<UInt64>()
    private var nonceCounterRemote = SequenceNumber<UInt64>()
    
    private var mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]?
    
    private var remoteContext: RemoteContext?
    
    private var handshakeState: HandShakeState {
        didSet {
            DDLogNotice(
                "[GroupCall] Participant \(participantID.id) handshake state changed from \(oldValue) to \(handshakeState)"
            )
        }
    }
    
    // MARK: - Internal Variables
    
    // TODO: (IOS-4059) Move a11y string to NormalParticipant, make `dependencies` private again
    let dependencies: Dependencies

    // TODO: (IOS-4059) Would be nice if this wasn't optional so we could move it to the parent class.
    private(set) var threemaIdentity: ThreemaIdentity?
    private(set) var nickname: String?
        
    var needsPostHandshakeRekey = false

    var isHandshakeCompleted: Bool {
        handshakeState == .done
    }
    
    // MARK: - Lifecycle
    
    init(
        participantID: ParticipantID,
        dependencies: Dependencies,
        groupCallMessageCrypto: GroupCallMessageCryptoProtocol,
        isExistingParticipant: Bool
    ) {
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
        
        super.init(participantID: participantID)
    }
    
    func handle(
        message: Groupcall_ParticipantToParticipant.OuterEnvelope,
        localParticipant: LocalParticipant
    ) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] \(#function)")
        
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
                DDLogWarn("Received PCK or PCCK match local ones")
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
            
            return .handshakeCompleted(self)
            
        case .done:
            return try handlePostHandshakeMessage(relayData: message.encryptedData)
        }
        
        // This line should never be reached!
    }
    
    // TODO: (IOS-4131) This function is currently unused, might be related to mentioned ticket
    func setNeedsRekeyIfEligible() {
        guard handshakeState == .await_auth else {
            return
        }
        
        needsPostHandshakeRekey = true
    }
}

// MARK: - Private Helper Functions

extension RemoteParticipant {
    
    private func handlePostHandshakeMessage(relayData: Data) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // TODO: (IOS-3883) Why is this copied here?
        let data = relayData
        
        var nextPcckNonce = pcckRemote!
        nextPcckNonce.append(nonceCounterRemote.next().littleEndianData)
        
        guard let innerData = dependencies.groupCallCrypto.decryptData(
            cipherText: data,
            withKey: keyPair.privateKey,
            signKey: pckRemote!,
            nonce: nextPcckNonce
        ) else {
            assertionFailure()
            throw GroupCallError.decryptionFailure
        }
        
        guard let envelope = try? Groupcall_ParticipantToParticipant.Envelope(serializedData: innerData) else {
            assertionFailure()
            throw GroupCallError.decryptionFailure
        }
        
        switch envelope.content {
        
        case let .captureState(newCaptureState):
            DDLogNotice("New capture state is \(newCaptureState)")
            switch newCaptureState.state {
           
            case let .camera(muteState):
               
                guard let innerState = muteState.state else {
                    DDLogError("[GroupCall] Camera state announcement doesn't have state")
                    assertionFailure()
                    throw GroupCallError.decryptionFailure
                }
                
                switch innerState {
                case .on:
                    DDLogNotice("[GroupCall] Camera announced on")
                    return try .participantToSFU(subscribeVideo(subscribe: true), self, .videoState(.unmuted))
                case .off:
                    DDLogNotice("[GroupCall] Camera announced off")
                    return try .participantToSFU(subscribeVideo(subscribe: false), self, .videoState(.muted))
                }
            
            case let .microphone(muteState):
                
                guard let innerState = muteState.state else {
                    DDLogError("[GroupCall] Audio state announcement doesn't have state")
                    assertionFailure()
                    throw GroupCallError.decryptionFailure
                }
                
                switch innerState {
                case .on:
                    DDLogNotice("[GroupCall] Audio state announced on")
                    // TODO: (IOS-4111) According to the protocol no subscribe is needed if the microphone changes
                    return try .participantToSFU(subscribeAudio(), self, .audioState(.unmuted))
                case .off:
                    DDLogNotice("[GroupCall] Audio state announced off")
                    return .muteStateChanged(self, .audioState(.muted))
                }
            
            case .none:
                DDLogNotice(
                    "[GroupCall] Received a `Groupcall_ParticipantToParticipant.CaptureState`, which could not be processed, so ignoring it."
                )
                return .none
            }
       
        case .none:
            DDLogWarn(
                "[GroupCall] Creating content for `Groupcall_ParticipantToParticipant.Envelope` failed, ignoring it."
            )
            return .none
        
        case .encryptedAdminEnvelope:
            DDLogNotice("[GroupCall] Received an encryptedAdminEnvelope, which not yet supported, so ignoring it.")
            return .none
       
        case let .rekey(mediaKeys):
            return handleRekey(with: mediaKeys)
       
        case .holdState:
            DDLogNotice("[GroupCall] Received a holdState, which not yet supported, so ignoring it.")
            return .none
        }
    }
}

// MARK: - Handshake Messages

extension RemoteParticipant {
    func handshakeHelloMessage(for localIdentity: ThreemaIdentity, localNickname: String) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
    
    private func handshakeAuthMessage(with mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
}

// MARK: - Handshake Completed P2P Messages

extension RemoteParticipant {
    // MARK: Incoming

    private func handleRekey(with key: Groupcall_ParticipantToParticipant.MediaKey) -> MessageResponseAction {
        let mediaKey = MediaKeys(
            pcmk: key.pcmk,
            epoch: Int(key.epoch),
            ratchetCounter: Int(key.ratchetCounter),
            dependencies: dependencies
        )
        return .rekeyReceived(self, mediaKey)
    }
    
    // MARK: Outgoing
    
    func audio(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send audio mute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        var p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope()
        p2pEnvelope.padding = dependencies.groupCallCrypto.padding()
        p2pEnvelope.captureState = Groupcall_ParticipantToParticipant.CaptureState()
        
        switch mute {
        case .muted:
            p2pEnvelope.captureState.microphone.state = .off(Common_Unit())
        case .unmuted:
            p2pEnvelope.captureState.microphone.state = .on(Common_Unit())
        }
        
        let serializedP2PEnvelope = try p2pEnvelope.ownSerializedData()
        
        return try encrypt(serializedP2PEnvelope)
    }
    
    func audioMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try audio(.muted)
    }
    
    func audioUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try audio(.unmuted)
    }
    
    func video(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send video unmute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        var p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope()
        p2pEnvelope.padding = dependencies.groupCallCrypto.padding()
        p2pEnvelope.captureState = Groupcall_ParticipantToParticipant.CaptureState()
        
        switch mute {
        case .muted:
            p2pEnvelope.captureState.camera.state = .off(Common_Unit())
        case .unmuted:
            p2pEnvelope.captureState.camera.state = .on(Common_Unit())
        }
        
        let serializedP2PEnvelope = try p2pEnvelope.ownSerializedData()
        
        return try encrypt(serializedP2PEnvelope)
    }
    
    func videoUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try video(.unmuted)
    }
    
    func videoMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try video(.muted)
    }
    
    func rekeyMessage(with protocolMediaKeys: Groupcall_ParticipantToParticipant.MediaKey) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send rekey message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        let p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.rekey = protocolMediaKeys
        }
        
        let serializedP2PEnvelope = try p2pEnvelope.ownSerializedData()
        
        return try encrypt(serializedP2PEnvelope)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send audio mute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        var nextPcckNonce = pcck
        nextPcckNonce.append(nonceCounter.next().littleEndianData)
        
        guard let outerData = dependencies.groupCallCrypto.encryptData(
            plaintext: data,
            withPublicKey: pckRemote!,
            secretKey: keyPair.privateKey,
            nonce: nextPcckNonce
        ) else {
            throw GroupCallError.encryptionFailure
        }
        
        return outerData
    }
}

// MARK: - Handshake Completed Participant to SFU Messages

extension RemoteParticipant {
    private func subscribeAudio() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot subscribe to audio of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        let subMessage = Groupcall_ParticipantToSfu.ParticipantMicrophone.with {
            $0.participantID = participantID.id
            $0.subscribe = Groupcall_ParticipantToSfu.ParticipantMicrophone.Subscribe()
        }

        let outer = Groupcall_ParticipantToSfu.Envelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.requestParticipantMicrophone = subMessage
        }
        
        return outer
    }
    
    func subscribeVideo(subscribe: Bool) throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot subscribe to video of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
        
        let resolution = Common_Resolution.with {
            $0.height = GroupCallConfiguration.SubscribeVideo.height
            $0.width = GroupCallConfiguration.SubscribeVideo.width
        }
        
        var subMessage = Groupcall_ParticipantToSfu.ParticipantCamera()
        subMessage.participantID = participantID.id
        
        if subscribe {
            let internalSub = Groupcall_ParticipantToSfu.ParticipantCamera.Subscribe.with {
                $0.desiredResolution = resolution
                $0.desiredFps = GroupCallConfiguration.SubscribeVideo.fps
            }
            subMessage.subscribe = internalSub
        }
        else {
            subMessage.unsubscribe = Groupcall_ParticipantToSfu.ParticipantCamera.Unsubscribe()
        }
        
        let outer = Groupcall_ParticipantToSfu.Envelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.requestParticipantCamera = subMessage
        }

        return outer
    }
    
    func unsubscribeVideo() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot unsubscribe to video of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.badParticipantState
        }
                
        let subMessage = Groupcall_ParticipantToSfu.ParticipantCamera.with {
            $0.participantID = participantID.id
            $0.unsubscribe = Groupcall_ParticipantToSfu.ParticipantCamera.Unsubscribe()
        }

        let outer = Groupcall_ParticipantToSfu.Envelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.requestParticipantCamera = subMessage
        }

        return outer
    }
}

// MARK: - RemoteParticipantProtocol

extension RemoteParticipant: RemoteParticipantProtocol {
    func getID() async -> ParticipantID {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return participantID
    }
    
    func setIdentityRemote(id: ThreemaIdentity) {
        threemaIdentity = id
    }
    
    func setRemoteContext(_ remoteContext: RemoteContext) {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        self.remoteContext = remoteContext
    }
    
    func add(
        _ mediaKey: Groupcall_ParticipantToParticipant.MediaKey,
        using decryptor: ThreemaGroupCallFrameCryptoDecryptor
    ) throws {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        guard mediaKey.epoch < UInt8.max else {
            throw GroupCallError.localProtocolViolation
        }
        
        guard mediaKey.ratchetCounter < UInt8.max else {
            throw GroupCallError.localProtocolViolation
        }
        
        let uint8Epoch = UInt8(mediaKey.epoch)
        let uint8RatchetCounter = UInt8(mediaKey.ratchetCounter)
        
        DDLogNotice("[GroupCall] Added key epoch=\(mediaKey.epoch) ratchedCounter=\(mediaKey.ratchetCounter)")
        decryptor.addPcmk(mediaKey.pcmk, epoch: uint8Epoch, ratchetCounter: uint8RatchetCounter)
    }
    
    func add(decryptor: ThreemaGroupCallFrameCryptoDecryptor) throws {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        guard let mediaKeys else {
            fatalError()
        }
        
        self.mediaKeys = []
        
        guard let audioContext = remoteContext?.microphoneAudioContext else {
            fatalError()
        }
        
        guard let videoContext = remoteContext?.cameraVideoContext else {
            fatalError()
        }
        
        decryptor.attach(
            with: audioContext.receiver,
            mediaType: .audio,
            tag: "\(participantID.id).\(audioContext.mid).opus.receiver"
        )
        decryptor.attach(
            with: videoContext.receiver,
            mediaType: .video,
            tag: "\(participantID.id).\(videoContext.mid).vp8.receiver"
        )
        
        for mediaKey in mediaKeys {
            DDLogNotice("[GroupCall] Added key epoch=\(mediaKey.epoch) ratchetCounter=\(mediaKey.ratchetCounter)")
            try add(mediaKey, using: decryptor)
        }
    }
    
    func addUsingGroupCallActor(decryptor: ThreemaGroupCallFrameCryptoDecryptor) throws {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        try add(decryptor: decryptor)
    }
    
    func getRemoteContext() async -> RemoteContext? {
        remoteContext
    }
}
