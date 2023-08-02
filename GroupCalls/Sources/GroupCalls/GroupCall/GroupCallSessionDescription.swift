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
import WebRTC

// MARK: - Nested Types

extension GroupCallSessionDescription {
    fileprivate struct Codec {
        let payloadType: UInt8
        let parameters: [UInt64]
        let feedback: [String]?
        let fmtp: [String]?
    }
    
    fileprivate enum DirectionType {
        case local
        case remote
    }
}

@GlobalGroupCallActor
/// Generates the WebRTC session description based on its internal session description state
/// All new participants must be registered by calling `addParticipantToMLineOrder(participantID:)`
final class GroupCallSessionDescription: Sendable {
    // MARK: - Private Properties

    private let state: SessionDescriptionState
    
    // MARK: - Lifecycle
    
    init(localParticipantID: ParticipantID) {
        self.state = SessionDescriptionState(version: 1, localParticipantID: localParticipantID)
    }
    
    // MARK: - Update Functions
    
    func addParticipantToMLineOrder(participantID: ParticipantID) {
        DDLogNotice("[GroupCall] [mLineOrder] Current SessionDescription \(Unmanaged.passUnretained(self).toOpaque())")
        DDLogNotice("[GroupCall] [mLineOrder] Adding participant to mLineOrder \(participantID)")
        DDLogNotice("[GroupCall] [mLineOrder] Pre Current mLineOrder \(state.mLineOrder)")
        state.mLineOrder.append(participantID)
        DDLogNotice("[GroupCall] [mLineOrder] Post Current mLineOrder \(state.mLineOrder)")
    }
    
    // MARK: - SDP Generating
    
    func generateRemoteDescription(from descriptionInit: RemoteSessionDescriptionInit) -> String {
        // List of all bundled MIDs
        var bundle = [Mid]()
        
        // Generated remote lines
        var lines = [String]()
        
        DDLogNotice("[GroupCall] [mLineOrder] Current SessionDescription \(Unmanaged.passUnretained(self).toOpaque())")
        DDLogNotice("[GroupCall] [mLineOrder] Current mLineOrder is \(state.mLineOrder)")
        
        // Add local media lines
        var mLineOrder = Array(state.mLineOrder)
        if mLineOrder.removeFirst() != state.localParticipantID {
            fatalError("Expected local participant ID to be first in mLineOrder")
        }
        let mids = Mids(from: state.localParticipantID)
  
        // Add RTP media lines
        bundle.append(mids.microphone)
        lines += createRtpMediaLines(
            type: .local,
            kind: .audio,
            active: true,
            extensions: GroupCallSessionDescription.MICROPHONE_HEADER_EXTENSIONS,
            codecs: GroupCallSessionDescription.MICROPHONE_CODECS,
            mid: mids.microphone
        )
        bundle.append(mids.camera)
        lines += createRtpMediaLines(
            type: .local,
            kind: .video,
            active: true,
            extensions: GroupCallSessionDescription.CAMERA_HEADER_EXTENSIONS,
            codecs: GroupCallSessionDescription.CAMERA_CODECS,
            mid: mids.camera,
            simulcast: GroupCallSessionDescription.CAMERA_SEND_ENCODINGS
        )
        
        // Add SCTP media line
        bundle.append(mids.data)
        lines += createSctpMediaLines(mid: mids.data)
        
        // Add remote media lines
        var remoteParticipants = Set(descriptionInit.remoteParticipants)
        for participantID in mLineOrder {
            DDLogNotice("[GroupCall] [mLineOrder] Processing participant \(participantID)")
            let mids = Mids(from: participantID)
            
            // Check if the remote participant is active
            let active = remoteParticipants.remove(participantID) != nil
            
            // Add RTP media lines
            bundle.append(mids.microphone)
            lines += createRtpMediaLines(
                type: .remote,
                kind: .audio,
                active: active,
                extensions: GroupCallSessionDescription.MICROPHONE_HEADER_EXTENSIONS,
                codecs: GroupCallSessionDescription.MICROPHONE_CODECS,
                mid: mids.microphone
            )
            bundle.append(mids.camera)
            lines += createRtpMediaLines(
                type: .remote,
                kind: .video,
                active: active,
                extensions: GroupCallSessionDescription.CAMERA_HEADER_EXTENSIONS,
                codecs: GroupCallSessionDescription.CAMERA_CODECS,
                mid: mids.camera
            )
            
            remoteParticipants.remove(participantID)
        }
        
        DDLogNotice("[GroupCall] [mLineOrder] Remote participants is \(remoteParticipants)")
        // Sanity-check
        if !remoteParticipants.isEmpty {
            fatalError("Expected a remote media line to be present for each remote participant ID")
        }
        
        // Prepend session lines
        lines = (createSessionLines(from: descriptionInit, bundle: bundle) + lines)
        
        // Generate description
        lines.append("")
        return lines.joined(separator: "\r\n")
    }
}

// MARK: Internal Helper Function

extension GroupCallSessionDescription {
    nonisolated static func patchLocalDescription(sdp: String) -> String {
        let opus = MICROPHONE_CODECS["opus"]!
        
        // Ensure correct Opus settings
        return sdp.replacingOccurrences(
            of: "a=fmtp:\(opus.payloadType) .*",
            with: "a=fmtp:\(opus.payloadType) \(opus.fmtp!.joined(separator: ";"))",
            options: .regularExpression
        )
    }
}

// MARK: Private Helper Functions

extension GroupCallSessionDescription {
    private func createRtpMediaLines(
        type: DirectionType,
        kind: MediaKind,
        active: Bool,
        extensions: [UInt: String],
        codecs: [String: Codec],
        mid: Mid,
        simulcast: [SendEncoding]? = nil
    ) -> [String] {
        
        let payloadTypes = codecs.map { _, codec in codec.payloadType }
        
        // Determine direction
        var direction = ""
        switch (active, type) {
        case (false, _):
            direction = "inactive"
        case (true, DirectionType.local):
            direction = "recvonly"
        case (true, DirectionType.remote):
            direction = "sendonly"
        }
        
        // Add media-specific lines
        var lines: [String] = [
            "m=\(kind) \(active ? "9" : "0") UDP/TLS/RTP/SAVPF \(payloadTypes.map(String.init).joined(separator: " "))",
            "c=IN IP4 0.0.0.0",
            "a=rtcp:9 IN IP4 0.0.0.0",
            "a=mid:\(mid)",
        ]
        
        let extensionLines = extensions.map { id, uri in "a=extmap:\(id) \(uri)" }
        lines += extensionLines
        lines += [
            "a=\(direction)",
            "a=rtcp-mux",
        ]
        if kind == .video {
            lines.append("a=rtcp-rsize")
        }
        
        // Add msid if remote participant
        if type == .remote {
            lines.append("a=msid:- \(mid)")
        }
        
        // Add codec-specific lines
        for (name, codec) in codecs {
            lines
                .append(
                    "a=rtpmap:\(codec.payloadType) \(name)/\(codec.parameters.compactMap { "\($0)" }.joined(separator: "/"))"
                )
            if let feedback = codec.feedback {
                lines += feedback.map { feedback in "a=rtcp-fb:\(codec.payloadType) \(feedback)" }
            }
            if let fmtp = codec.fmtp {
                lines.append("a=fmtp:\(codec.payloadType) \(fmtp.joined(separator: ";"))")
            }
        }
        
        // Add simulcast lines, if necessary
        if active, kind == .video, type == .local, simulcast != nil {
            let rids = simulcast!.map(\.rid)
            lines += rids.map { rid in "a=rid:\(rid) recv" }
            lines.append("a=simulcast:recv \(rids.joined(separator: ";"))")
        }
        
        return lines
    }
    
    private func createSctpMediaLines(mid: Mid) -> [String] {
        [
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel",
            "c=IN IP4 0.0.0.0",
            "a=mid:\(mid)",
            "a=sctp-port:5000",
            "a=max-message-size:131072",
        ]
    }
    
    private func createSessionLines(from descriptionInit: RemoteSessionDescriptionInit, bundle: [Mid]) -> [String] {
        let lines = [
            "v=0",
            "o=- \(state.localParticipantID.id) \(state.version) IN IP4 127.0.0.1",
            "s=-",
            "t=0 0",
            "a=group:BUNDLE \(bundle.map { $0 }.joined(separator: " "))",
            "a=ice-ufrag:\(descriptionInit.parameters.iceParameters.usernameFragment)",
            "a=ice-pwd:\(descriptionInit.parameters.iceParameters.password)",
            "a=ice-options:trickle",
            "a=ice-lite",
            "a=fingerprint:sha-256 \(descriptionInit.parameters.dtlsParameters.fingerprintToString())",
            "a=setup:passive",
        ]
        
        state.version += 1
        
        return lines
    }
}

// MARK: - Static Codec Initialization

extension GroupCallSessionDescription {
    fileprivate static let MICROPHONE_CODECS: [String: Codec] = [
        "opus": Codec(
            payloadType: 111,
            parameters: [48000, 2],
            feedback: ["transport-cc"],
            fmtp: ["minptime=10", "useinbandfec=1", "usedtx=1"]
        ),
    ]

    fileprivate static let CAMERA_CODECS: [String: Codec] = [
        "VP8": Codec(
            payloadType: 96,
            parameters: [90000],
            feedback: ["transport-cc", "ccm fir", "nack", "nack pli", "goog-remb"],
            fmtp: nil
        ),
        "rtx": Codec(
            payloadType: 97,
            parameters: [90000],
            feedback: nil,
            fmtp: ["apt=96"]
        ),
    ]

    fileprivate static let MICROPHONE_HEADER_EXTENSIONS: [UInt: String] = [
        10: "urn:ietf:params:rtp-hdrext:ssrc-audio-level",
        4: "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
        5: "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
        1: "urn:ietf:params:rtp-hdrext:sdes:mid",
        // TODO(SE-257): Disabled until we can use cryptex
    ]

    fileprivate static let CAMERA_HEADER_EXTENSIONS: [UInt: String] = [
        1: "urn:ietf:params:rtp-hdrext:sdes:mid",
        2: "urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id",
        3: "urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id",
        4: "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
        5: "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
        11: "urn:3gpp:video-orientation",
        12: "urn:ietf:params:rtp-hdrext:toffset",
    ]

    static let CAMERA_SEND_ENCODINGS: [SendEncoding] = [
        SendEncoding(
            rid: "l",
            maxBitrateBps: 100_000,
            scalabilityMode: ScalabilityMode.L1T3,
            scaleResolutionDownBy: 4
        ),
        SendEncoding(
            rid: "m",
            maxBitrateBps: 250_000,
            scalabilityMode: ScalabilityMode.L1T3,
            scaleResolutionDownBy: 2
        ),
        SendEncoding(
            rid: "h",
            maxBitrateBps: 2_200_000,
            scalabilityMode: ScalabilityMode.L1T3
        ),
    ]
}
