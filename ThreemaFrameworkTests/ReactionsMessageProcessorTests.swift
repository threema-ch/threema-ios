import Foundation
import Testing
import ThreemaEssentials

@testable import ThreemaFramework

// The tests operate directly on a `mainQueueConcurrencyType` Core Data context (see `DatabaseContextMock`), so the
// whole suite must run on the main thread. See `PersistenceMigrationTests` for the full reasoning.
@MainActor
@Suite("Reactions message processor tests")
struct ReactionsMessageProcessorTests {

    @Test("A legacy ack or dec is stored as read, because it never shows a notification", arguments: [true, false])
    func legacyReactionIsRead(ack: Bool) throws {
        let testDatabase = TestDatabase()
        let dbPreparer = testDatabase.preparer

        let message = dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO"
            )
            let conversation = dbPreparer.createConversation(contactEntity: contact)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }

        let entityManager = testDatabase.entityManager
        let processor = ReactionsMessageProcessor(
            entityManager: entityManager,
            messageProcessorDelegate: MessageProcessorDelegateMock()
        )

        // Sent by somebody else, so it would have been unread before
        try entityManager.performAndWaitSave {
            try processor.handleLegacyReaction(ack: ack, date: .now, messageID: message.objectID, sender: "ECHOECHO")
        }

        let reactions = try #require(entityManager.entityFetcher.messageReactionEntities(for: message))
        #expect(reactions.count == 1)
        #expect(reactions.first?.reaction == (ack ? "👍" : "👎"))
        #expect(reactions.first?.readAt != nil)

        // Thus it can't end up in the notification about the next actual reaction to the message
        let unreadReactions = try #require(entityManager.entityFetcher.unreadMessageReactionEntities(for: message))
        #expect(unreadReactions.isEmpty)
    }
}
