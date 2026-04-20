import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class GroupTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.preparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testSaveAndImplicitReload() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()
        let expectedGroupID = BytesUtility.generateGroupID()
        let expectedMember01 = "MEMBER01"
        let expectedMember02 = "MEMBER02"

        // Setup initial group in DB

        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        var member03: ContactEntity!
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedMember01
            )
            let member02 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedMember02
            )
            member03 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER03"
            )
            groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = expectedGroupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                    conversation.members?.formUnion([member01, member02])
                }
        }

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        // Check group properties before changing

        XCTAssertNil(group.lastPeriodicSync)
        XCTAssertEqual(group.allMemberIdentities.count, 3)
        XCTAssertNil(group.name)
        XCTAssertNil(group.old_ProfilePicture)
        XCTAssertEqual(group.conversationCategory, ConversationEntity.Category.default)
        XCTAssertEqual(group.conversationVisibility, ConversationEntity.Visibility.default)
        XCTAssertNil(group.lastUpdate)
        XCTAssertNil(group.lastMessageDate)

        // Change group properties in DB

        let dateNow = Date()

        let entityManager = testDatabase.entityManager
        entityManager.performAndWaitSave {
            let imageData = entityManager.entityCreator.imageDataEntity(data: Data([0]), size: .zero)

            let message = entityManager.entityCreator.textMessageEntity(
                text: "123",
                in: conversation,
                setLastUpdate: true
            )
            message.date = dateNow

            groupEntity.lastPeriodicSync = dateNow
            conversation.groupName = "Test group 123"
            conversation.groupImage = imageData
            conversation.members?.insert(member03)
            conversation.lastUpdate = dateNow
            conversation.lastMessage = message
            conversation.changeCategory(to: .private)
            conversation.changeVisibility(to: .archived)
        }

        // Check changed group properties

        XCTAssertEqual(group.lastPeriodicSync, dateNow)
        XCTAssertEqual(group.allMemberIdentities.count, 4)
        XCTAssertEqual(group.name, "Test group 123")
        XCTAssertNotNil(group.old_ProfilePicture)
        XCTAssertEqual(group.conversationCategory, ConversationEntity.Category.private)
        XCTAssertEqual(group.conversationVisibility, ConversationEntity.Visibility.archived)
        XCTAssertEqual(group.lastUpdate, dateNow)
        XCTAssertEqual(group.lastMessageDate, dateNow)
    }

    func testGroupIdentityMismatch() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()
        let expectedGroupID = BytesUtility.generateGroupID()

        // Setup initial group in DB
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        dbPreparer.save {
            groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = expectedGroupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
        }

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        // Check group properties before changing
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.rawValue, myIdentityStoreMock.identity)

        // Change group property `GroupEntity.groupId` in DB
        let entityManager = testDatabase.entityManager
        entityManager.performAndWaitSave {
            groupEntity.groupID = BytesUtility.generateGroupID()
        }

        // Check changed group properties
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.rawValue, myIdentityStoreMock.identity)
        XCTAssertTrue(ddLoggerMock.exists(message: "Group identity mismatch"))

        // Change group property `Conversation.groupID` in DB
        entityManager.performAndWaitSave {
            conversation.groupID = BytesUtility.generateGroupID()
        }

        // Check changed group properties
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.rawValue, myIdentityStoreMock.identity)
        XCTAssertTrue(ddLoggerMock.exists(message: "Group ID mismatch"))
    }

    func testSortedMembers() throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: BytesUtility.generatePublicKey()
        )
        
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER01"
            )
            member01.setLastName(to: "Muster", sortOrderFirstName: true)
            member01.setFirstName(to: "Hans", sortOrderFirstName: true)

            let member02 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER02"
            )
            member02.setLastName(to: "Xmen", sortOrderFirstName: true)
            member02.setFirstName(to: "Amy", sortOrderFirstName: true)

            let member03 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER03"
            )
            member03.setLastName(to: "Weber", sortOrderFirstName: true)

            let member04 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER04"
            )
            member04.setFirstName(to: "Fritzli", sortOrderFirstName: true)

            let member05 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER05"
            )
            let member06 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER06"
            )

            let member07 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER07"
            )
            member07.setLastName(to: "Weber 2", sortOrderFirstName: true)

            let member08 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER08"
            )
            member08.setFirstName(to: "Fritzli 2", sortOrderFirstName: true)
            
            let groupID = BytesUtility.generateGroupID()

            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: "MEMBER03")
            conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.contact = member03
                    conversation.members?.formUnion([
                        member01,
                        member02,
                        member03,
                        member04,
                        member05,
                        member06,
                        member07,
                        member08,
                    ])
                    conversation.groupID = groupID
                }
            )
        }
        
        let expectedOrderFirstName = [
            "MEMBER03", // Weber (Creator)
            "MEMBER02", // Amy Xmen
            "MEMBER04", // Fritzli
            "MEMBER08", // Fritzli 2
            "MEMBER01", // Hans Muster
            "MEMBER07", // Weber 2
            "MEMBER05", // MEMBER05
            "MEMBER06", // MEMBER06
        ]
        
        let expectedOrderLastName = [
            "MEMBER03", // Weber (Creator)
            "MEMBER04", // Fritzli
            "MEMBER08", // Fritzli 2
            "MEMBER01", // Muster Hans
            "MEMBER07", // Weber 2
            "MEMBER02", // Xmen Amy
            "MEMBER05", // MEMBER05
            "MEMBER06", // MEMBER06
        ]
        
        let userSettingsMock = UserSettingsMock()

        // Run first name order
        
        let groupSortedFirstName = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )
        let sortedContactsFirstName = groupSortedFirstName.sortedMembers
        
        // Validate
        XCTAssertEqual(expectedOrderFirstName.count, sortedContactsFirstName.count)
        for (expectedContactID, actualContact) in zip(expectedOrderFirstName, sortedContactsFirstName) {
            switch actualContact {
            case let .contact(contact):
                XCTAssertEqual(expectedContactID, contact.identity.rawValue)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
        
        // Run last name order
        
        userSettingsMock.sortOrderFirstName = false
        let groupSortedLastName = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )
        let sortedContactsLastName = groupSortedLastName.sortedMembers
        
        // Validate
        XCTAssertEqual(expectedOrderLastName.count, sortedContactsLastName.count)
        for (expectedContactID, actualContact) in zip(expectedOrderLastName, sortedContactsLastName) {
            switch actualContact {
            case let .contact(contact):
                XCTAssertEqual(expectedContactID, contact.identity.rawValue)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
    }

    func testSortedMembersWithMe() {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: BytesUtility.generatePublicKey()
        )
        
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER01"
            )
            member01.setFirstName(to: "Em", sortOrderFirstName: true)
            member01.setLastName(to: "il", sortOrderFirstName: true)

            let member02 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER02"
            )
            member02.setFirstName(to: "Emi", sortOrderFirstName: true)
            member02.setLastName(to: "ly", sortOrderFirstName: true)

            let member03 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER03"
            )
            member03.setFirstName(to: "Emi", sortOrderFirstName: true)
            member03.setLastName(to: "l", sortOrderFirstName: true)
            member03.publicNickname = "Should not matter"

            let member04 = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: "MEMBER04"
            )
            member04.setFirstName(to: "Em", sortOrderFirstName: true)
            member04.setLastName(to: "ily", sortOrderFirstName: true)

            let groupID = BytesUtility.generateGroupID()

            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: "MEMBER03")
            conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.contact = member03
                    conversation.members?.formUnion([member01, member02, member03, member04])
                    conversation.groupID = groupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
            )
        }
        
        let expectedOrder = [
            "MEMBER03", // Emi l (Creator)
            "MEMBER01", // Em il
            "MEMBER04", // Em ily
            "MEMBER02", // Emi ly
            "ECHOECHO", // Me
        ]
        
        // Run
        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )
        let sortedContacts = group.sortedMembers

        // Validate
        XCTAssertEqual(expectedOrder.count, sortedContacts.count)
        for (expectedContactID, actualContact) in zip(expectedOrder, sortedContacts) {
            switch actualContact {
            case .me:
                XCTAssertEqual(expectedContactID, myIdentityStoreMock.identity)
            case let .contact(contact):
                XCTAssertEqual(expectedContactID, contact.identity.rawValue)
            default:
                XCTFail("Unexpected contact in sorted contacts: \(actualContact)")
            }
        }
    }
    
    func testSortedFirstNameMembersMeCreator() async throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: BytesUtility.generatePublicKey()
        )
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let taskManagerMock = TaskManagerMock()
        let userSettings = UserSettingsMock()
        let groupPhotoSenderMock = GroupPhotoSenderMock()

        var members = [ContactEntity]()

        let member01 = dbPreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: "MEMBER01"
        )
        member01.setLastName(to: "Muster", sortOrderFirstName: true)
        member01.setFirstName(to: "Hans", sortOrderFirstName: true)
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: "MEMBER02"
        )
        member02.setLastName(to: "Xmen", sortOrderFirstName: true)
        member02.setFirstName(to: "Amy", sortOrderFirstName: true)
        members.append(member02)

        let groupManager = GroupManager(
            myIdentityStore: myIdentityStoreMock,
            contactStore: contactStoreMock,
            taskManager: taskManagerMock,
            userSettings: userSettings,
            entityManager: testDatabase.entityManager,
            groupPhotoSender: {
                groupPhotoSenderMock
            }
        )

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )

        let group = try await groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.identity).compactMap { $0 }),
            systemMessageDate: Date(),
            sourceCaller: .local
        )

        guard let group else {
            XCTFail("Group create failed")
            return
        }

        let expectedOrderFirstName = [
            "ECHOECHO", // Me (Creator)
            "MEMBER02", // Amy Xmen
            "MEMBER01", // Hans Muster
        ]

        // Run first name order

        let sortedContactsFirstName = group.sortedMembers

        // Validate
        XCTAssertEqual(expectedOrderFirstName.count, sortedContactsFirstName.count)
        for (expectedContactID, actualContact) in zip(expectedOrderFirstName, sortedContactsFirstName) {
            switch actualContact {
            case .me:
                XCTAssertEqual(expectedContactID, myIdentityStoreMock.identity)
            case let .contact(contact):
                XCTAssertEqual(expectedContactID, contact.identity.rawValue)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
    }

    func testSortedLastNameMembersMeCreator() async throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: BytesUtility.generatePublicKey()
        )
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let taskManagerMock = TaskManagerMock()
        let userSettings = UserSettingsMock()
        userSettings.sortOrderFirstName = false
        let groupPhotoSenderMock = GroupPhotoSenderMock()

        var members = [ContactEntity]()

        let member01 = dbPreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: "MEMBER01"
        )
        member01.setLastName(to: "Muster", sortOrderFirstName: true)
        member01.setFirstName(to: "Hans", sortOrderFirstName: true)
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: BytesUtility.generatePublicKey(),
            identity: "MEMBER02"
        )
        member02.setLastName(to: "Xmen", sortOrderFirstName: true)
        member02.setFirstName(to: "Amy", sortOrderFirstName: true)
        members.append(member02)

        let groupManager = GroupManager(
            myIdentityStore: myIdentityStoreMock,
            contactStore: contactStoreMock,
            taskManager: taskManagerMock,
            userSettings: userSettings,
            entityManager: testDatabase.entityManager,
            groupPhotoSender: {
                groupPhotoSenderMock
            }
        )

        let groupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )

        let group = try await groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.identity).compactMap { $0 }),
            systemMessageDate: Date(),
            sourceCaller: .local
        )

        guard let group else {
            XCTFail("Group create failed")
            return
        }

        let expectedOrderLastName = [
            "ECHOECHO", // Me (Creator)
            "MEMBER01", // Hans Muster
            "MEMBER02", // Amy Xmen
        ]

        // Run last name order

        userSettings.sortOrderFirstName = false
        let sortedContactsLastName = group.sortedMembers

        // Validate
        XCTAssertEqual(expectedOrderLastName.count, sortedContactsLastName.count)
        for (expectedContactID, actualContact) in zip(expectedOrderLastName, sortedContactsLastName) {
            switch actualContact {
            case .me:
                XCTAssertEqual(expectedContactID, myIdentityStoreMock.identity)
            case let .contact(contact):
                XCTAssertEqual(expectedContactID, contact.identity.rawValue)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
    }

    func testEqualTo() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        var members = Set<ContactEntity>()
        dbPreparer.save {
            for member in ["MEMBER01", "MEMBER02"] {
                members.insert(
                    dbPreparer.createContact(
                        publicKey: BytesUtility.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let expectedGroupID = BytesUtility.generateGroupID()
        let (conversation1, groupEntity1) = createGroupInDB(
            groupID: expectedGroupID,
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        dbPreparer.save {
            members.insert(
                dbPreparer.createContact(
                    publicKey: BytesUtility.generatePublicKey(),
                    identity: "MEMBER03"
                )
            )
        }
        let (conversation2, groupEntity2) = createGroupInDB(
            groupID: expectedGroupID,
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let (conversation3, groupEntity3) = createGroupInDB(
            groupID: BytesUtility.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let g1 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity1,
            conversation: conversation1,
            lastSyncRequest: nil
        )

        let g2 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity2,
            conversation: conversation2,
            lastSyncRequest: nil
        )

        let g3 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity3,
            conversation: conversation3,
            lastSyncRequest: nil
        )

        let g4 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity3,
            conversation: conversation3,
            lastSyncRequest: nil
        )

        XCTAssertFalse(g1.isEqual(to: g2), "Members are different")
        XCTAssertFalse(g2.isEqual(to: g3), "Group ID is different")
        XCTAssertTrue(g3.isEqual(to: g4))
    }

    func testDeleteGroupEntity() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        var members = Set<ContactEntity>()
        dbPreparer.save {
            for member in ["MEMBER01", "MEMBER02"] {
                members.insert(
                    dbPreparer.createContact(
                        publicKey: BytesUtility.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let (conversation, groupEntity) = createGroupInDB(
            groupID: BytesUtility.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        XCTAssertFalse(group.willBeDeleted)

        let em = testDatabase.entityManager
        em.performAndWait {
            em.entityDestroyer.delete(groupEntity: groupEntity)
        }

        let expect = expectation(description: "Give time for deletion")
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 2)

        XCTAssertTrue(group.willBeDeleted)
    }

    func testDeleteConversation() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        var members = Set<ContactEntity>()
        dbPreparer.save {
            for member in ["MEMBER01", "MEMBER02"] {
                members.insert(
                    dbPreparer.createContact(
                        publicKey: BytesUtility.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let (conversation, groupEntity) = createGroupInDB(
            groupID: BytesUtility.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        XCTAssertFalse(group.willBeDeleted)

        let em = testDatabase.entityManager
        em.performAndWait {
            em.entityDestroyer.delete(conversation: conversation)
        }

        let expect = expectation(description: "Give time for deletion")
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 2)

        XCTAssertTrue(group.willBeDeleted)
    }

    private func createGroupInDB(
        groupID: Data,
        members: Set<ContactEntity>,
        myIdentity: String
    ) -> (conversation: ConversationEntity, groupEntity: GroupEntity) {

        var conversation: ConversationEntity!
        var groupEntity: GroupEntity!

        dbPreparer.save {
            let groupID = groupID
            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: nil)
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = groupID
                    conversation.groupMyIdentity = myIdentity
                    conversation.members?.formUnion(members)
                }
        }

        return (conversation, groupEntity)
    }
}
