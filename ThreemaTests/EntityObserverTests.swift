//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class EntityObserverTests: XCTestCase {

    private var myIdentityStoreMock: MyIdentityStoreMock!

    private var mainCnx: NSManagedObjectContext!
    private var backgroundCnx: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        myIdentityStoreMock = MyIdentityStoreMock()

        (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
    }

    func testWithoutBusinessAbstraction() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: mainCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        let entityManager = EntityManager(databaseContext: dbCnx, myIdentityStore: myIdentityStoreMock)
        let conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {

            var expects = [XCTestExpectation]()

            var groupNameChanged: String?
            var groupNameChangedCount = 0

            for i in 0...399 {
                let expect = expectation(description: "group name changed \(i)")

                var observer: NSKeyValueObservation?
                observer = conversation?.observe(\.groupName, options: [.new, .old]) { _, value in
                    var hasValueChanged = false

                    entityManager.performSyncBlockAndSafe {
                        guard !value.isPrior else {
                            return
                        }
                        guard value.newValue != "GRP1" else {
                            return
                        }
                        hasValueChanged = true

                        if let c = entityManager.entityFetcher
                            .getManagedObject(by: conversation?.objectID) as? Conversation {
                            groupNameChanged = c.groupName
                            groupNameChangedCount += 1
                        }
                    }

                    if hasValueChanged {
                        observer?.invalidate()
                        expect.fulfill()
                    }
                }
                expects.append(expect)
            }

            startMeasuring()
            entityManager.performSyncBlockAndSafe {
                if let c = entityManager.entityFetcher
                    .getManagedObject(by: conversation?.objectID) as? Conversation {
                    c.groupName = "GRP2"
                }
            }

            wait(for: expects, timeout: 6)
            stopMeasuring()

            XCTAssertEqual("GRP2", groupNameChanged)
            XCTAssertEqual(groupNameChangedCount, 400)
        }
    }

    func testBusinessAbstraction() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: mainCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        let entityManager = EntityManager(databaseContext: dbCnx, myIdentityStore: myIdentityStoreMock)
        let conversation: Conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )!

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            var expects = [XCTestExpectation]()
            var subscriptionTokens = [EntityObserver.SubscriptionToken]()

            var groupNameChanged: String?
            var groupNameChangedCount = 0

            for i in 0...399 {
                let expect = expectation(description: "group name changed \(i)")

                subscriptionTokens.append(EntityObserver.shared.subscribe(
                    managedObject: conversation,
                    for: [.updated]
                ) { managedObject, _ in
                    groupNameChanged = (managedObject as? Conversation)?.groupName
                    groupNameChangedCount += 1

                    expect.fulfill()
                })

                expects.append(expect)
            }

            startMeasuring()
            entityManager.performSyncBlockAndSafe {
                if let c = entityManager.entityFetcher
                    .getManagedObject(by: conversation.objectID) as? Conversation {
                    c.groupName = "GRP2"
                }
            }

            wait(for: expects, timeout: 6)
            stopMeasuring()

            // Remove (deallocate) tokens to remove subscriber
            subscriptionTokens.removeAll()

            XCTAssertEqual("GRP2", groupNameChanged)
            XCTAssertEqual(groupNameChangedCount, 400)
        }
    }

    func testBusinessAbstractionDeleteManagedObject() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: mainCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        let entityManager = EntityManager(databaseContext: dbCnx, myIdentityStore: myIdentityStoreMock)
        let conversation: Conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )!

        var expectedDeletedManagedObject: NSManagedObject?
        var expectedReason: EntityObserver.EntityChangedReason?

        let expect = expectation(description: "conversation delete")

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.deleted]
        ) { managedObject, reason in
            expectedDeletedManagedObject = managedObject
            expectedReason = reason

            expect.fulfill()
        }

        entityManager.performSyncBlockAndSafe {
            entityManager.entityDestroyer.deleteObject(object: conversation)
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(expectedDeletedManagedObject?.objectID, conversation.objectID)
        XCTAssertEqual(expectedReason, .deleted)
    }

    func testBusinessAbstractionDeleteManagedObjectOnPrivateContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: backgroundCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        let entityManager = EntityManager(databaseContext: dbCnx, myIdentityStore: myIdentityStoreMock)
        let conversation: Conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )!

        var expectedDeletedManagedObject: NSManagedObject?
        var expectedReason: EntityObserver.EntityChangedReason?

        let expect = expectation(description: "conversation delete")
        expect.assertForOverFulfill = false

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.deleted]
        ) { managedObject, reason in
            expectedDeletedManagedObject = managedObject
            expectedReason = reason

            expect.fulfill()
        }

        entityManager.performSyncBlockAndSafe {
            entityManager.entityDestroyer.deleteObject(object: conversation)
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(expectedDeletedManagedObject?.objectID, conversation.objectID)
        XCTAssertEqual(expectedReason, .deleted)
    }

    func testBusinessAbstractionChangeManagedObjectOnDifferentContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: mainCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
        let conversation: Conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )!

        var groupNameChanged: String? = conversation.groupName

        let expect = expectation(description: "conversation change")

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.updated]
        ) { managedObject, _ in
            groupNameChanged = (managedObject as? Conversation)?.groupName

            expect.fulfill()
        }

        let dbPrivateCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        let backgroundEntityManager = EntityManager(
            databaseContext: dbPrivateCnx,
            myIdentityStore: myIdentityStoreMock
        )

        DispatchQueue.global(qos: .default).async {
            backgroundEntityManager.performSyncBlockAndSafe {
                let conversation: Conversation = backgroundEntityManager.entityFetcher.conversation(
                    for: groupID,
                    creator: groupCreatorIdentity
                )!
                conversation.groupName = "GRP2"
            }
        }

        wait(for: [expect], timeout: 3)

        // Saving GroupEntity on private context will be saved object also on main context
        XCTAssertEqual(groupNameChanged, "GRP2")
    }

    func testBusinessAbstractionChangeManagedObjectOnPrivateContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        let dbPreparer = DatabasePreparer(context: backgroundCnx)
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let dbCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        let entityManager = EntityManager(databaseContext: dbCnx, myIdentityStore: myIdentityStoreMock)
        let conversation: Conversation = entityManager.entityFetcher.conversation(
            for: groupID,
            creator: groupCreatorIdentity
        )!

        var groupNameChanged: String? = conversation.groupName

        let expect = expectation(description: "conversation change")

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.updated]
        ) { managedObject, _ in
            groupNameChanged = (managedObject as? Conversation)?.groupName

            // Fullfill only on main context
            if managedObject?.managedObjectContext?.parent == nil {
                expect.fulfill()
            }
        }

        entityManager.performSyncBlockAndSafe {
            let conversation: Conversation = entityManager.entityFetcher.conversation(
                for: groupID,
                creator: groupCreatorIdentity
            )!
            conversation.groupName = "GRP2"
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(groupNameChanged, "GRP2")
    }
}
