import Foundation

@objc public final class VoIPCallHangupMessage: NSObject {
    public var contactIdentity: String!
    public let callID: VoIPCallID
    public var date: Date?
    public var completion: (() -> Void)?
    
    init(callID: VoIPCallID, completion: (() -> Void)?) {
        self.callID = callID
        self.completion = completion
        super.init()
    }
    
    public convenience init(contactIdentity: String, callID: VoIPCallID, completion: (() -> Void)?) {
        self.init(callID: callID, completion: completion)
        self.contactIdentity = contactIdentity
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallHangupMessage: VoIPCallMessageProtocol {
    
    enum VoIPCallHangupMessageError: Error {
        case generateJson(error: Error)
    }
        
    public static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any]) -> T where T: VoIPCallMessageProtocol {
        let callID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as! UInt32)
        return VoIPCallHangupMessage(callID: callID, completion: nil) as! T
    }
    
    public func encodeAsJson() throws -> Data {
        let json = [VoIPCallConstants.callIDKey: callID.callID] as [AnyHashable: Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallHangupMessageError.generateJson(error: error)
        }
    }
}
