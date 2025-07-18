//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

class GroupTests: XCTestCase {
    
    private var dbMainCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbPreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testSaveAndImplicitReload() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()
        let expectedGroupID = MockData.generateGroupID()
        let expectedMember01 = "MEMBER01"
        let expectedMember02 = "MEMBER02"

        // Setup initial group in DB

        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        var member03: ContactEntity!
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedMember01
            )
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedMember02
            )
            member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03"
            )
            groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = expectedGroupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                    conversation.members?.formUnion([member01, member02])
                }
        }

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
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

        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
        entityManager.performAndWaitSave {
            let imageData = entityManager.entityCreator.imageDataEntity()
            imageData?.data = Data([0])

            let message = entityManager.entityCreator.textMessageEntity(for: conversation, setLastUpdate: true)
            message?.text = "123"
            message?.date = dateNow

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
        let expectedGroupID = MockData.generateGroupID()

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
                    // swiftformat:disable:next acronyms
                    conversation.groupId = expectedGroupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
        }

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        // Check group properties before changing
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.string, myIdentityStoreMock.identity)

        // Change group property `GroupEntity.groupId` in DB
        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
        entityManager.performAndWaitSave {
            // swiftformat:disable:next acronyms
            groupEntity.groupId = MockData.generateGroupID()
        }

        // Check changed group properties
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.string, myIdentityStoreMock.identity)
        XCTAssertTrue(ddLoggerMock.exists(message: "Group identity mismatch"))

        // Change group property `Conversation.groupID` in DB
        entityManager.performAndWaitSave {
            // swiftformat:disable:next acronyms
            conversation.groupId = MockData.generateGroupID()
        }

        // Check changed group properties
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.string, myIdentityStoreMock.identity)
        XCTAssertTrue(ddLoggerMock.exists(message: "Group ID mismatch"))
    }

    func testSortedMembers() throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: MockData.generatePublicKey()
        )
        
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER01"
            )
            member01.setLastName(to: "Muster")
            member01.setFirstName(to: "Hans")
            
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER02"
            )
            member02.setLastName(to: "Xmen")
            member02.setFirstName(to: "Amy")

            let member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03"
            )
            member03.setLastName(to: "Weber")

            let member04 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER04"
            )
            member04.setFirstName(to: "Fritzli")
            
            let member05 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER05"
            )
            let member06 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER06"
            )

            let member07 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER07"
            )
            member07.setLastName(to: "Weber 2")

            let member08 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER08"
            )
            member08.setFirstName(to: "Fritzli 2")
            
            let groupID = MockData.generateGroupID()

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
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
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
                XCTAssertEqual(expectedContactID, contact.identity.string)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
        
        // Run last name order
        
        userSettingsMock.sortOrderFirstName = false
        let groupSortedLastName = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
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
                XCTAssertEqual(expectedContactID, contact.identity.string)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
    }

    func testSortedMembersWithMe() {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: MockData.generatePublicKey()
        )
        
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER01"
            )
            member01.setFirstName(to: "Em")
            member01.setLastName(to: "il")
            
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER02"
            )
            member02.setFirstName(to: "Emi")
            member02.setLastName(to: "ly")

            let member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03"
            )
            member03.setFirstName(to: "Emi")
            member03.setLastName(to: "l")
            member03.publicNickname = "Should not matter"

            let member04 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER04"
            )
            member04.setFirstName(to: "Em")
            member04.setLastName(to: "ily")

            let groupID = MockData.generateGroupID()

            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: "MEMBER03")
            conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.contact = member03
                    conversation.members?.formUnion([member01, member02, member03, member04])
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
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
                XCTAssertEqual(expectedContactID, contact.identity.string)
            default:
                XCTFail("Unexpected contact in sorted contacts: \(actualContact)")
            }
        }
    }
    
    func testSortedFirstNameMembersMeCreator() async throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: MockData.generatePublicKey()
        )
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let taskManagerMock = TaskManagerMock()
        let userSettings = UserSettingsMock()
        let groupPhotoSenderMock = GroupPhotoSenderMock()

        var members = [ContactEntity]()

        let member01 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER01"
        )
        member01.setLastName(to: "Muster")
        member01.setFirstName(to: "Hans")
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER02"
        )
        member02.setLastName(to: "Xmen")
        member02.setFirstName(to: "Amy")
        members.append(member02)

        let groupManager = GroupManager(
            myIdentityStoreMock,
            contactStoreMock,
            taskManagerMock,
            userSettings,
            EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            groupPhotoSenderMock
        )

        let groupIdentity = GroupIdentity(
            id: MockData.generateGroupID(),
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
                XCTAssertEqual(expectedContactID, contact.identity.string)
            default:
                XCTFail("Unexpected contact in sorted contacts")
            }
        }
    }

    func testSortedLastNameMembersMeCreator() async throws {
        let myIdentityStoreMock = MyIdentityStoreMock(
            identity: "ECHOECHO",
            secretKey: MockData.generatePublicKey()
        )
        let contactStoreMock = ContactStoreMock(callOnCompletion: true)
        let taskManagerMock = TaskManagerMock()
        let userSettings = UserSettingsMock()
        userSettings.sortOrderFirstName = false
        let groupPhotoSenderMock = GroupPhotoSenderMock()

        var members = [ContactEntity]()

        let member01 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER01"
        )
        member01.setLastName(to: "Muster")
        member01.setFirstName(to: "Hans")
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER02"
        )
        member02.setLastName(to: "Xmen")
        member02.setFirstName(to: "Amy")
        members.append(member02)

        let groupManager = GroupManager(
            myIdentityStoreMock,
            contactStoreMock,
            taskManagerMock,
            userSettings,
            EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            groupPhotoSenderMock
        )

        let groupIdentity = GroupIdentity(
            id: MockData.generateGroupID(),
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
                XCTAssertEqual(expectedContactID, contact.identity.string)
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
                        publicKey: MockData.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let expectedGroupID = MockData.generateGroupID()
        let (conversation1, groupEntity1) = createGroupInDB(
            groupID: expectedGroupID,
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        dbPreparer.save {
            members.insert(
                dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
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
            groupID: MockData.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let g1 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity1,
            conversation: conversation1,
            lastSyncRequest: nil
        )

        let g2 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity2,
            conversation: conversation2,
            lastSyncRequest: nil
        )

        let g3 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity3,
            conversation: conversation3,
            lastSyncRequest: nil
        )

        let g4 = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
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
                        publicKey: MockData.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let (conversation, groupEntity) = createGroupInDB(
            groupID: MockData.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        XCTAssertFalse(group.willBeDeleted)

        let em = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
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
                        publicKey: MockData.generatePublicKey(),
                        identity: member
                    )
                )
            }
        }

        let (conversation, groupEntity) = createGroupInDB(
            groupID: MockData.generateGroupID(),
            members: members,
            myIdentity: myIdentityStoreMock.identity
        )

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        XCTAssertFalse(group.willBeDeleted)

        let em = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
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
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.groupMyIdentity = myIdentity
                    conversation.members?.formUnion(members)
                }
        }

        return (conversation, groupEntity)
    }
}
