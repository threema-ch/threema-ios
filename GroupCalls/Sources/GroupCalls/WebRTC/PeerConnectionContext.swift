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

import AsyncAlgorithms
import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
@preconcurrency import WebRTC

enum UserInteraction {
    case camera(CaptureState)
    case microphone(CaptureState)
    case left
}

enum PeerConnectionResult {
    case connectionStateChange(RTCIceConnectionState)
    case newDataChannelMessage(RTCDataBuffer)
    case userInteraction(UserInteraction)
}

protocol PeerConnectionContextProtocol: AnyObject, Sendable {
    var dataChannelContext: DataChannelContextProtocol { get }
    var peerConnection: RTCPeerConnectionProtocol { get }
    
    var transceivers: [RTCRtpTransceiverProtocol] { get }
    
    init(peerConnection: RTCPeerConnectionProtocol, dataChannelContext: DataChannelContextProtocol)
    
    static func build<T>(
        from configuration: RTCConfiguration,
        with constraints: RTCMediaConstraints
    ) throws -> T where T: PeerConnectionContextProtocol
}

protocol RTCRtpTransceiverProtocol: NSObject, Sendable {
    var mid: String { get }
    var mediaType: RTCRtpMediaType { get }
    var direction: RTCRtpTransceiverDirection { get }
    
    func logActivation()
    func setEnabled()
    func setDisabled()
}

// MARK: - RTCRtpTransceiver + Sendable, RTCRtpTransceiverProtocol

extension RTCRtpTransceiver: @unchecked Sendable, RTCRtpTransceiverProtocol {
    func logActivation() {
        DDLogNotice(
            "[GroupCall] Activating local transceiver (kind='\(mediaType)', mid='\(mid)')"
        )
    }
        
    func setEnabled() {
        sender.track?.isEnabled = true
        receiver.track?.isEnabled = true
    }
    
    func setDisabled() {
        sender.track?.isEnabled = false
        receiver.track?.isEnabled = false
    }
}

final class PeerConnectionContext: NSObject, Sendable, PeerConnectionContextProtocol {
    // MARK: - Nested Types

    enum PeerConnectionCtxError: Error {
        case cannotInitializePeerConnection
    }
    
    // MARK: - Public Properties
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    public static let peerConnectionFactory: RTCPeerConnectionFactory = {
        let fieldtrials = [kRTCFieldTrialUseNWPathMonitor: kRTCFieldTrialEnabledValue]
        RTCInitFieldTrialDictionary(fieldtrials)

        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()
    
    // MARK: - Internal Properties
    
    var transceivers: [RTCRtpTransceiverProtocol] {
        peerConnection.transceivers
    }
    
    let peerConnection: RTCPeerConnectionProtocol
    
    let dataChannelContext: DataChannelContextProtocol
    
    let peerConnectionResultStream: AsyncStream<PeerConnectionResult>
    
    // MARK: - Private Properties
    
    fileprivate let peerConnectionResultStreamContinuation: AsyncStream<PeerConnectionResult>.Continuation
    
    // MARK: - Lifecycle
    
    init(peerConnection: RTCPeerConnectionProtocol, dataChannelContext: DataChannelContextProtocol) {
        self.peerConnection = peerConnection
        self.dataChannelContext = dataChannelContext
        
        (self.peerConnectionResultStream, self.peerConnectionResultStreamContinuation) = AsyncStream
            .makeStream(of: PeerConnectionResult.self)
        
        super.init()
        
        self.peerConnection.delegate = self
    }
    
    static func build<PeerConnectionContextImpl>(
        from configuration: RTCConfiguration,
        with constraints: RTCMediaConstraints
    ) throws -> PeerConnectionContextImpl where PeerConnectionContextImpl: PeerConnectionContextProtocol {
        guard let peerConnection = PeerConnectionContext.peerConnectionFactory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: nil
        ) else {
            throw PeerConnectionCtxError.cannotInitializePeerConnection
        }
        let dataChannel = DataChannelContext(peerConnection: peerConnection)
        let ctx = PeerConnectionContextImpl(peerConnection: peerConnection, dataChannelContext: dataChannel)
        
        if let ctx = ctx as? RTCPeerConnectionDelegate {
            peerConnection.delegate = ctx
        }
        
        return ctx
    }
}

// MARK: - RTCPeerConnectionDelegate

extension PeerConnectionContext: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function) to state \(stateChanged)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DDLogNotice(
            // swiftformat:disable:next acronyms
            "RTCPeerConnectionDelegate \(#function) with id \(stream.streamId) \(stream.audioTracks) \(stream.videoTracks)"
        )
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function) connection changed to state \(newState)")
        
        peerConnectionResultStreamContinuation.yield(.connectionStateChange(newState))
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function) \(candidate.sdp)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
    
    public func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didStartReceivingOn transceiver: RTCRtpTransceiver
    ) {
        DDLogNotice(
            "RTCPeerConnectionDelegate \(#function) \(transceiver.mid) \(transceiver.mediaType) \(transceiver.receiver)"
        )
    }
    
    public func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd rtpReceiver: RTCRtpReceiver,
        streams mediaStreams: [RTCMediaStream]
    ) {
        DDLogNotice("RTCPeerConnectionDelegate \(#function)")
    }
}
