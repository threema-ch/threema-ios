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
final class JoinedRemoteParticipant: RemoteParticipant, ViewModelParticipant {
    
    // MARK: - Public Properties
    
    nonisolated let participantID: ParticipantID
    /// This property is used in group call status updates. It is provided to us by the SFU and can therefore differ
    /// from the `displayName` which is fetched locally and can depend on a linked contact.
    nonisolated let nickname: String
    
    // MARK: Crypto
    
    /// Our key pair
    private var keyPair: KeyPair
    
    /// Our Participant Call Cookie
    private var pcck: Data
    private var remoteContext: RemoteContext
    
    private var pckRemote: Data
    private var pcckRemote: Data
    
    private var nonceCounter: SequenceNumber<UInt64>
    private var nonceCounterRemote: SequenceNumber<UInt64>
    
    private var mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]
    
    // MARK: - ViewModelParticipant
    
    nonisolated let threemaIdentity: ThreemaIdentity
    let dependencies: Dependencies
    
    nonisolated lazy var displayName: String = dependencies.groupCallParticipantInfoFetcher
        .fetchDisplayName(for: threemaIdentity)
    
    nonisolated lazy var avatar: UIImage? = dependencies.groupCallParticipantInfoFetcher
        .fetchAvatar(for: threemaIdentity)
    
    nonisolated lazy var idColor: UIColor = dependencies.groupCallParticipantInfoFetcher
        .fetchIDColor(for: threemaIdentity)
    
    var audioMuteState: MuteState = .muted
    var videoMuteState: MuteState = .muted
    
    // MARK: - Lifecycle
    
    init(
        participantID: ParticipantID,
        dependencies: Dependencies,
        threemaIdentity: ThreemaIdentity,
        nickname: String,
        keyPair: KeyPair,
        pcck: Data,
        remoteContext: RemoteContext,
        pckRemote: Data,
        pcckRemote: Data,
        nonceCounter: SequenceNumber<UInt64>,
        nonceCounterRemote: SequenceNumber<UInt64>,
        mediaKeys: [Groupcall_ParticipantToParticipant.MediaKey]
    ) {
        self.participantID = participantID
        self.dependencies = dependencies
        self.threemaIdentity = threemaIdentity
        self.nickname = nickname
        self.keyPair = keyPair
        self.pcck = pcck
        self.remoteContext = remoteContext
        self.pckRemote = pckRemote
        self.pcckRemote = pcckRemote
        self.nonceCounter = nonceCounter
        self.nonceCounterRemote = nonceCounterRemote
        self.mediaKeys = mediaKeys
    }

    func handle(
        message: Groupcall_ParticipantToParticipant.OuterEnvelope,
        localParticipant: LocalParticipant
    ) throws -> MessageResponseAction {
        try handlePostHandshakeMessage(relayData: message.encryptedData)
    }
    
    func setAudioMuteState(to state: MuteState) async {
        audioMuteState = state
    }
    
    func setVideoMuteState(to state: MuteState) async {
        videoMuteState = state
    }
}

// MARK: - Private Helper Functions

extension JoinedRemoteParticipant {
    
    private func handlePostHandshakeMessage(relayData: Data) throws -> MessageResponseAction {
        DDLogNotice("[GroupCall] Handle PostHandshakeMessage for JoinedRemoteParticipant with id: \(participantID.id)")

        var nextPcckNonce = pcckRemote
        nextPcckNonce.append(nonceCounterRemote.next().littleEndianData)
        
        guard let innerData = dependencies.groupCallCrypto.decryptData(
            cipherText: relayData,
            withKey: keyPair.privateKey,
            signKey: pckRemote,
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
            switch newCaptureState.state {
           
            case let .camera(muteState):
               
                guard let innerState = muteState.state else {
                    DDLogError(
                        "[GroupCall] Camera state announcement of JoinedRemoteParticipant with id: \(participantID.id) doesn't have state"
                    )
                    assertionFailure()
                    throw GroupCallError.decryptionFailure
                }
                
                switch innerState {
                case .on:
                    return try .participantToSFU(subscribeVideo(subscribe: true), self, .videoState(.unmuted))
                case .off:
                    return try .participantToSFU(subscribeVideo(subscribe: false), self, .videoState(.muted))
                }
            
            case let .microphone(muteState):
                
                guard let innerState = muteState.state else {
                    DDLogError(
                        "[GroupCall] Audio state announcement of JoinedRemoteParticipant with id: \(participantID.id) doesn't have state"
                    )
                    assertionFailure()
                    throw GroupCallError.decryptionFailure
                }
                
                switch innerState {
                case .on:
                    // TODO: (IOS-4111) According to the protocol no subscribe is needed if the microphone changes
                    return try .participantToSFU(subscribeAudio(), self, .audioState(.unmuted))
                case .off:
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

// MARK: - Handshake Completed P2P Messages

extension JoinedRemoteParticipant {
    
    func audioMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try audio(.muted)
    }
    
    func audioUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try audio(.unmuted)
    }
    
    private func audio(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
    
    func videoUnmuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try video(.unmuted)
    }
    
    func videoMuteMessage() throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        return try video(.muted)
    }
    
    private func video(_ mute: MuteState) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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
    
    func rekeyMessage(with protocolMediaKeys: Groupcall_ParticipantToParticipant.MediaKey) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        let p2pEnvelope = Groupcall_ParticipantToParticipant.Envelope.with {
            $0.padding = dependencies.groupCallCrypto.padding()
            $0.rekey = protocolMediaKeys
        }
        
        let serializedP2PEnvelope = try p2pEnvelope.ownSerializedData()
        
        return try encrypt(serializedP2PEnvelope)
    }
    
    private func handleRekey(with key: Groupcall_ParticipantToParticipant.MediaKey) -> MessageResponseAction {
        let mediaKey = MediaKeys(
            pcmk: key.pcmk,
            epoch: Int(key.epoch),
            ratchetCounter: Int(key.ratchetCounter),
            dependencies: dependencies
        )
        return .rekeyReceived(self, mediaKey)
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
        var nextPcckNonce = pcck
        nextPcckNonce.append(nonceCounter.next().littleEndianData)
        
        guard let outerData = dependencies.groupCallCrypto.encryptData(
            plaintext: data,
            withPublicKey: pckRemote,
            secretKey: keyPair.privateKey,
            nonce: nextPcckNonce
        ) else {
            throw GroupCallError.encryptionFailure
        }
        
        return outerData
    }
}

// MARK: - Handshake Completed Participant to SFU Messages

extension JoinedRemoteParticipant {
    private func subscribeAudio() throws -> Groupcall_ParticipantToSfu.Envelope {
        DDLogNotice("[GroupCall] Participant \(participantID.id) \(#function)")
        
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

extension JoinedRemoteParticipant {
    
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
                
        guard let audioContext = remoteContext.microphoneAudioContext else {
            fatalError()
        }
        
        guard let videoContext = remoteContext.cameraVideoContext else {
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

// MARK: - Equatable

extension JoinedRemoteParticipant: Equatable {
    static func == (lhs: JoinedRemoteParticipant, rhs: JoinedRemoteParticipant) -> Bool {
        lhs.participantID == rhs.participantID
    }
}

// MARK: - Hashable

extension JoinedRemoteParticipant: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(participantID)
    }
}
