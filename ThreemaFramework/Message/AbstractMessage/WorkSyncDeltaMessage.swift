import CocoaLumberjackSwift
import Foundation
import SwiftProtobuf
import ThreemaProtocols

@objc public final class WorkSyncDeltaMessage: AbstractMessage {
    public var decoded: CspE2e_WorkSyncDelta?
    
    override public func type() -> UInt8 {
        UInt8(MSGTYPE_WORK_SYNC_DELTA)
    }
    
    override public func allowSendingProfile() -> Bool {
        false
    }

    override public func canCreateConversation() -> Bool {
        false
    }

    override public func needsConversation() -> Bool {
        false
    }

    override public func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        .unspecified
    }
    
    override public func flagShouldPush() -> Bool {
        false
    }
    
    override public func canShowUserNotification() -> Bool {
        false
    }
    
    override public func noDeliveryReceiptFlagSet() -> Bool {
        true
    }
    
    override public func isContentValid() -> Bool {
        decoded != nil
    }
    
    override public func body() -> Data? {
        guard let serializedData = try? decoded?.serializedData()
        else {
            DDLogError("Unable to create ReactionMessage body")
            return nil
        }

        var body = Data()
        body.append(serializedData)

        return body
    }
    
    @objc override public init() {
        super.init()
    }
    
    @objc func fromRawProtoBufMessage(rawProtobufMessage: NSData) throws {
        decoded = try CspE2e_WorkSyncDelta(serializedData: rawProtobufMessage as Data)
    }
    
    private enum CodingKeys: String, CodingKey {
        case cspMessage
    }

    private enum CodingError: Error {
        case decodeObjectFailed, serializedDataFailed
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        do {
            guard let data = coder.decodeObject(of: NSData.self, forKey: CodingKeys.cspMessage.rawValue) else {
                throw CodingError.decodeObjectFailed
            }
            self.decoded = try CspE2e_WorkSyncDelta(serializedBytes: Data(data))
        }
        catch {
            DDLogError("Decoding failed: \(error)")
        }
    }
    
    override public func encode(with coder: NSCoder) {
        super.encode(with: coder)
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
