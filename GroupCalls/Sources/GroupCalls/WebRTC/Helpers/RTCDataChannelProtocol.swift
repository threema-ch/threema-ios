import Foundation
import WebRTC

protocol RTCDataChannelProtocol: NSObject, Sendable {
    var delegate: RTCDataChannelDelegate? { get set }
    
    func sendData(_ buffer: RTCDataBuffer) -> Bool
    func close()
}

// MARK: - RTCDataChannel + Sendable, RTCDataChannelProtocol

extension RTCDataChannel: @unchecked Sendable, RTCDataChannelProtocol { }
