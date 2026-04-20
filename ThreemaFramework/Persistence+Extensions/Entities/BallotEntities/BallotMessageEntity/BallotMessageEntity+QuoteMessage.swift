import Foundation

// MARK: - BallotMessageEntity + QuoteMessageProvider

extension BallotMessageEntity: QuoteMessageProvider {
    public var quoteMessage: QuoteMessage? {
        if isSummaryMessage() {
            self
        }
        else {
            nil
        }
    }
}

// MARK: - BallotMessageEntity + QuoteMessage

extension BallotMessageEntity: QuoteMessage { }
