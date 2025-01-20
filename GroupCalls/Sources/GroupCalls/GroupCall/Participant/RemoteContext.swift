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
    
    static func fromTransceiverMap(transceivers: Transceivers<some RTCRtpTransceiverProtocol>) throws -> RemoteContext {
        guard transceivers.values.allSatisfy({ $0 is RTCRtpTransceiver }) else {
            return RemoteContext()
        }

        guard let microphoneAudio = transceivers[MediaKind.audio] as? RTCRtpTransceiver else {
            throw GroupCallRemoteContextError.noRemoteAudioTransceiverSet
        }
        guard let cameraVideo = transceivers[MediaKind.video] as? RTCRtpTransceiver else {
            throw GroupCallRemoteContextError.noRemoteVideoTransceiverSet
        }
        
        return try RemoteContext(
            microphoneAudioContext: RemoteAudioContext.create(microphoneAudio),
            cameraVideoContext: RemoteVideoContext.create(cameraVideo)
        )
    }
}

struct RemoteAudioContext: Sendable {
    let track: RTCAudioTrack
    let receiver: RTCRtpReceiver
    let mid: String
    
    var active: Bool {
        get {
            track.isEnabled
        }
        set {
            track.isEnabled = newValue
        }
    }
    
    static func create(_ transceiver: RTCRtpTransceiver) throws -> RemoteAudioContext {
        guard transceiver.mediaType == .audio else {
            DDLogError("[GroupCall] Invalid transceiver kind for remote audio context=\(transceiver.mediaType)")
            throw GroupCallRemoteContextError.invalidTransceiverAudioType
        }
        
        guard transceiver.direction == .recvOnly ||
            transceiver.direction == .sendRecv else {
            DDLogError("[GroupCall] Invalid transceiver direction for remote audio context=\(transceiver.direction)")
            throw GroupCallRemoteContextError.invalidTransceiverAudioDirection
        }
        
        guard let t = transceiver.receiver.track else {
            DDLogError("[GroupCall] Missing track on transceiver=\(transceiver.direction)")
            throw GroupCallRemoteContextError.missingAudioTrackOnReceiver
        }
                
        guard let track = t as? RTCAudioTrack else {
            DDLogError("[GroupCall] Invalid track type for remote audio context=\(t.description)")
            throw GroupCallRemoteContextError.invalidAudioTrackType
        }
        
        return RemoteAudioContext(track: track, receiver: transceiver.receiver, mid: transceiver.mid)
    }
}

struct RemoteVideoContext: Sendable {
    let track: RTCVideoTrack
    let receiver: RTCRtpReceiver
    let mid: String
    
    var active: Bool {
        get {
            track.isEnabled
        }
        set {
            track.isEnabled = newValue
        }
    }
    
    static func create(_ transceiver: RTCRtpTransceiver) throws -> RemoteVideoContext {
        guard transceiver.mediaType == .video else {
            DDLogError("[GroupCall] Invalid transceiver kind for remote video context=\(transceiver.mediaType)")
            throw GroupCallRemoteContextError.invalidTransceiverVideoType
        }
        
        guard transceiver.direction == .recvOnly ||
            transceiver.direction == .sendRecv else {
            DDLogError("[GroupCall] Invalid transceiver direction for remote video context=\(transceiver.direction)")
            throw GroupCallRemoteContextError.invalidTransceiverVideoDirection
        }
        
        guard let t = transceiver.receiver.track else {
            DDLogError("[GroupCall] Missing track on transceiver=\(transceiver.direction)")
            throw GroupCallRemoteContextError.missingVideoTrackOnReceiver
        }
        
        guard let track = t as? RTCVideoTrack else {
            DDLogError("[GroupCall] Invalid track type for remote video context=\(t.description)")
            throw GroupCallRemoteContextError.invalidVideoTrackType
        }
        
        return RemoteVideoContext(track: track, receiver: transceiver.receiver, mid: transceiver.mid)
    }
}
