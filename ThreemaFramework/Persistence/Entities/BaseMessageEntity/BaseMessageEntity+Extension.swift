import Foundation

extension BaseMessageEntity {
    public var noDeliveryReceiptFlagSet: Bool {
        guard let flags else {
            return false
        }
        
        return (flags.intValue & BaseMessageFlags.noDeliveryReceipt) != 0
    }
    
    @objc public var wasDeleted: Bool {
        managedObjectContext == nil || isDeleted
    }
    
    public var typeSupportsRemoteDeletion: Bool {
        self is AudioMessageEntity ||
            self is FileMessageEntity ||
            self is ImageMessageEntity ||
            self is VideoMessageEntity ||
            self is LocationMessageEntity ||
            self is TextMessageEntity
    }
    
    // @objc needed for overriding
    @objc public func contentToCheckForMentions() -> String? {
        nil
    }
}
