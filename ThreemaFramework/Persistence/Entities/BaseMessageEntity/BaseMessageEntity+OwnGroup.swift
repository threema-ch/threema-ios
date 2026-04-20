import CocoaLumberjackSwift
import Foundation

extension BaseMessageEntity {
    /// Is this a message I sent?
    public var isOwnMessage: Bool {
        isOwn.boolValue
    }
    
    public var isGroupMessage: Bool {
        conversation.isGroup
    }
}
