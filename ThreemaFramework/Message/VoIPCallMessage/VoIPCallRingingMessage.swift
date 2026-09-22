import Foundation

public final class VoIPCallRingingMessage: NSObject {
    public var contactIdentity: String!
    public let callID: VoIPCallID
    public var completion: (() -> Void)?

    public let receivedAsReflected: Bool?
    public let isOutgoing: Bool
    
    init(
        callID: VoIPCallID,
        receivedAsReflected: Bool?,
        isOutgoing: Bool,
        completion: (() -> Void)?
    ) {
        self.callID = callID
        self.completion = completion
        self.receivedAsReflected = receivedAsReflected
        self.isOutgoing = isOutgoing
        
        super.init()
    }
    
    public convenience init(
        contactIdentity: String,
        callID: VoIPCallID,
        receivedAsReflected: Bool? = nil,
        isOutgoing: Bool,
        completion: (() -> Void)?
    ) {
        self.init(
            callID: callID,
            receivedAsReflected: receivedAsReflected,
            isOutgoing: isOutgoing,
            completion: completion
        )
        self.contactIdentity = contactIdentity
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallRingingMessage: VoIPCallMessageProtocol {
    
    enum VoIPCallRingingMessageError: Error {
        case generateJson(error: Error)
    }
        
    public static func decodeAsObject<T>(
        _ dictionary: [AnyHashable: Any],
        receivedAsReflected: Bool,
        isOutgoing: Bool
    ) -> T where T: VoIPCallMessageProtocol {
        let callID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as! UInt32)
        return VoIPCallRingingMessage(
            callID: callID,
            receivedAsReflected: receivedAsReflected,
            isOutgoing: isOutgoing,
            completion: nil
        ) as! T
    }
    
    public func encodeAsJson() throws -> Data {
        let json = [VoIPCallConstants.callIDKey: callID.callID] as [AnyHashable: Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallRingingMessageError.generateJson(error: error)
        }
    }
}
