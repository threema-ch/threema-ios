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

import Foundation
@preconcurrency import WebRTC

typealias Transceivers<Transceiver: RTCRtpTransceiverProtocol> = [MediaKind: Transceiver]

protocol RemoteContextProtocol {
    var microphoneAudioContext: RemoteAudioContext? { get }
    var cameraVideoContext: RemoteVideoContext? { get }
}

struct RemoteContext: RemoteContextProtocol {
    let microphoneAudioContext: RemoteAudioContext?
    let cameraVideoContext: RemoteVideoContext?
    
    init() {
        self.microphoneAudioContext = nil
        self.cameraVideoContext = nil
    }
    
    private init(microphoneAudioContext: RemoteAudioContext, cameraVideoContext: RemoteVideoContext) {
        self.microphoneAudioContext = microphoneAudioContext
        self.cameraVideoContext = cameraVideoContext
    }
    
    static func fromTransceiverMap(transceivers: Transceivers<some RTCRtpTransceiverProtocol>) -> RemoteContext {
        guard transceivers.values.allSatisfy({ $0 is RTCRtpTransceiver }) else {
            return RemoteContext()
        }
        
        guard let microphoneAudio = transceivers[MediaKind.audio] as? RTCRtpTransceiver else {
            fatalError("Expected remote audio transceiver to be set")
        }
        guard let cameraVideo = transceivers[MediaKind.video] as? RTCRtpTransceiver else {
            fatalError("Expected remote video transceiver to be set")
        }
        
        // TODO: Implement
        return RemoteContext(
            microphoneAudioContext: RemoteAudioContext.create(microphoneAudio),
            cameraVideoContext: RemoteVideoContext.create(cameraVideo)
        )
    }
}

struct RemoteAudioContext: Sendable {
    // TODO: Implement
    
    let track: RTCAudioTrack
    let receiver: RTCRtpReceiver
    let mid: String
    
    static func create(_ transceiver: RTCRtpTransceiver) -> RemoteAudioContext {
        guard let track = transceiver.receiver.track as? RTCAudioTrack else {
            fatalError()
        }
        
        return RemoteAudioContext(track: track, receiver: transceiver.receiver, mid: transceiver.mid)
    }
}

struct RemoteVideoContext: Sendable {
    // TODO: Implement
    let track: RTCVideoTrack
    let receiver: RTCRtpReceiver
    let mid: String
    
    static func create(_ transceiver: RTCRtpTransceiver) -> RemoteVideoContext {
        guard let track = transceiver.receiver.track as? RTCVideoTrack else {
            fatalError()
        }
        
        return RemoteVideoContext(track: track, receiver: transceiver.receiver, mid: transceiver.mid)
    }
}
