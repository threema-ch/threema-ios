import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class EntityObserverTests: XCTestCase {

    private var myIdentityStoreMock: MyIdentityStoreMock!

    private var testDatabase: TestDatabase!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        myIdentityStoreMock = MyIdentityStoreMock()

        testDatabase = TestDatabase()
    }

    func testWithoutBusinessAbstraction() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
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

                    entityManager.performAndWaitSave {
                        guard !value.isPrior else {
                            return
                        }
                        guard value.newValue != "GRP1" else {
                            return
                        }
                        hasValueChanged = true

                        if let c = entityManager.entityFetcher
                            .managedObject(with: conversation!.objectID) as? ConversationEntity {
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
            entityManager.performAndWaitSave {
                if let c = entityManager.entityFetcher
                    .managedObject(with: conversation!.objectID) as? ConversationEntity {
                    c.groupName = "GRP2"
                }
            }

            // TODO: (IOS-3875) Timeout
            wait(for: expects, timeout: 60)
            stopMeasuring()

            XCTAssertEqual("GRP2", groupNameChanged)
            XCTAssertEqual(groupNameChangedCount, 400)
        }
    }

    // TODO: (IOS-3875) Reenable this test
    func testBusinessAbstraction() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
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
                    groupNameChanged = (managedObject as? ConversationEntity)?.groupName
                    groupNameChangedCount += 1

                    expect.fulfill()
                })

                expects.append(expect)
            }

            startMeasuring()
            entityManager.performAndWaitSave {
                if let c = entityManager.entityFetcher
                    .managedObject(with: conversation.objectID) as? ConversationEntity {
                    c.groupName = "GRP2"
                }
            }

            // TODO: (IOS-3875) Timeout
            wait(for: expects, timeout: 60)
            stopMeasuring()

            // Remove (deallocate) tokens to remove subscriber
            subscriptionTokens.removeAll()

            XCTAssertEqual("GRP2", groupNameChanged)
            XCTAssertEqual(groupNameChangedCount, 400)
        }
    }

    func testBusinessAbstractionDeleteManagedObject() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
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

        entityManager.performAndWaitSave {
            entityManager.entityDestroyer.delete(conversation: conversation)
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(expectedDeletedManagedObject?.objectID, conversation.objectID)
        XCTAssertEqual(expectedReason, .deleted)
    }

    func testBusinessAbstractionDeleteManagedObjectOnPrivateContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
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

        entityManager.performAndWaitSave {
            entityManager.entityDestroyer.delete(conversation: conversation)
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(expectedDeletedManagedObject?.objectID, conversation.objectID)
        XCTAssertEqual(expectedReason, .deleted)
    }

    func testBusinessAbstractionChangeManagedObjectOnDifferentContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
        )!

        var groupNameChanged: String? = conversation.groupName

        let expect = expectation(description: "conversation change")

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.updated]
        ) { managedObject, _ in
            groupNameChanged = (managedObject as? ConversationEntity)?.groupName

            expect.fulfill()
        }

        let backgroundEntityManager = testDatabase.backgroundEntityManager

        DispatchQueue.global(qos: .default).async {
            backgroundEntityManager.performAndWaitSave {
                let conversation: ConversationEntity = backgroundEntityManager.entityFetcher.groupConversationEntity(
                    for: groupID,
                    creatorID: groupCreatorIdentity, myIdentity: self.myIdentityStoreMock.identity
                )!
                conversation.groupName = "GRP2"
            }
        }

        wait(for: [expect], timeout: 3)

        // Saving GroupEntity on private context will be saved object also on main context
        XCTAssertEqual(groupNameChanged, "GRP2")
    }

    // TODO: (IOS-3875) Reenable this test
    func testBusinessAbstractionChangeManagedObjectOnPrivateContext() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        let dbPreparer = testDatabase.preparer
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreatorIdentity
            )
            let groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                conversation.contact = contact
                conversation.groupName = "GRP1"
            }
        }

        let entityManager = testDatabase.entityManager
        let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
            for: groupID,
            creatorID: groupCreatorIdentity, myIdentity: myIdentityStoreMock.identity
        )!

        var groupNameChanged: String? = conversation.groupName

        let expect = expectation(description: "conversation change")

        let subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: conversation,
            for: [.updated]
        ) { managedObject, _ in
            groupNameChanged = (managedObject as? ConversationEntity)?.groupName

            // Fulfill only on main context
            if managedObject?.managedObjectContext?.parent == nil {
                expect.fulfill()
            }
        }

        entityManager.performAndWaitSave {
            let conversation: ConversationEntity = entityManager.entityFetcher.groupConversationEntity(
                for: groupID,
                creatorID: groupCreatorIdentity, myIdentity: self.myIdentityStoreMock.identity
            )!
            conversation.groupName = "GRP2"
        }

        wait(for: [expect], timeout: 3)

        XCTAssertEqual(groupNameChanged, "GRP2")
    }
}
