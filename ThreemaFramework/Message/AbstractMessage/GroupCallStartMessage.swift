import CocoaLumberjackSwift
import Foundation
import GroupCalls
import SwiftProtobuf
import ThreemaMacros
import ThreemaProtocols

public final class GroupCallStartMessage: AbstractGroupMessage {
    public var decoded: CspE2e_GroupCallStart?
    
    /// Is there no (longer a) call to join for this message?
    @objc public var callEnded = false

    override public func type() -> UInt8 {
        UInt8(MSGTYPE_GROUP_CALL_START)
    }
    
    override public func flagShouldPush() -> Bool {
        true
    }
    
    override public func allowSendingProfile() -> Bool {
        true
    }
    
    override public func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        .V12
    }
    
    @objc var decodedObj: Any {
        decoded as Any
    }
    
    override public func body() -> Data? {
        guard let groupCreatorASCII = groupCreator?.data(using: .ascii),
              let serializedData = try? decoded?.serializedData()
        else {
            let message = "Unable to create GroupCallStartMessage body"
            DDLogError("\(message)")
            return nil
        }
        
        var body = Data()
        body.append(groupCreatorASCII)
        body.append(groupID)
        body.append(serializedData)
        
        return body
    }
    
    override public func pushNotificationBody() -> String {
        String.localizedStringWithFormat(
            #localize("group_call_notification_body"),
            DateFormatter.shortStyleTimeNoDate(date)
        )
    }
    
    override public func isContentValid() -> Bool {
        decoded != nil
    }

    override public func isGroupCall() -> Bool {
        true
    }
    
    @objc override public init() {
        super.init()
    }
    
    @objc func fromRawProtoBufMessage(rawProtobufMessage: NSData) throws {
        decoded = try CspE2e_GroupCallStart(serializedBytes: rawProtobufMessage as Data)
    }

    // MARK: NSSecureCoding

    private enum CodingKeys: String, CodingKey {
        case cspMessage
        case callEnded
    }

    private enum CodingError: Error {
        case decodeObjectFailed, serializedDataFailed
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // Outside the `do`, so a CSP decoding failure cannot skip it
        self.callEnded = coder.decodeBool(forKey: CodingKeys.callEnded.rawValue)
        
        do {
            guard let data = coder.decodeObject(of: NSData.self, forKey: CodingKeys.cspMessage.rawValue) else {
                throw CodingError.decodeObjectFailed
            }
            self.decoded = try CspE2e_GroupCallStart(serializedBytes: Data(data))
        }
        catch {
            DDLogError("Decoding failed: \(error)")
        }
    }
    
    override public func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        // Outside the `do`, so a CSP encoding failure cannot skip it
        coder.encode(callEnded, forKey: CodingKeys.callEnded.rawValue)
        
        do {
            guard let data = try decoded?.serializedData() else {
                throw CodingError.serializedDataFailed
            }
            coder.encode(NSData(data: data), forKey: CodingKeys.cspMessage.rawValue)
        }
        catch {
            DDLogError("Encoding failed: \(error)")
        }
    }

    override public static var supportsSecureCoding: Bool {
        true
    }
}
