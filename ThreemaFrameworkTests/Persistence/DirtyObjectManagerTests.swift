//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CoreData
import Foundation
import Testing
@testable import ThreemaFramework

@Suite("Dirty Object Manager")
struct DirtyObjectManagerTests {
    let appGroupID = "group.ch.threema"
    let userDefaults = UserDefaults(suiteName: "group.ch.threema")!

    @Test("Add and refresh dirty objects with reset cache")
    func addDirtyObjectAndRefresh() async throws {
        // Config
        let (persistentStoreCoordinator, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: false)

        let databasePreparer = DatabasePreparer(context: mainCnx)
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

        // Mock
        let databaseManagerMock = DatabaseManagerMock(
            persistentStoreCoordinator: persistentStoreCoordinator,
            databaseContext: DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        )

        // Act
        let dirtyObjectManager = DirtyObjectManager(
            databaseManager: databaseManagerMock,
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
