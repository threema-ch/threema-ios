import Foundation
import WebRTC

final class WebRTCCaptureCtx {
    private var audioTrack: RTCAudioTrack?
    private var audioSource: RTCAudioSource?
    private var videoTrack: RTCVideoTrack?
    
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    let audioQueue = DispatchQueue(label: "VoIPCallAudioQueue")
    
    var videoCapturer: RTCCameraVideoCapturer?
}
