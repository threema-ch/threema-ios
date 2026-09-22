import Foundation

public final class VoIPCallHangupMessage: NSObject {
    public var contactIdentity: String!
    public let callID: VoIPCallID
    public var date: Date?
    public var duration: UInt?
    public var completion: (() -> Void)?
    
    public let receivedAsReflected: Bool?
    public let isOutgoing: Bool
    
    init(
        callID: VoIPCallID,
        duration: UInt? = nil,
        receivedAsReflected: Bool?,
        isOutgoing: Bool,
        completion: (() -> Void)? = nil
    ) {
        self.callID = callID
        self.completion = completion
        self.duration = duration
        self.receivedAsReflected = receivedAsReflected
        self.isOutgoing = isOutgoing
        
        super.init()
    }
    
    public convenience init(
        contactIdentity: String,
        callID: VoIPCallID,
        duration: UInt?,
        receivedAsReflected: Bool? = nil,
        isOutgoing: Bool,
        completion: (() -> Void)? = nil
    ) {
        self.init(
            callID: callID,
            duration: duration,
            receivedAsReflected: receivedAsReflected,
            isOutgoing: isOutgoing,
            completion: completion
        )
        self.contactIdentity = contactIdentity
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallHangupMessage: VoIPCallMessageProtocol {
    
    enum VoIPCallHangupMessageError: Error {
        case generateJson(error: Error)
    }
        
    public static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any], receivedAsReflected: Bool, isOutgoing: Bool) -> T where T: VoIPCallMessageProtocol {
        let callID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as! UInt32)
        
        var decodedDuration: UInt?
        if let duration = dictionary[VoIPCallConstants.callDurationKey] as? UInt {
            decodedDuration = duration
        }
        
        return VoIPCallHangupMessage(
            callID: callID,
            duration: decodedDuration,
            receivedAsReflected: receivedAsReflected,
            isOutgoing: isOutgoing
        ) as! T
    }
    
    public func encodeAsJson() throws -> Data {
        var json = [VoIPCallConstants.callIDKey: callID.callID] as [AnyHashable: Any]
        
        if let duration, duration != 0 {
            json[VoIPCallConstants.callDurationKey] = duration
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallHangupMessageError.generateJson(error: error)
        }
    }
}
