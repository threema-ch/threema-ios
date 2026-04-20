import Foundation
import WebRTC
@testable import GroupCalls

final class MockPeerConnectionContext: PeerConnectionContextProtocol {
    init(
        peerConnection: GroupCalls.RTCPeerConnectionProtocol,
        dataChannelContext: GroupCalls.DataChannelContextProtocol
    ) {
        self.peerConnection = peerConnection
        self.dataChannelContext = dataChannelContext
    }
    
    static func build<T>(from configuration: RTCConfiguration, with constraints: RTCMediaConstraints) throws -> T
        where T: GroupCalls.PeerConnectionContextProtocol {
        fatalError()
    }
    
    var dataChannelContext: GroupCalls.DataChannelContextProtocol
    
    var peerConnection: GroupCalls.RTCPeerConnectionProtocol
    
    var transceivers = [GroupCalls.RTCRtpTransceiverProtocol]()
}

extension MockPeerConnectionContext {
    func addTransceivers(for: ParticipantID) {
//        let transceiver = MockRTCRtpTransceiver()
    }
}

final class MockRTCRtpTransceiver: NSObject, GroupCalls.RTCRtpTransceiverProtocol {
    var mid: String
    
    var mediaType: RTCRtpMediaType
    
    var direction: RTCRtpTransceiverDirection
    
    func setDirection(_ direction: RTCRtpTransceiverDirection, error: AutoreleasingUnsafeMutablePointer<NSError?>?) {
        self.direction = direction
    }
    
    var loggedActivation = 0
    
    init(mid: String, mediaType: RTCRtpMediaType, direction: RTCRtpTransceiverDirection) {
        self.mid = mid
        self.mediaType = mediaType
        self.direction = direction
    }
    
    func logActivation() {
        loggedActivation += 1
    }
    
    func setEnabled() {
        // Noop
    }
    
    func setDisabled() {
        // Noop
    }
}
