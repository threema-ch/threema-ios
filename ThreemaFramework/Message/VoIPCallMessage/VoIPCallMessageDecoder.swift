import CocoaLumberjackSwift
import Foundation

final class VoIPCallMessageDecoder: NSObject {
    @objc class func decodeVoIPCallOffer(from: BoxVoIPCallOfferMessage, receivedAsReflected: Bool, isOutgoing: Bool) -> VoIPCallOfferMessage? {
        decode(from.jsonData, receivedAsReflected: receivedAsReflected, isOutgoing: isOutgoing)
    }
    
    @objc class func decodeVoIPCallAnswer(from: BoxVoIPCallAnswerMessage, receivedAsReflected: Bool, isOutgoing: Bool) -> VoIPCallAnswerMessage? {
        decode(from.jsonData, receivedAsReflected: receivedAsReflected, isOutgoing: isOutgoing)
    }
    
    @objc class func decodeVoIPCallHangup(
        from: BoxVoIPCallHangupMessage,
        contactIdentity: String,
        receivedAsReflected: Bool,
        isOutgoing: Bool
    ) -> VoIPCallHangupMessage? {
        guard let jsonData = from.jsonData,
              let msg: VoIPCallHangupMessage = decode(
                  jsonData,
                  receivedAsReflected: receivedAsReflected,
                  isOutgoing: isOutgoing
              ) else {
            DDLogError("[VoipCallMessageDecoder] No JSON data to decode hangup message from id: \(from)")
            return nil
        }
        
        msg.contactIdentity = contactIdentity
        msg.date = from.date
        return msg
    }
    
    @objc class func decodeVoIPCallIceCandidates(
        from: BoxVoIPCallIceCandidatesMessage,
        receivedAsReflected: Bool,
        isOutgoing: Bool
    )
        -> VoIPCallIceCandidatesMessage? {
        decode(from.jsonData, receivedAsReflected: receivedAsReflected, isOutgoing: isOutgoing)
    }
    
    @objc class func decodeVoIPCallRinging(
        from: BoxVoIPCallRingingMessage,
        contactIdentity: String,
        receivedAsReflected: Bool,
        isOutgoing: Bool
    ) -> VoIPCallRingingMessage? {
        
        guard let jsonData = from.jsonData,
              let msg: VoIPCallRingingMessage = decode(
                  jsonData,
                  receivedAsReflected: receivedAsReflected,
                  isOutgoing: isOutgoing
              ) else {
            DDLogError("[VoipCallMessageDecoder] No JSON data to decode ringing message from id: \(from)")
            return nil
        }
        
        msg.contactIdentity = contactIdentity
        return msg
    }
    
    private class func decode<T: VoIPCallMessageProtocol>(_ jsonData: Data, receivedAsReflected: Bool, isOutgoing: Bool) -> T? {
        do {
            if let dic = try JSONSerialization
                .jsonObject(with: jsonData, options: .mutableContainers) as? [AnyHashable: Any] {
                return T.decodeAsObject(
                    dic,
                    receivedAsReflected: receivedAsReflected,
                    isOutgoing: isOutgoing
                )
            }
        }
        catch {
            DDLogError("Error decode voip call message \(error)")
        }
        
        return nil
    }
}
