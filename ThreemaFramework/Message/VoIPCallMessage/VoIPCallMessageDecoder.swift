import CocoaLumberjackSwift
import Foundation

@objc final class VoIPCallMessageDecoder: NSObject {
    @objc class func decodeVoIPCallOffer(from: BoxVoIPCallOfferMessage) -> VoIPCallOfferMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallAnswer(from: BoxVoIPCallAnswerMessage) -> VoIPCallAnswerMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallHangup(
        from: BoxVoIPCallHangupMessage,
        contactIdentity: String
    ) -> VoIPCallHangupMessage? {
        
        guard let jsonData = from.jsonData, let msg: VoIPCallHangupMessage = decode(jsonData) else {
            DDLogError("[VoipCallMessageDecoder] No JSON data to decode hangup message from id: \(from)")
            return nil
        }
        
        msg.contactIdentity = contactIdentity
        msg.date = from.date
        return msg
    }
    
    @objc class func decodeVoIPCallIceCandidates(from: BoxVoIPCallIceCandidatesMessage)
        -> VoIPCallIceCandidatesMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallRinging(
        from: BoxVoIPCallRingingMessage,
        contactIdentity: String
    ) -> VoIPCallRingingMessage? {
        
        guard let jsonData = from.jsonData, let msg: VoIPCallRingingMessage = decode(jsonData) else {
            DDLogError("[VoipCallMessageDecoder] No JSON data to decode ringing message from id: \(from)")
            return nil
        }
        
        msg.contactIdentity = contactIdentity
        return msg
    }
    
    private class func decode<T: VoIPCallMessageProtocol>(_ jsonData: Data) -> T? {
        do {
            if let dic = try JSONSerialization
                .jsonObject(with: jsonData, options: .mutableContainers) as? [AnyHashable: Any] {
                return T.decodeAsObject(dic)
            }
        }
        catch {
            DDLogError("Error decode voip call message \(error)")
        }
        
        return nil
    }
}
