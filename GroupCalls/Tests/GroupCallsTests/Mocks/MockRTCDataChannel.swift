import Foundation
import WebRTC
@testable import GroupCalls

final class MockRTCDataChannel: NSObject, RTCDataChannelProtocol {
    func sendData(_ buffer: RTCDataBuffer) -> Bool {
        true
    }
    
    var delegate: RTCDataChannelDelegate?
    
    func close() {
        print("[MockRTCDataChannel] Closed")
    }
}
