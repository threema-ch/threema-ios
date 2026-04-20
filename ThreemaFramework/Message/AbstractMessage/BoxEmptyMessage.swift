final class BoxEmptyMessage: AbstractMessage {
    override func type() -> UInt8 {
        UInt8(MSGTYPE_EMPTY)
    }
    
    // No flags
    
    override func flagShouldPush() -> Bool {
        false
    }
    
    override func flagDontQueue() -> Bool {
        false
    }
    
    override func flagDontAck() -> Bool {
        false
    }
    
    override func flagGroupMessage() -> Bool {
        false
    }
    
    override func flagImmediateDeliveryRequired() -> Bool {
        false
    }
    
    override func flagIsVoIP() -> Bool {
        false
    }
    
    override func body() -> Data? {
        // Doesn't contain any content
        Data()
    }
    
    override func canCreateConversation() -> Bool {
        false
    }
    
    override func canUnarchiveConversation() -> Bool {
        false
    }
    
    override func needsConversation() -> Bool {
        false
    }
    
    override func canShowUserNotification() -> Bool {
        false
    }
    
    override func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        // This should always be sent as PFS message. Thus a system message will be posted if an empty message is
        // received without FS and a FS session exists with the sender.
        // Old clients will just drop this as unknown message.
        .V10
    }
    
    override func isContentValid() -> Bool {
        // Every content is valid
        true
    }
    
    // pushNotificationBody left out as this is not needed
    
    override func allowSendingProfile() -> Bool {
        false
    }
    
    // getMessageIDString is a general implementation so no override needed
    
    override func noDeliveryReceiptFlagSet() -> Bool {
        true
    }
    
    // MARK: NSSecureCoding

    override public static var supportsSecureCoding: Bool {
        true
    }
}
