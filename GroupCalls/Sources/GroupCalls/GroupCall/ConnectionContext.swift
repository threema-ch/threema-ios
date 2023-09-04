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
import ThreemaProtocols
@preconcurrency import WebRTC

protocol ConnectionContextProtocol {
    associatedtype RTPRtcTransceiverProtocolImpl: RTCRtpTransceiverProtocol
}

@GlobalGroupCallActor
final class ConnectionContext<
    PeerConnectionContextImpl: PeerConnectionContextProtocol,
    RTCRtpTransceiverImpl: RTCRtpTransceiverProtocol
>: Sendable, ConnectionContextProtocol {
    
    // MARK: - Types
    
    typealias RTPRtcTransceiverProtocolImpl = RTCRtpTransceiverImpl
    typealias Transceivers = [MediaKind: RTCRtpTransceiverProtocol]
    
    // MARK: - Private Variables
    
    // MARK: Participant State

    fileprivate let myParticipantID: Participant
    
    fileprivate let cryptoContext: GroupCallFrameCryptoAdapterProtocol
    
    fileprivate let transceivers = TransceiverMap<RTCRtpTransceiverImpl>()
    fileprivate var audioTrack: RTCAudioTrack?
    fileprivate var audioSource: RTCAudioSource?
    fileprivate var videoTrack: RTCVideoTrack?
    var videoCapturer: RTCCameraVideoCapturer?
    
    // MARK: WebRTC Connection

    fileprivate let sessionParameters: SessionParameters
    fileprivate let sessionDescription: GroupCallSessionDescription!
    fileprivate let webRTCConnectionContext: WebRTCConnectionContext<PeerConnectionContextImpl>
    
    fileprivate let webrtcLogger = RTCCallbackLogger()
    
    fileprivate let dependencies: Dependencies
    
    // MARK: - Internal Variables
    
    let rtcAudioSession: RTCAudioSession = {
        let sharedInstance = RTCAudioSession.sharedInstance()
        sharedInstance.useManualAudio = true
        sharedInstance.isAudioEnabled = true
        
        return sharedInstance
    }()
    
    let audioQueue = DispatchQueue(label: "VoIPCallAudioQueue")
        
    var messageStream: AsyncStream<PeerConnectionMessage> {
        webRTCConnectionContext.messageStream
    }
    
    // MARK: - Lifecycle
    
    convenience init(
        certificate: RTCCertificate,
        cryptoContext: GroupCallFrameCryptoAdapterProtocol,
        sessionParameters: SessionParameters,
        dependencies: Dependencies
    ) throws {
        let config = ConnectionContext.getPeerConnectionConfiguration(certificate: certificate)
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let peerConnectionContext: PeerConnectionContextImpl = try PeerConnectionContext.build(
            from: config,
            with: constraints
        )
        
        self.init(
            certificate: certificate,
            cryptoContext: cryptoContext,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: peerConnectionContext
        )
        
        // Initialize WebRTC Logger
        Task.detached { [weak self] in
            // TODO: IOS-3728
            self?.webrtcLogger.severity = .warning
            self?.webrtcLogger.start { message in
                let trimmed = message.trimmingCharacters(in: .newlines)
                DDLogNotice("[GroupCall] [libwebrtc] \(trimmed)")
            }
        }
    }
    
    init(
        certificate: RTCCertificate,
        cryptoContext: GroupCallFrameCryptoAdapterProtocol,
        sessionParameters: SessionParameters,
        dependencies: Dependencies,
        peerConnectionContext: PeerConnectionContextImpl
    ) {
        self.webRTCConnectionContext = WebRTCConnectionContext(
            certificate: certificate,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionCtx: peerConnectionContext
        )
        self.cryptoContext = cryptoContext
        self.sessionParameters = sessionParameters
        
        self.sessionDescription = GroupCallSessionDescription(localParticipantID: sessionParameters.participantID)
        self.myParticipantID = Participant(id: sessionParameters.participantID)
        self.dependencies = dependencies
    }
    
    // MARK: Update Functions
    
    func attachToLocalContext(kind: SdpKind, transceiver: RTCRtpTransceiverImpl) async {
        guard let transceiver = transceiver as? RTCRtpTransceiver else {
            return
        }
        
        switch kind {
        case .audio:
            if let audioTrack {
                assert(transceiver.sender.track == nil)
                
                transceiver.sender.track = audioTrack
                                
                if let transceiver = transceiver as? RTCRtpTransceiverImpl {
                    await transceivers.setLocal([.audio: transceiver])
                }
            }
            else {
                DDLogError("[GroupCall] AudioTrack was unexpectedly nil")
            }
            
        case .video:
            if let videoTrack {
                assert(transceiver.sender.track == nil)
                
                transceiver.sender.track = videoTrack
                                
                if let transceiver = transceiver as? RTCRtpTransceiverImpl {
                    await transceivers.setLocal([.video: transceiver])
                }
            }
            else {
                DDLogError("[GroupCall] VideoTrack was unexpectedly nil")
            }
        }
    }
    
    func updateCall(call: ParticipantStateActor, remove: Set<ParticipantID>, add: Set<ParticipantID>) async throws {
        guard !Task.isCancelled else {
            return
        }
        
        guard !remove.isEmpty || !add.isEmpty else {
            DDLogError("[GroupCall] Ignoring update, no participants to be removed or added")
            return
        }
        
        DDLogNotice("[GroupCall] Update started (remove=\(remove), add=\(add))")
        
        // Create offer
        // The participants to be added are not yet in `transceivers.remote`, so we need to add
        // them explicitly.
        DDLogNotice("[GroupCall] Added (becoming active): \(add)")
        var remoteParticipants = [ParticipantID]()
        await remoteParticipants.append(contentsOf: transceivers.remote.map(\.key))
        remoteParticipants.append(contentsOf: add)
        
        for participant in add {
            sessionDescription.addParticipantToMLineOrder(participantID: participant)
        }
        
        try await createAndApplyOffer(remoteParticipants: remoteParticipants)
        
        // Get all cached transceivers available on the peer connection.
        var unmapped = TransceiverMapActor<RTCRtpTransceiverImpl>()
        
        for transceiver in await transceivers.local.values {
            await unmapped.add(TransceiverAdapter(mid: transceiver.mid, transceiver: transceiver))
        }

        for transceiver in webRTCConnectionContext.getTransceivers() as [RTCRtpTransceiverImpl] {
            await unmapped.add(TransceiverAdapter(mid: transceiver.mid, transceiver: transceiver))
        }

        try await remapLocalTransceivers(unmapped: unmapped, remove: remove, add: add)
        await remapExistingRemoteTransceivers(unmapped: unmapped, add: add)
        await remapAddedRemoteTransceivers(unmapped: &unmapped, add: add, participantState: call)
        
        // Ensure there are no unmapped remaining transceivers
        guard await unmapped.isEmpty else {
            // Unmapped transceivers are a fatal error. We cannot continue and must abort.
            fatalError()
        }
        
        // Create and apply answer
        try await createAndApplyAnswer()
    }
}

// MARK: - Connection Setup & Updates

extension ConnectionContext {
    
    func createAndApplyInitialOfferAndAnswer() async throws {
        let initDescription = RemoteSessionDescriptionInit(
            parameters: sessionParameters,
            remoteParticipants: []
        )
        
        let myDescription = sessionDescription.generateRemoteDescription(from: initDescription)
        
        let sdp = RTCSessionDescription(type: .offer, sdp: myDescription)
        try await webRTCConnectionContext.setRemoteDescription(sdp: sdp)
        
        try await createAndApplyAnswer()
    }
     
    func createAndApplyAnswer() async throws {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let sessionDescription = try await webRTCConnectionContext.answer(for: constraints)
        
        let patched = GroupCallSessionDescription.patchLocalDescription(sdp: sessionDescription.sdp)
        let patchedDescription = RTCSessionDescription(type: .answer, sdp: patched)
        
        DDLogNotice("[GroupCall] [GroupCall] Applying sdp \(patchedDescription)")
        
        try await webRTCConnectionContext.set(patchedDescription)
    }
     
    func addIceCandidates(addresses: [Groupcall_SfuHttpResponse.Join.Address]) async throws {
        // Connect to the SFU
        let candidates = addresses.map { Address(ip: $0.ip, port: $0.port) }.filter { address in
            guard !dependencies.userSettings.ipv6Enabled else {
                return true
            }
            return address.protocolVersion == .ipv4
        }.map { address in
             
            let ipType = address.protocolVersion == .ipv4 ? "1" : "2"
            let sdp = "candidate:\(0) 1 udp \(ipType) \(address.ip) \(address.port) typ host"
             
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: 0, sdpMid: nil)
            return candidate
        }
         
        await withTaskGroup(of: Void.self, body: { group in
            for candidate in candidates {
                group.addTask {
                    try? await self.add(candidate)
                }
            }
        })
    }
    
    func leave() async {
        await teardown()
    }
    
    /// Tears down any connections to the SFU and/or other clients
    /// Upon returning we can start another call / connection without any issues caused
    /// by leftover stuff.
    ///
    /// Note that the implementation in the android app is much more sophisticated. Instead of replicating
    /// the solution from android we did a teardown similar to the one done for 1:1 calls in our app.
    func teardown() async {
        audioTrack?.isEnabled = false
        videoTrack?.isEnabled = false
        
        RTCAudioSession.sharedInstance().lockForConfiguration()
        do {
            if RTCAudioSession.sharedInstance().isActive {
                try RTCAudioSession.sharedInstance().setActive(false)
            }
        }
        catch {
            DDLogError(
                "[GroupCall] An error occurred when setting the shared audio session to inactive \(error.localizedDescription)"
            )
        }
        RTCAudioSession.sharedInstance().unlockForConfiguration()
        
        await videoCapturer?.stopCapture()
        
        webRTCConnectionContext.teardown()
    }
    
    // MARK: - Private Update Helper Functions

    private func createAndApplyOffer(remoteParticipants: any Collection<ParticipantID>) async throws {
        let myDescription = sessionDescription.generateRemoteDescription(from: RemoteSessionDescriptionInit(
            parameters: sessionParameters,
            remoteParticipants: Array(remoteParticipants)
        ))
        
        let sessionDescription = RTCSessionDescription(type: .offer, sdp: myDescription)
        
        DDLogNotice("[GroupCall] Applying offer sdp \(sessionDescription)")
        try await webRTCConnectionContext.setRemoteDescription(sdp: sessionDescription)
    }
     
    private func add(_ candidate: RTCIceCandidate) async throws {
        do {
            try await webRTCConnectionContext.add(candidate)
            DDLogNotice("[GroupCall] Added candidate \(candidate.sdp)")
        }
        catch {
            DDLogNotice("[GroupCall] Error is \(String(describing: error))")
            throw error
        }
    }
}

// MARK: - Transceiver Mapping & Remapping

extension ConnectionContext {
    func mapLocalTransceivers(ownAudioMuteState: OwnMuteState, ownVideoMuteState: OwnMuteState) async throws {
        let map = TransceiverMapActor<RTCRtpTransceiverImpl>()
        
        for transceiver in webRTCConnectionContext.getTransceivers() as [RTCRtpTransceiverImpl] {
            await map.add(TransceiverAdapter(mid: transceiver.mid, transceiver: transceiver))
        }
        
        // Map all local transceivers for the first time
        DDLogNotice("[GroupCall] Mapping all local transceivers")
        
        let newLocalTransceivers = try await {
            var result = [SdpKind: RTCRtpTransceiverImpl]()
            let mids = Mids(from: myParticipantID.id).toMap()
            
            for (kind, mid) in mids {
                guard let transceiver = await map.removeValue(for: mid) else {
                    fatalError("Local '\(kind)' transceiver not found")
                }
                
                if transceiver.mediaType == .audio {
                    if ownAudioMuteState == .unmuted {
                        transceiver.setEnabled()
                    }
                    else {
                        transceiver.setDisabled()
                    }
                }
                if transceiver.mediaType == .video {
                    //  transceiver.sender.track?.isEnabled = ownVideoMuteState == .unmuted
                }
                
                // Initial mapping: Set direction to activate correctly
                transceiver.logActivation()
                
                await map.setupLocalTransceiver(transceiver, kind: kind)
                
                if let productionTransceiver = transceiver as? RTCRtpTransceiver {
                    // Add encryptor
                    try self.cryptoContext.attachEncryptor(
                        to: productionTransceiver,
                        myParticipantID: myParticipantID.id
                    )
                }
                else {
                    #if !DEBUG
                        fatalError()
                    #endif
                }
                
                // Attach to the correct local context
                await attachToLocalContext(kind: kind, transceiver: transceiver)
                
                // Done
                result[kind] = transceiver
            }
            return result
        }()
        
        await transceivers.setLocal(newLocalTransceivers)
        
        // Ensure there are no unmapped remaining transceivers
        guard await map.isEmpty else {
            // Unmapped transceivers are a fatal error. We cannot continue and must abort.
            fatalError()
        }
    }
    
    private func remapAddedRemoteTransceivers(
        unmapped: inout TransceiverMapActor<RTCRtpTransceiverImpl>,
        add: Set<ParticipantID>,
        participantState: ParticipantStateActor
    ) async {
        
        // Create all newly added (pending) remote participant states and map their
        // transceivers.
        DDLogNotice("[GroupCall] Remapping all newly added remote transceivers")
        for participantID in add {
            // Sanity checks
//            if !sessionDescription.mLineOrder.contains(participantID) ||
//            transceivers.remote.contains(participantID.id) {
//                let msg = "remapAddedRemoteTransceivers sanity check failed"
//                assertionFailure(msg)
//                DDLogError(msg)
//            }
            
            // TODO: Add decryptor
//            let decryptor = frameCrypto.addDecryptor(id: participantID.id)
            
            // Create transceivers map
            var remoteTransceivers: [MediaKind: RTCRtpTransceiverImpl] = [:]
            for (kind, mid) in Mids(from: participantID).toMap() {
                // Mark it as mapped
                guard let transceiver = await unmapped.removeValue(for: mid) else {
                    DDLogError("[GroupCall] Remote '\(kind)' transceiver for MID '\(mid)' not found")
                    assertionFailure()
                    continue
                }
                
                // First encounter: Set direction to activate correctly
                transceiver.logActivation()
                
                await unmapped.setupTransceiver(transceiver)
                
                // Add stream to decryptor
//                let tag = "\(participantID.id).\(mid).\(kind == .video ? "vp8" : "opus").receiver"
//                decryptor.attach(transceiver.receiver, tag: tag)
                
                // Set transceiver
                remoteTransceivers[kind.mediaKind] = transceiver
            }
            
            // Apply newly mapped transceivers to the control state
            await participantState.setRemoteContext(
                participantID: participantID,
                remoteContext: RemoteContext.fromTransceiverMap(transceivers: remoteTransceivers)
            )
            
            // Create new remote participant and store the gathered transceivers
            await transceivers.setRemote(participantID, to: remoteTransceivers)
        }
    }
    
    private func remapLocalTransceivers(
        unmapped: TransceiverMapActor<RTCRtpTransceiverImpl>,
        remove: any Collection<ParticipantID>,
        add: any Collection<ParticipantID>
    ) async throws {
        // Remap
        DDLogNotice("[GroupCall] Remapping all local transceivers")
        
        let newLocalTransceivers = await { [self] in
            var result = [SdpKind: RTCRtpTransceiverImpl]()
            let mids = Mids(from: myParticipantID.id).toMap()
            for (kind, mid) in mids {
                // Mark it as mapped
                guard let transceiver = await unmapped.removeValue(for: mid) else {
                    DDLogWarn("We are missing a transceiver for \(mid). But expect it to be available in the future.")
                    continue
                }
                
                if let existingTransceiver = await transceivers.getLocal(for: kind),
                   !existingTransceiver.isEqual(transceiver) {
                    fatalError("Local transceiver has changed. This is not allowed.")
                }
                
                guard transceiver.direction == .sendOnly else {
                    fatalError("Local transceivers must be send only")
                }
                
                result[kind] = transceiver
            }
            return result
        }()
        
        await transceivers.setLocal(newLocalTransceivers)
    }
    
    private func remapExistingRemoteTransceivers(
        unmapped: TransceiverMapActor<some RTCRtpTransceiverProtocol>,
        add: any Collection<ParticipantID>
    ) async {
        // Remap all existing remote participant transceivers
        DDLogVerbose("[GroupCall] Remapping all existing remote transceivers")
        for (participantID, remoteTransceivers) in await transceivers.remote {
            // Sanity checks
            // TODO: Add sanity checks
//            guard sessionParameters.participantID != session.mLineOrder ||
//                sessionParameters.participantID != transceivers.remote[participantID] ||
//                add.contains(participantID) else {
//                    fatalError("remapExistingRemoteTransceivers sanity check failed")
//            }

            for (kind, mid) in Mids(from: participantID).toMap() {
                // Mark it as mapped
                guard let transceiver = await unmapped.removeValue(for: mid) else {
                    fatalError("Remote '\(kind)' transceiver for MID '\(mid)' not found")
                }

                // Ensure transceiver matches the expected instance
                guard let existingMapped = remoteTransceivers[kind.mediaKind],
                      existingMapped.isEqual(transceiver) else {
                    fatalError("Remote '\(kind)' transceiver mismatch")
                }
                
                guard transceiver.direction == .recvOnly else {
                    fatalError("Remote transceiver must be send only.")
                }
            }
        }
    }
    
    func updateAudioMute(with muteState: MuteState) async {
        for localTransceiver in await transceivers.local {
            guard let actualTransceiver = localTransceiver.value as? RTCRtpTransceiver else {
                fatalError()
            }
            
            guard actualTransceiver.mediaType == .audio else {
                continue
            }
            
            switch muteState {
            case .muted:
                actualTransceiver.sender.track?.isEnabled = false
            case .unmuted:
                actualTransceiver.sender.track?.isEnabled = true
            }
        }
    }
}

// MARK: - Private Static Helper Functions

extension ConnectionContext {
    fileprivate static func getPeerConnectionConfiguration(certificate: RTCCertificate) -> RTCConfiguration {
        let config = RTCConfiguration()
        config.certificate = certificate
        config.iceTransportPolicy = .all
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.tcpCandidatePolicy = .disabled
        config.candidateNetworkPolicy = .all
        config.keyType = .ECDSA
        config.continualGatheringPolicy = .gatherContinually
        config.shouldPruneTurnPorts = false // Is set to based on priority in android
        config.sdpSemantics = .unifiedPlan
        config.cryptoOptions = RTCCryptoOptions(
            srtpEnableGcmCryptoSuites: true,
            srtpEnableAes128Sha1_32CryptoCipher: false,
            srtpEnableAes128Sha1_80CryptoCipher: false,
            srtpEnableEncryptedRtpHeaderExtensions: false,
            sframeRequireFrameEncryption: false
        )
        config.offerExtmapAllowMixed = true // Never disable this or you will see crashes!
        
        return config
    }
}

// MARK: - DataChannel Sending

extension ConnectionContext {
    func relay(_ relay: Groupcall_ParticipantToParticipant.OuterEnvelope) throws {
        var relayEnvelope = Groupcall_ParticipantToSfu.Envelope()
        relayEnvelope.padding = dependencies.groupCallCrypto.padding()
        relayEnvelope.relay = relay
        
        guard let serializedOuter = try? relayEnvelope.serializedData() else {
            throw FatalGroupCallError.SerializationFailure
        }
        
        let buffer = RTCDataBuffer(data: serializedOuter, isBinary: true)
        
        webRTCConnectionContext.send(buffer)
    }
    
    func send(_ data: Data) {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        webRTCConnectionContext.send(buffer)
    }
}

// MARK: - Audio / Video Context

extension ConnectionContext {
    func startVideoCapture(position: CameraPosition?) async throws {
        guard let videoCapturer else {
            // TODO: IOS-3743 Group Calls Graceful Error Handling
            fatalError()
        }
        
        let device = RTCCameraVideoCapturer.captureDevices()
            .first { $0.position == position?.avDevicePosition ?? .front }!
        let format = selectFormatForDevice(
            device: device,
            width: GroupCallConfiguration.SendVideo.width,
            height: GroupCallConfiguration.SendVideo.height,
            capturer: videoCapturer
        )
        videoTrack?.isEnabled = true
        
        try? await videoCapturer.startCapture(with: device, format: format, fps: 30)
    }
    
    func createLocalMediaSenders() {
        audioTrack = createAudioTrack()
        videoTrack = createVideoTrack()
    }
    
    func localVideoTrack() -> RTCVideoTrack? {
        videoTrack
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        audioSource = PeerConnectionContext.peerConnectionFactory.audioSource(with: audioConstrains)
        
        // TODO: Wat
        guard let audioSource else {
            fatalError("We assigned audioSource above, this doesn't happen")
        }
        
        // swiftformat:disable acronyms
        let audioTrack = PeerConnectionContext.peerConnectionFactory.audioTrack(with: audioSource, trackId: "gcAudio0")
        // swiftformat:enable acronyms
        
        // TODO: IOS-3877 auto mute after 3 participants
        audioTrack.isEnabled = false
        
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = PeerConnectionContext.peerConnectionFactory.videoSource()
        
        #if targetEnvironment(simulator)
        // TODO: Do something nice for the simulator
        //        self.connectionContext.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        // swiftformat:disable acronyms
        let videoTrack = PeerConnectionContext.peerConnectionFactory.videoTrack(with: videoSource, trackId: "gcVideo0")
        // swiftformat:enable acronyms
        
        videoTrack.isEnabled = false
        return videoTrack
    }
}

extension ConnectionContext {
    // Copied from VoIPCallpeerConnectionClient.swift
    /// Select the correct format for the capture device
    private func selectFormatForDevice(
        device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        capturer: RTCCameraVideoCapturer
    ) -> AVCaptureDevice.Format {
        let targetHeight = height
        let targetWidth = width
        
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff = Int32.max
        
        let supportedFormats = RTCCameraVideoCapturer.supportedFormats(for: device)
        
        for format in supportedFormats {
            let dimension: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(
                format.formatDescription
            )
            let diff =
                abs(targetWidth - dimension.width) +
                abs(targetHeight - dimension.height)
            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            }
            else if diff == currentDiff, pixelFormat == capturer.preferredOutputPixelFormat() {
                selectedFormat = format
            }
        }
        
        return selectedFormat!
    }
}
