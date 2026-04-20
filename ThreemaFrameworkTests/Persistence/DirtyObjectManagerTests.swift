import CoreData
import Foundation
import Testing
@testable import ThreemaFramework

@Suite("Dirty Object Manager")
struct DirtyObjectManagerTests {
    let userDefaults = UserDefaults(suiteName: "group.ch.threema")!

    @Test("Add and refresh dirty objects with reset cache")
    func addDirtyObjectAndRefresh() async throws {
        // Config
        let testDatabase = TestDatabase()

        let databasePreparer = testDatabase.preparer
        let (contactEntity, conversationEntity, firstBaseMessageEntity, secondBaseMessageEntity) = databasePreparer
            .save {
                let contactEntity = databasePreparer.createContact(identity: "ECHECHO")
                let conversationEntity = databasePreparer.createConversation(contactEntity: contactEntity)
                let firstBaseMessageEntity = databasePreparer.createTextMessage(
                    conversation: conversationEntity,
                    isOwn: false,
                    sender: contactEntity,
                    remoteSentDate: nil
                )
                let secondBaseMessageEntity = databasePreparer.createTextMessage(
                    conversation: conversationEntity,
                    isOwn: false,
                    sender: contactEntity,
                    remoteSentDate: nil
                )

                return (contactEntity, conversationEntity, firstBaseMessageEntity, secondBaseMessageEntity)
            }

        // Act
        let dirtyObjectManager = DirtyObjectManager(
            databaseManager: testDatabase.databaseManagerMock,
            userDefaults: userDefaults
        )

        await confirmation("Test add and refresh dirty objects", expectedCount: 1) { confimation in
            NotificationCenter.default.addObserver(
                forName: DatabaseContext.changedManagedObjects,
                object: nil,
                queue: nil,
                using: { notification in
                    let objectIDs = notification
                        .userInfo?[DatabaseContext.refreshedObjectIDsKey] as? Set<NSManagedObjectID>

                    // Test
                    #expect(objectIDs != nil)
                    #expect(objectIDs?.count == 4)
                    #expect(objectIDs?.contains(contactEntity.objectID) == true)
                    #expect(objectIDs?.contains(conversationEntity.objectID) == true)
                    #expect(objectIDs?.contains(firstBaseMessageEntity.objectID) == true)
                    #expect(objectIDs?.contains(secondBaseMessageEntity.objectID) == true)

                    confimation()
                }
            )

            dirtyObjectManager.markAsDirty(objectID: firstBaseMessageEntity.objectID)
            dirtyObjectManager.markAsDirty(objectID: secondBaseMessageEntity.objectID)
            dirtyObjectManager.refreshDirtyObjects(reset: true)
        }

        #expect(userDefaults.array(forKey: "DBDirtyObjectsKey") == nil)
    }
}
