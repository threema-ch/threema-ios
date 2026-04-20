import CocoaLumberjackSwift
import Foundation
import WebRTC

enum TransceiverSetup {
    static func setupTransceiver(_ transceiver: RTCRtpTransceiver) {
        
        var error: NSError?
        transceiver.setDirection(.recvOnly, error: &error)
        
        transceiver.receiver.track?.isEnabled = true
        
        if let error {
            fatalError(error.description)
        }
    }
    
    static func setupLocalTransceiver(_ transceiver: RTCRtpTransceiver, kind: SdpKind) {
        
        var error: NSError?
        transceiver.setDirection(.sendOnly, error: &error)
        
        if let error {
            fatalError(error.description)
        }
        
        TransceiverSetup.setCameraVideoSimulcastEncodingParameters(kind: kind, transceiver: transceiver)
    }
    
    static func setCameraVideoSimulcastEncodingParameters(kind: SdpKind, transceiver: RTCRtpTransceiver) {
        guard kind == .video else {
            return
        }
        
        DDLogNotice("[GroupCall] Current parameters \(transceiver.sender.parameters)")
        
        let prevParam = transceiver.sender.parameters
        
        transceiver.sender.parameters = {
            let param = RTCRtpParameters()
            // In Android this was taken from an enum. We have guessed the correct value here.
            param.degradationPreference = NSNumber(value: 3)
            param.encodings = [RTCRtpEncodingParameters]()
            param.encodings = GroupCallSessionDescription.CAMERA_SEND_ENCODINGS.map { $0.toRtcEncoding() }
            // swiftformat:disable:next acronyms
            param.transactionId = prevParam.transactionId
            
            return param
        }()
    }
}
