import Foundation
import Testing
import ThreemaEssentials

@testable import ThreemaFramework

// The tests operate directly on a `mainQueueConcurrencyType` Core Data context (see `DatabaseContextMock`), so the
// whole suite must run on the main thread. See `PersistenceMigrationTests` for the full reasoning.
//
// Both flavours of the database are covered, because the `readAt` field is stored encrypted in one of them and the
// queries have to look at the right field.
@MainActor
@Suite("Unread message reactions fetch tests")
struct UnreadMessageReactionsFetchTests {

    @Test("Only reactions without a read date are unread", arguments: [false, true])
    func unreadReactionsOfMessage(encrypted: Bool) throws {
        let testDatabase = TestDatabase(encrypted: encrypted)
        let dbPreparer = testDatabase.preparer

        let message = dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO"
            )
            let conversation = dbPreparer.createConversation(contactEntity: contact)
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )

            dbPreparer.createMessageReactionEntity(message: message, reaction: "🔮", contact: contact)
            dbPreparer.createMessageReactionEntity(message: message, reaction: "❤️", contact: contact)
            // Already seen, thus not unread anymore
            dbPreparer.createMessageReactionEntity(
                message: message,
                reaction: "😂",
                readAt: .now,
                contact: contact
            )

            return message
        }

        let entityManager = testDatabase.entityManager
        let allReactions = try #require(entityManager.entityFetcher.messageReactionEntities(for: message))
        let unreadReactions = try #require(entityManager.entityFetcher.unreadMessageReactionEntities(for: message))

        #expect(allReactions.count == 3)
        #expect(unreadReactions.count == 2)
        #expect(!unreadReactions.contains { $0.reaction == "😂" })
    }

    @Test("Reading a reaction removes it from the unread ones", arguments: [false, true])
    func readingAReaction(encrypted: Bool) throws {
        let testDatabase = TestDatabase(encrypted: encrypted)
        let dbPreparer = testDatabase.preparer

        let message = dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO"
            )
            let conversation = dbPreparer.createConversation(contactEntity: contact)
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )

            dbPreparer.createMessageReactionEntity(message: message, reaction: "🔮", contact: contact)

            return message
        }

        let entityManager = testDatabase.entityManager
        let reaction = try #require(entityManager.entityFetcher.unreadMessageReactionEntities(for: message)?.first)

        dbPreparer.save {
            reaction.readAt = .now
        }

        let remainingReactions = try #require(entityManager.entityFetcher.unreadMessageReactionEntities(for: message))
        #expect(remainingReactions.isEmpty)
    }

    @Test("Unread reactions of a conversation cover all its messages", arguments: [false, true])
    func unreadReactionsOfConversation(encrypted: Bool) throws {
        let testDatabase = TestDatabase(encrypted: encrypted)
        let dbPreparer = testDatabase.preparer

        let conversation = dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO"
            )
            let conversation = dbPreparer.createConversation(contactEntity: contact)

            for index in 0..<2 {
                let message = dbPreparer.createTextMessage(
                    conversation: conversation,
                    text: "Message \(index)",
                    isOwn: true,
                    sender: nil,
                    remoteSentDate: nil
                )
                dbPreparer.createMessageReactionEntity(message: message, reaction: "🔮", contact: contact)
                dbPreparer.createMessageReactionEntity(
                    message: message,
                    reaction: "❤️",
                    readAt: .now,
                    contact: contact
                )
            }

            return conversation
        }

        let entityManager = testDatabase.entityManager
        let unreadReactions = try #require(entityManager.entityFetcher.unreadReactions(in: conversation))

        // One unread reaction per message, the read ones are left out
        #expect(unreadReactions.count == 2)
        #expect(unreadReactions.allSatisfy { $0.reaction == "🔮" })
    }
}
