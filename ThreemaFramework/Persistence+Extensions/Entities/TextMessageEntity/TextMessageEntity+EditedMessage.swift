import Foundation

// MARK: - TextMessageEntity + EditedMessageProvider

extension TextMessageEntity: EditedMessageProvider {
    public var editedMessage: EditedMessage? {
        BusinessInjector.ui.entityManager.entityFetcher.message(
            with: id,
            in: conversation
        ) as? EditedMessage
    }
}

// MARK: - TextMessageEntity + EditedMessage

extension TextMessageEntity: EditedMessage { }
