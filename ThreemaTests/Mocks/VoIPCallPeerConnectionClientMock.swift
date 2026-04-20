import Foundation
@testable import Threema

final class VoIPCallPeerConnectionClientMock: VoIPCallPeerConnectionClientProtocol {
    var peerConnection: RTCPeerConnection?

    var delegate: Threema.VoIPCallPeerConnectionClientDelegate?

    var remoteVideoQualityProfile: ThreemaFramework.CallsignalingProtocol.ThreemaVideoCallQualityProfile?

    var isRemoteVideoActivated = false

    var networkIsRelayed = false

    func initialize(
        contactIdentity: String,
        isInitiator: Bool,
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

    func answer(completion: @escaping (RTCSessionDescription?, ThreemaFramework.VoIPCallSdpPatcher.SdpError?) -> Void) {
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
