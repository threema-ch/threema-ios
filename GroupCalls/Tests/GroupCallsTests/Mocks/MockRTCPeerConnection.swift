import Foundation
import WebRTC
@testable import GroupCalls

final class MockRTCPeerConnection: RTCPeerConnectionProtocol {
    var transceivers = [RTCRtpTransceiver]()
    
    var delegate: RTCPeerConnectionDelegate?
    
    var isClosed = false
    
    func setRemoteDescription(sdp: RTCSessionDescription) async throws {
        // Noop
    }
    
    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        let desc = RTCSessionDescription(type: .answer, sdp: "")
        
        return desc
    }
    
    func set(_ localDescription: RTCSessionDescription) async throws {
        // noop
    }
    
    func add(_ iceCandidate: RTCIceCandidate) async throws {
        // noop
    }
    
    func close() {
        // noop
        isClosed = true
    }
}
