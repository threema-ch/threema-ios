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

import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols
@preconcurrency import WebRTC

@GlobalGroupCallActor
final class WebRTCConnectionContext<PeerConnectionCtxImpl: PeerConnectionContextProtocol> {
    
    // MARK: - Private properties

    fileprivate let sessionDescription: GroupCallSessionDescription!
    fileprivate let peerConnectionCtx: PeerConnectionContextProtocol
    
    fileprivate let webrtcLogger = RTCCallbackLogger()
    
    // MARK: - Internal Properties
    
    var messageStream: AsyncStream<PeerConnectionMessage> {
        peerConnectionCtx.dataChannelContext.messageStream
    }
    
    // MARK: - Lifecycle

    convenience init(
        certificate: RTCCertificate,
        sessionParameters: SessionParameters,
        dependencies: Dependencies
    ) throws {
        let config = WebRTCConnectionContext.getPeerConnectionConfiguration(certificate: certificate)
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let peerConnectionCtx: PeerConnectionCtxImpl = try PeerConnectionContext.build(from: config, with: constraints)
        
        self.init(
            certificate: certificate,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionCtx: peerConnectionCtx
        )
        
        // Initialize WebRTC Logger
        Task.detached { [weak self] in
            self?.webrtcLogger.severity = .warning
            self?.webrtcLogger.start { message in
                if let trimmed = RTCCallbackLogger.trimMessage(message: message) {
                    DDLogNotice("[GroupCall] [libwebrtc] \(trimmed)")
                }
            }
        }
    }
    
    init(
        certificate: RTCCertificate,
        sessionParameters: SessionParameters,
        dependencies: Dependencies,
        peerConnectionCtx: PeerConnectionCtxImpl
    ) {
        self.peerConnectionCtx = peerConnectionCtx
        
        self.sessionDescription = GroupCallSessionDescription(localParticipantID: sessionParameters.participantID)
    }
    
    // MARK: - Update Functions
    
    func teardown() {
        peerConnectionCtx.dataChannelContext.close()
        peerConnectionCtx.peerConnection.close()
    }
    
    // MARK: - Helper Functions
    
    func getTransceivers<T: RTCRtpTransceiverProtocol>() -> [T] {
        peerConnectionCtx.transceivers as! [T]
    }
}

extension WebRTCConnectionContext {
    func send(_ buffer: RTCDataBuffer) {
        peerConnectionCtx.dataChannelContext.sendData(buffer)
    }
}

extension WebRTCConnectionContext {
    func setRemoteDescription(sdp: RTCSessionDescription) async throws {
        try await peerConnectionCtx.peerConnection.setRemoteDescription(sdp: sdp)
    }
    
    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        try await peerConnectionCtx.peerConnection.answer(for: constraints)
    }
    
    func set(_ localDescription: RTCSessionDescription) async throws {
        try await peerConnectionCtx.peerConnection.set(localDescription)
    }
    
    func add(_ iceCandidate: RTCIceCandidate) async throws {
        try await peerConnectionCtx.peerConnection.add(iceCandidate)
    }
}

// MARK: - Private Helper Functions

extension WebRTCConnectionContext {
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
