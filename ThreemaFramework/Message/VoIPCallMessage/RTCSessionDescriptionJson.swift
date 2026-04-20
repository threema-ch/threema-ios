import Foundation
import WebRTC

extension RTCSessionDescription {
        
    enum RTCSessionDescriptionError: Error {
        case generateJson(error: Error)
        case unknownSdpType(unknownType: String)
    }
    
    class func description(from dictionary: [AnyHashable: Any]) -> RTCSessionDescription {
        let type = RTCSessionDescription.type(for: dictionary[VoIPCallConstants.JSON_ANSWER_ANSWER_SDPTYPE] as! String)
        let sdp = dictionary[VoIPCallConstants.JSON_ANSWER_ANSWER_SDP]
        return RTCSessionDescription(type: type, sdp: sdp as! String)
    }
}

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else {
            return nil
        }
        return self[range]
    }
}
