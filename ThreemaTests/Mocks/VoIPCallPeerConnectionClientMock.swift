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

import Foundation
@testable import Threema

class VoIPCallPeerConnectionClientMock: VoIPCallPeerConnectionClientProtocol {
    var peerConnection: RTCPeerConnection?

    var delegate: Threema.VoIPCallPeerConnectionClientDelegate?

    var remoteVideoQualityProfile: ThreemaFramework.CallsignalingProtocol.ThreemaVideoCallQualityProfile?

    var isRemoteVideoActivated = false

    var networkIsRelayed = false

    func initialize(
        contactIdentity: String,
        callID: ThreemaFramework.VoIPCallID?,
        peerConnectionParameters: Threema.PeerConnectionParameters,
        delegate: Threema.VoIPCallPeerConnectionClientDelegate,
        completion: @escaping (Error?) -> Void
    ) {
        // no-op
    }

    func close() {
        // no-op
    }

    func muteAudio(completion: @escaping () -> Void) {
        // no-op
    }

    func unmuteAudio(completion: @escaping () -> Void) {
        // no-op
    }

    func activateRTCAudio(speakerActive: Bool) {
        // no-op
    }

    func speakerOff() {
        // no-op
    }

    func speakerOn() {
        // no-op
    }

    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool) {
        // no-op
    }

    func endCaptureLocalVideo(renderer: RTCVideoRenderer, switchCamera: Bool) {
        // no-op
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        // no-op
    }

    func endRemoteVideo(renderer: RTCVideoRenderer) {
        // no-op
    }

    func stopVideoCall() {
        // no-op
    }

    func offer(completion: @escaping (RTCSessionDescription?, ThreemaFramework.VoIPCallSdpPatcher.SdpError?) -> Void) {
        // no-op
    }

    func answer(completion: @escaping (RTCSessionDescription) -> Void) {
        // no-op
    }

    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        // no-op
    }

    func set(addRemoteCandidate: RTCIceCandidate) {
        // no-op
    }

    func logDebugEndStats(completion: @escaping () -> Void) {
        // no-op
    }
}
