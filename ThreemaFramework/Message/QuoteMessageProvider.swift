/// Provides the quoted message
public protocol QuoteMessageProvider: BaseMessageEntity {
    /// `QuotedMessage` if it exists, `nil` otherwise
    var quoteMessage: QuoteMessage? { get }
}

/// A quoted message
public protocol QuoteMessage: PreviewableMessage {
    /// Readable name of the author of the quoted message.
    var localizedSenderName: String { get }
    /// ID Color of the sender
    var senderIDColor: UIColor { get }
}
