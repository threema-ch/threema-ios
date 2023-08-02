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

import AVFoundation
import CocoaLumberjackSwift
import Foundation
import SwiftProtobuf
import ThreemaProtocols
@preconcurrency import WebRTC

@GlobalGroupCallActor
public final class RemoteParticipant {
    // MARK: - Types

    typealias NonceCounterT = Int
    
    enum MessageResponseAction {
        case none
        case handshakeCompleted(RemoteParticipant)
        case participantToSFU(Groupcall_ParticipantToSfu.Envelope, RemoteParticipant, ParticipantStateChange)
        case sendAuth(RemoteParticipant, Data)
        case epHelloAndAuth(RemoteParticipant, (Data, Data))
        case participantToParticipant(RemoteParticipant, Data)
        case muteStateChanged(RemoteParticipant, ParticipantStateChange)
        case rekeyReceived(RemoteParticipant, MediaKeys)
    }
    
    // MARK: - Private Variables
    
    private let dependencies: Dependencies
    private let groupCallCrypto: GroupCallMessageCryptoProtocol
    
    private var pcckRemote: Data?
    private var pckRemote: Data?
    
    private var keyPair: KeyPair
    /// Participant Call Cookie
    private var pcck: Data
    
    private var nonceCounter: NonceCounterT = 1
    private var nonceCounterRemote: NonceCounterT = 1
    
    private var mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]?
    
    private var remoteContext: RemoteContext?
    
    private var handshakeState: HandShakeState {
        didSet {
            DDLogNotice("[GroupCall] Participant \(id) handshake state changed from \(oldValue) to \(handshakeState)")
        }
    }
    
    // MARK: - Internal Variables
    
    var identityRemote: ThreemaID?
    
    let participant: ParticipantID
    
    var needsPostHandshakeRekey = false
    
    var id: UInt32 {
        participant.id
    }
    
    var isHandshakeCompleted: Bool {
        handshakeState == .done
    }
    
    var newMediaKeys: [Groupcall_ParticipantToParticipant.MediaKey] {
        // TODO: This shouldn't return all we have used ever
        mediaKeys ?? [Groupcall_ParticipantToParticipant.MediaKey]()
    }
    
    // MARK: - Lifecycle
    
    init(
        participant: ParticipantID,
        dependencies: Dependencies,
        groupCallCrypto: GroupCallMessageCryptoProtocol,
        isExistingParticipant: Bool
    ) {
        self.participant = participant
        self.dependencies = dependencies
        self.groupCallCrypto = groupCallCrypto
        
        let keys = dependencies.groupCallCrypto.generateKeyPair()
        self.keyPair = KeyPair(publicKey: keys.1, privateKey: keys.0)
        self.pcck = self.dependencies.groupCallCrypto.randomBytes(of: 16)
        self.handshakeState = isExistingParticipant ? .await_ep_hello : .await_np_hello
    }
    
    func handle(
        message: Groupcall_ParticipantToParticipant.OuterEnvelope,
        localParticipant: LocalParticipant
    ) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] \(#function)")
        
        switch handshakeState {
        case .await_np_hello:
            handleHandshakeHello(message: message)
            handshakeState = .await_auth
            let mediaKeys = [localParticipant.protocolMediaKeys, localParticipant.pendingProtocolMediaKeys]
                .compactMap { $0 }
            return .epHelloAndAuth(
                self,
                (
                    handshakeHelloMessage(for: try! ThreemaID(
                        id: localParticipant.identity,
                        nickname: localParticipant.nickname
                    )),
                    sendHandshakeAuth(with: mediaKeys)
                )
            )
        case .await_ep_hello:
            handleHandshakeHello(message: message)
            handshakeState = .await_auth
            let mediaKeys = [localParticipant.protocolMediaKeys, localParticipant.pendingProtocolMediaKeys]
                .compactMap { $0 }
            return .sendAuth(self, sendHandshakeAuth(with: mediaKeys))
        case .await_auth:
            handleAuth(message: message)
            handshakeState = .done
            return .handshakeCompleted(self)
        case .done:
            return try handlePostHandshakeMessage(relayData: message.encryptedData)
        }
    }
    
    func setNeedsRekeyIfElligible() {
        guard handshakeState == .await_auth else {
            return
        }
        
        needsPostHandshakeRekey = true
    }
}

// MARK: - Private Helper Functions

extension RemoteParticipant {
    
    private func handlePostHandshakeMessage(relayData: Data) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        let data = relayData
        // The first message is the handshake auth message
        
        var nextPcckNonce = pcckRemote!
        var littleEndianNonceCounter = nonceCounterRemote.littleEndian
        nextPcckNonce.append(Data(bytes: &littleEndianNonceCounter, count: MemoryLayout<NonceCounterT>.size))
        
        nonceCounterRemote += 1
        
        guard let innerData = dependencies.groupCallCrypto.decryptData(
            cipherText: data,
            withKey: keyPair.privateKey,
            signKey: pckRemote!,
            nonce: nextPcckNonce
        ) else {
            assertionFailure()
            throw GroupCallsError.decryptionFailure
        }
        
        guard let envelope = try? Groupcall_ParticipantToParticipant.Envelope(serializedData: innerData) else {
            assertionFailure()
            throw GroupCallsError.decryptionFailure
        }
        
        switch envelope.content {
        case let .captureState(newCaptureState):
            DDLogNotice("New capture state is \(newCaptureState)")
            switch newCaptureState.state {
            case let .camera(muteState):
                DDLogNotice("Camera announced")
                guard let innerState = muteState.state else {
                    DDLogError("[GroupCall] Camera state announcement doesn't have state")
                    assertionFailure()
                    throw GroupCallsError.decryptionFailure
                }
                switch innerState {
                case .on:
                    DDLogNotice("[GroupCall] Camera announced on")
                    return try .participantToSFU(subscribeVideo(), self, .videoState(.unmuted))
                case .off:
                    DDLogNotice("[GroupCall] Camera announced off")
                    return .muteStateChanged(self, .videoState(.muted))
                }
            case let .microphone(muteState):
                guard let innerState = muteState.state else {
                    DDLogError("[GroupCall] Audio state announcement doesn't have state")
                    assertionFailure()
                    throw GroupCallsError.decryptionFailure
                }
                switch innerState {
                case .on:
                    DDLogNotice("[GroupCall] Audio state announced on")
                    return try .participantToSFU(subscribeAudio(), self, .audioState(.unmuted))
                case .off:
                    DDLogNotice("[GroupCall] Audio state announced off")
                    return .muteStateChanged(self, .audioState(.muted))
                }
            case .none:
                fatalError()
            }
        case .none:
            fatalError()
        case .some(.encryptedAdminEnvelope(_)):
            fatalError()
        case let .rekey(mediaKeys):
            return handleRekey(with: mediaKeys)
        case .some(.holdState(_)):
            DDLogNotice("TODO: Handle hold state message")
            return .none
        }
    }
}

// MARK: - Handshake Messages

extension RemoteParticipant {
    func handshakeHelloMessage(for localIdentity: ThreemaID) -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        var helloMessage = Groupcall_ParticipantToParticipant.Handshake.Hello()
        helloMessage.identity = localIdentity.id
        helloMessage.nickname = localIdentity.nickname
        helloMessage.pck = keyPair.publicKey
        helloMessage.pcck = pcck
        
        let nonce = dependencies.groupCallCrypto.randomBytes(of: 24)
        
        var envelope = Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope()
        envelope.padding = nonce
        envelope.hello = helloMessage
        
        let serializedEnvelope = try! envelope.serializedData()
        
        let encryptedEnvelope = groupCallCrypto.symmetricEncryptByGCHK(serializedEnvelope, nonce: nonce)!
        
        var result = nonce
        result.append(encryptedEnvelope)
        
        return result
    }
    
    func sendHandshakeAuth(with mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]) -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        var handshakeAuth = Groupcall_ParticipantToParticipant.Handshake.Auth()
        handshakeAuth.pcck = pcckRemote!
        handshakeAuth.pck = pckRemote!
        
        handshakeAuth.mediaKeys = mediaKeys
        
        var handshakeAuthEnvelope = Groupcall_ParticipantToParticipant.Handshake.AuthEnvelope()
        handshakeAuthEnvelope.auth = handshakeAuth
        
        guard let serializedHandshakeAuthEnvelope = try? handshakeAuthEnvelope.serializedData() else {
            fatalError()
        }
        
        var nextPcckNonce = pcck
        var littleEndianNonceCounter = nonceCounter.littleEndian
        nextPcckNonce.append(Data(bytes: &littleEndianNonceCounter, count: MemoryLayout<NonceCounterT>.size))
        nonceCounter += 1
        
        let innerNonce = dependencies.groupCallCrypto.randomBytes(of: 24)
        guard let sharedSecret = dependencies.groupCallCrypto.sharedSecret(with: identityRemote!.id) else {
            // TODO: We need should throw here or attempt to fetch the contact.
            // This should be handled by the app, a new contact can join a group call iff it has previously joined the
            // group
            // i.e. the public key should already be known. Thus we can probably safely abort here.
            fatalError()
        }
        
        guard let innerData = try? groupCallCrypto.symmetricEncryptBYGCNHAK(
            sharedSecret: sharedSecret,
            plainText: serializedHandshakeAuthEnvelope,
            nonce: innerNonce
        ) else {
            fatalError()
        }
        
        var completeInnerData = innerNonce
        completeInnerData.append(innerData)
        
        guard let outerData = dependencies.groupCallCrypto.encryptData(
            plaintext: completeInnerData,
            withPublicKey: pckRemote!,
            secretKey: keyPair.privateKey,
            nonce: nextPcckNonce
        ) else {
            fatalError()
        }
        
        return outerData
    }
    
    private func handleAuth(message: Groupcall_ParticipantToParticipant.OuterEnvelope) {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        let data = message.encryptedData
        
        assert(nonceCounterRemote == 1)
        
        var nextPcckNonce = pcckRemote!
        var littleEndianNonceCounter = nonceCounterRemote.littleEndian
        nextPcckNonce.append(Data(bytes: &littleEndianNonceCounter, count: MemoryLayout<NonceCounterT>.size))
        nonceCounterRemote += 1
        
        guard let innerData = dependencies.groupCallCrypto.decryptData(
            cipherText: data,
            withKey: keyPair.privateKey,
            signKey: pckRemote!,
            nonce: nextPcckNonce
        ) else {
            assertionFailure()
            return
        }
        
        let innerNonce = innerData[0..<24]
        let ciphertext = innerData.advanced(by: 24)
        
        guard let sharedSecret = dependencies.groupCallCrypto.sharedSecret(with: identityRemote!.id) else {
            // TODO: We need should throw here or attempt to fetch the contact.
            fatalError()
        }
        
        guard let decrypted = try? groupCallCrypto.symmetricDecryptBYGCNHAK(
            sharedSecret: sharedSecret,
            cipherText: ciphertext,
            nonce: innerNonce
        ) else {
            fatalError()
        }
        
        guard let authMessage = try? Groupcall_ParticipantToParticipant.Handshake
            .AuthEnvelope(serializedData: decrypted).auth else {
            fatalError()
        }
        
        mediaKeys = authMessage.mediaKeys
    }
    
    private func handleHandshakeHello(message: Groupcall_ParticipantToParticipant.OuterEnvelope) {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        let data = message.encryptedData
        
        let nonce = data[0..<24]
        let cipherText = data.advanced(by: 24)
        guard let decrypted = groupCallCrypto.symmetricDecryptByGCHK(cipherText, nonce: nonce) else {
            fatalError()
        }
        
        guard let handshake = try? Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope(serializedData: decrypted)
            .hello else {
            fatalError()
        }
        
        assert(handshake.unknownFields.data.isEmpty)
        
        guard handshake.unknownFields.data.isEmpty else {
            fatalError()
        }
        
        pcckRemote = handshake.pcck
        pckRemote = handshake.pck
        identityRemote = try! ThreemaID(id: handshake.identity, nickname: handshake.nickname)
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
    
    // MARK: Outoging
    
    func audio(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send audio mute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope()
        p2pEnvelope.captureState = Groupcall_ParticipantToParticipant.CaptureState()
        p2pEnvelope.padding = dependencies.groupCallCrypto.padding()
        
        switch mute {
        case .muted:
            p2pEnvelope.captureState.microphone.state = .off(Common_Unit())
        case .unmuted:
            p2pEnvelope.captureState.microphone.state = .on(Common_Unit())
        }
        
        guard let serializedp2pEnvelope = try? p2pEnvelope.serializedData() else {
            throw FatalStateError.SerializationFailure
        }
        
        return try encrypt(serializedp2pEnvelope)
    }
    
    func audioMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return try audio(.muted)
    }
    
    func audioUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return try audio(.unmuted)
    }
    
    func video(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send video unmute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope()
        p2pEnvelope.captureState = Groupcall_ParticipantToParticipant.CaptureState()
        p2pEnvelope.padding = dependencies.groupCallCrypto.padding()
        
        switch mute {
        case .muted:
            p2pEnvelope.captureState.camera.state = .off(Common_Unit())
        case .unmuted:
            p2pEnvelope.captureState.camera.state = .on(Common_Unit())
        }
        
        guard let serializedp2pEnvelope = try? p2pEnvelope.serializedData() else {
            throw FatalStateError.SerializationFailure
        }
        
        return try encrypt(serializedp2pEnvelope)
    }
    
    func videoUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return try video(.unmuted)
    }
    
    func videoMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return try video(.muted)
    }
    
    func rekeyMessage(with protocolMediaKeys: Groupcall_ParticipantToParticipant.MediaKey) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send rekey message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope()
        p2pEnvelope.rekey = protocolMediaKeys
        p2pEnvelope.padding = dependencies.groupCallCrypto.padding()
        
        guard let serializedp2pEnvelope = try? p2pEnvelope.serializedData() else {
            fatalError()
        }
        
        return try encrypt(serializedp2pEnvelope)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot send audio mute message to participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var nextPcckNonce = pcck
        var littleEndianNonceCounter = nonceCounter.littleEndian
        nextPcckNonce.append(Data(bytes: &littleEndianNonceCounter, count: MemoryLayout<NonceCounterT>.size))
        nonceCounter += 1
        
        guard let outerData = dependencies.groupCallCrypto.encryptData(
            plaintext: data,
            withPublicKey: pckRemote!,
            secretKey: keyPair.privateKey,
            nonce: nextPcckNonce
        ) else {
            throw ParticipantError.EncryptionFailure
        }
        
        return outerData
    }
}

// MARK: - Handshake Completed Participant to SFU Messages

extension RemoteParticipant {
    private func subscribeAudio() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot subscribe to audio of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var subMessage = Groupcall_ParticipantToSfu.ParticipantMicrophone()
        subMessage.action = .subscribe(Groupcall_ParticipantToSfu.ParticipantMicrophone.Subscribe())
        subMessage.participantID = participant.id

        var outer = Groupcall_ParticipantToSfu.Envelope()
        outer.requestParticipantMicrophone = subMessage
        outer.padding = dependencies.groupCallCrypto.padding()
        
        return outer
    }
    
    func subscribeVideo() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot subscribe to video of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        var res = Common_Resolution()
        res.height = GroupCallConfiguration.SubscribeVideo.height
        res.width = GroupCallConfiguration.SubscribeVideo.width
        
        var internalSub = Groupcall_ParticipantToSfu.ParticipantCamera.Subscribe()
        internalSub.desiredFps = GroupCallConfiguration.SubscribeVideo.fps
        internalSub.desiredResolution = res
        
        var subMessage = Groupcall_ParticipantToSfu.ParticipantCamera()
        subMessage.participantID = participant.id
        subMessage.action = .subscribe(internalSub)

        var outer = Groupcall_ParticipantToSfu.Envelope()
        outer.requestParticipantCamera = subMessage
        outer.padding = dependencies.groupCallCrypto.padding()

        return outer
    }
    
    func unsubscribeVideo() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        // Sanity Checks
        guard handshakeState == .done else {
            let msg = "Cannot unsubscribe to video of participant in state \(handshakeState)"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw ParticipantError.BadParticipantState
        }
        
        let internalSub = Groupcall_ParticipantToSfu.ParticipantCamera.Unsubscribe()
        
        var subMessage = Groupcall_ParticipantToSfu.ParticipantCamera()
        subMessage.participantID = participant.id
        subMessage.action = .unsubscribe(internalSub)

        var outer = Groupcall_ParticipantToSfu.Envelope()
        outer.requestParticipantCamera = subMessage
        outer.padding = dependencies.groupCallCrypto.padding()

        return outer
    }
}

extension RemoteParticipant {
    func getIdentity() -> ThreemaID? {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return identityRemote
    }
}

// MARK: - RemoteParticipantProtocol

extension RemoteParticipant: RemoteParticipantProtocol {
    func getID() async -> ParticipantID {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        return ParticipantID(id: id)
    }
    
    func setIdentityRemote(id: ThreemaID) {
        identityRemote = id
    }
    
    func setRemoteContext(_ remoteContext: RemoteContext) {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        self.remoteContext = remoteContext
    }
    
    func add(
        _ mediaKey: Groupcall_ParticipantToParticipant.MediaKey,
        using decryptor: ThreemaGroupCallFrameCryptoDecryptor
    ) throws {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        guard mediaKey.epoch < UInt8.max else {
            throw FatalGroupCallError.LocalProtocolViolation
        }
        
        guard mediaKey.ratchetCounter < UInt8.max else {
            throw FatalGroupCallError.LocalProtocolViolation
        }
        
        let uint8Epoch = UInt8(mediaKey.epoch)
        let uint8RatchetCounter = UInt8(mediaKey.ratchetCounter)
        
        DDLogNotice("[GroupCall] Added key epoch=\(mediaKey.epoch) ratchedCounter=\(mediaKey.ratchetCounter)")
        decryptor.addPcmk(mediaKey.pcmk, epoch: uint8Epoch, ratchetCounter: uint8RatchetCounter)
    }
    
    func add(decryptor: ThreemaGroupCallFrameCryptoDecryptor) throws {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
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
            tag: "\(participant.id).\(audioContext.mid).opus.receiver"
        )
        decryptor.attach(
            with: videoContext.receiver,
            mediaType: .video,
            tag: "\(participant.id).\(videoContext.mid).vp8.receiver"
        )
        
        for mediaKey in mediaKeys {
            DDLogNotice("[GroupCall] Added key epoch=\(mediaKey.epoch) ratchetCounter=\(mediaKey.ratchetCounter)")
            try add(mediaKey, using: decryptor)
        }
    }
    
    func addUsingGroupCallActor(decryptor: ThreemaGroupCallFrameCryptoDecryptor) throws {
        DDLogNotice("[GroupCall] Participant \(id) \(#function)")
        
        try add(decryptor: decryptor)
    }
    
    func getRemoteContext() async -> RemoteContext? {
        remoteContext
    }
}
