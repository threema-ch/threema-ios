import Foundation
import ThreemaProtocols

@objc public final class WebSessionResumeMessage: AbstractMessage {
    override public func type() -> UInt8 {
        UInt8(MSGTYPE_WORK_SYNC_DELTA)
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

    override public func canShowUserNotification() -> Bool {
        false
    }

    override public func noDeliveryReceiptFlagSet() -> Bool {
        true
    }

    override public func isContentValid() -> Bool {
        true
    }

    override public static var supportsSecureCoding: Bool {
        true
    }
}
