import Foundation

// MARK: - TextMessageEntity + QuoteMessageProvider

extension TextMessageEntity: QuoteMessageProvider {
    public var quoteMessage: QuoteMessage? {
        guard let quotedMessageID else {
            return nil
        }
        
        return BusinessInjector.ui.entityManager.entityFetcher.message(
            with: quotedMessageID,
            in: conversation
        ) as? QuoteMessage
    }
}

// MARK: - TextMessageEntity + QuoteMessage

extension TextMessageEntity: QuoteMessage { }
