import Foundation
import WebRTC
@testable import GroupCalls

final class MockRTCDataChannel: NSObject, RTCDataChannelProtocol, @unchecked Sendable {

    var delegate: RTCDataChannelDelegate?
    
    func sendData(_ buffer: RTCDataBuffer) -> Bool {
        true
    }
    
    func close() {
        print("[MockRTCDataChannel] Closed")
    }
}
