/// Provides the quoted message
public protocol EditedMessageProvider: BaseMessageEntity {
    /// `EditedMessage` if it exists, `nil` otherwise
    var editedMessage: EditedMessage? { get }
}

/// A edit message
public protocol EditedMessage: PreviewableMessage {
    /// Readable name of the author of the quoted message.
    var localizedSenderName: String { get }
    /// ID Color of the sender
    var senderIDColor: UIColor { get }
}
