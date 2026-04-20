import Foundation
import WebRTC

protocol RTCPeerConnectionProtocol: AnyObject {
    var delegate: RTCPeerConnectionDelegate? { get set }
    var transceivers: [RTCRtpTransceiver] { get }
    
    func setRemoteDescription(sdp: RTCSessionDescription) async throws
    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription
    func set(_ localDescription: RTCSessionDescription) async throws
    func add(_ iceCandidate: RTCIceCandidate) async throws
    
    func close()
}

// MARK: - RTCPeerConnection + RTCPeerConnectionProtocol

extension RTCPeerConnection: RTCPeerConnectionProtocol { }
