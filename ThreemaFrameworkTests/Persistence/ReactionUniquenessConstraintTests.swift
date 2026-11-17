import CoreData
import Foundation
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@Suite("Reaction uniqueness constraint")
struct ReactionUniquenessConstraintTests {

    @Test("No entity constrains uniqueness over a relationship", arguments: [
        DatabaseManager.databaseModelName,
        DatabaseManager.databaseEncryptedModelName,
    ])
    func noUniquenessConstraintOverRelationships(modelName: String) throws {
        let model = try #require(DatabaseContextMock.managedObjectModel(name: modelName))

        for entity in model.entities {
            let relationshipNames = Set(entity.relationshipsByName.keys)

            for constraint in entity.uniquenessConstraints {
                let constrained = Set(constraint.compactMap { $0 as? String })
                let overRelationships = constrained.intersection(relationshipNames)

                #expect(
                    overRelationships.isEmpty,
                    Comment(rawValue: "\(entity.name ?? "?") constrains \(overRelationships.sorted())")
                )
            }
        }
    }

    @Test("Saving the same reaction twice no longer traps", arguments: [false, true])
    func duplicateReactionSaves(encrypted: Bool) throws {
        let testDatabase = TestDatabase(encrypted: encrypted)
        // Saves directly to the store, which is where the uniqueness conflict detection runs. A child context would
        // only push into its parent. Private queue, so this does not save on the main queue.
        let context = ThreemaManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = testDatabase.context.main.persistentStoreCoordinator
        context.mergePolicy = NSMergePolicy.overwrite
        let preparer = TestDatabasePreparer(context: context)

        let (contact, message) = preparer.save { () -> (ContactEntity, TextMessageEntity) in
            let contact = preparer.createContact(identity: "MEMBERBB")
            let conversation = preparer.createConversation(groupID: BytesUtility.generateGroupID())
            conversation.members = [contact]

            let message = preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contact,
                remoteSentDate: .now
            )

            _ = MessageReactionEntity(context: context, reaction: "😀", contact: contact, message: message)

            return (contact, message)
        }

        // Same triple as above, which used to crash in Core Data's uniqueness conflict detection
        try context.performAndWait {
            _ = MessageReactionEntity(context: context, reaction: "😀", contact: contact, message: message)
            try context.save()
        }

        let reactions = try context.performAndWait {
            try context.fetch(NSFetchRequest<MessageReactionEntity>(entityName: "MessageReaction"))
        }
        #expect(reactions.count == 2)
    }
}
