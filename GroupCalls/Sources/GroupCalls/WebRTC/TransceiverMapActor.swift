import Foundation
import WebRTC

actor TransceiverMapActor<T: RTCRtpTransceiverProtocol> {
    fileprivate var map = [String: T]()
    
    var isEmpty: Bool {
        map.isEmpty
    }
    
    func add(_ transceiver: TransceiverAdapter<T>) {
        map[transceiver.mid] = transceiver.transceiver
    }
    
    func removeValue(for transceiver: Mid) -> T? {
        map.removeValue(forKey: transceiver)
    }
    
    func setupTransceiver(_ transceiver: T) {
        if let transceiver = transceiver as? RTCRtpTransceiver {
            TransceiverSetup.setupTransceiver(transceiver)
        }
    }
    
    func setupLocalTransceiver(_ transceiver: T, kind: SdpKind) {
        if let transceiver = transceiver as? RTCRtpTransceiver {
            TransceiverSetup.setupLocalTransceiver(transceiver, kind: kind)
        }
    }
}
