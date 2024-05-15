//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
        var conversation: Conversation!
        var member03: ContactEntity!
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedMember01,
                verificationLevel: 0
            )
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedMember02,
                verificationLevel: 0
            )
            member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03",
                verificationLevel: 0
            )
            groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = expectedGroupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                    conversation.addMembers([member01, member02])
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
        XCTAssertNil(group.profilePicture)
        XCTAssertEqual(group.conversationCategory, .default)
        XCTAssertEqual(group.conversationVisibility, .default)
        XCTAssertNil(group.lastUpdate)
        XCTAssertNil(group.lastMessageDate)

        // Change group properties in DB

        let dateNow = Date()

        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
        entityManager.performSyncBlockAndSafe {
            let imageData = entityManager.entityCreator.imageData()
            imageData?.data = Data([0])

            let message = entityManager.entityCreator.textMessage(for: conversation, setLastUpdate: true)
            message?.text = "123"
            message?.date = dateNow

            groupEntity.lastPeriodicSync = dateNow
            conversation.groupName = "Test group 123"
            conversation.groupImage = imageData
            conversation.addMembersObject(member03)
            conversation.lastUpdate = dateNow
            conversation.lastMessage = message
            conversation.conversationCategory = .private
            conversation.conversationVisibility = .archived
        }

        // Check changed group properties

        XCTAssertEqual(group.lastPeriodicSync, dateNow)
        XCTAssertEqual(group.allMemberIdentities.count, 4)
        XCTAssertEqual(group.name, "Test group 123")
        XCTAssertNotNil(group.profilePicture)
        XCTAssertEqual(group.conversationCategory, .private)
        XCTAssertEqual(group.conversationVisibility, .archived)
        XCTAssertEqual(group.lastUpdate, dateNow)
        XCTAssertEqual(group.lastMessageDate, dateNow)
    }

    func testGroupIdentityMismatch() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()
        let expectedGroupID = MockData.generateGroupID()

        // Setup initial group in DB
        var groupEntity: GroupEntity!
        var conversation: Conversation!
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
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        // Check group properties before changing
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.string, myIdentityStoreMock.identity)

        // Change group property `GroupEntity.groupID` in DB
        let entityManager = EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock)
        entityManager.performSyncBlockAndSafe {
            groupEntity.groupID = MockData.generateGroupID()
        }

        // Check changed group properties
        XCTAssertEqual(group.groupIdentity.id, expectedGroupID)
        XCTAssertEqual(group.groupIdentity.creator.string, myIdentityStoreMock.identity)
        XCTAssertTrue(ddLoggerMock.exists(message: "Group identity mismatch"))

        // Change group property `Conversation.groupID` in DB
        entityManager.performSyncBlockAndSafe {
            conversation.groupID = MockData.generateGroupID()
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
        var conversation: Conversation!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER01",
                verificationLevel: 0
            )
            member01.lastName = "Muster"
            member01.firstName = "Hans"
            
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER02",
                verificationLevel: 0
            )
            member02.lastName = "Xmen"
            member02.firstName = "Amy"

            let member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03",
                verificationLevel: 0
            )
            member03.lastName = "Weber"

            let member04 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER04",
                verificationLevel: 0
            )
            member04.firstName = "Fritzli"
            
            let member05 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER05",
                verificationLevel: 0
            )
            let member06 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER06",
                verificationLevel: 0
            )

            let member07 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER07",
                verificationLevel: 0
            )
            member07.lastName = "Weber 2"

            let member08 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER08",
                verificationLevel: 0
            )
            member08.firstName = "Fritzli 2"
            
            let groupID = MockData.generateGroupID()

            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: "MEMBER03")
            conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.contact = member03
                    conversation
                        .addMembers([member01, member02, member03, member04, member05, member06, member07, member08])
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
        var conversation: Conversation!
        
        dbPreparer.save {
            let member01 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER01",
                verificationLevel: 0
            )
            member01.firstName = "Em"
            member01.lastName = "il"
            
            let member02 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER02",
                verificationLevel: 0
            )
            member02.firstName = "Emi"
            member02.lastName = "ly"

            let member03 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER03",
                verificationLevel: 0
            )
            member03.firstName = "Emi"
            member03.lastName = "l"
            member03.publicNickname = "Should not matter"

            let member04 = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "MEMBER04",
                verificationLevel: 0
            )
            member04.firstName = "Em"
            member04.lastName = "ily"

            let groupID = MockData.generateGroupID()

            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: "MEMBER03")
            conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.contact = member03
                    conversation.addMembers([member01, member02, member03, member04])
                    conversation.groupID = groupID
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
            )
        }
        
        let expectedOrder = [
            "MEMBER03", // Emi l (Creator)
            "ECHOECHO", // Me
            "MEMBER01", // Em il
            "MEMBER04", // Em ily
            "MEMBER02", // Emi ly
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
    
    func testSortedFirstNameMembersMeCreator() throws {
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
            identity: "MEMBER01",
            verificationLevel: 0
        )
        member01.lastName = "Muster"
        member01.firstName = "Hans"
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER02",
            verificationLevel: 0
        )
        member02.lastName = "Xmen"
        member02.firstName = "Amy"
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
        var group: Group?

        let expec = expectation(description: "Create group")

        groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.identity).compactMap { $0 }),
            systemMessageDate: Date(),
            sourceCaller: .local
        )
        .done { grp in
            group = grp
            expec.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
            expec.fulfill()
        }

        wait(for: [expec], timeout: 3)

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

    func testSortedLastNameMembersMeCreator() throws {
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
            identity: "MEMBER01",
            verificationLevel: 0
        )
        member01.lastName = "Muster"
        member01.firstName = "Hans"
        members.append(member01)

        let member02 = dbPreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: "MEMBER02",
            verificationLevel: 0
        )
        member02.lastName = "Xmen"
        member02.firstName = "Amy"
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
        var group: Group?

        let expec = expectation(description: "Create group")

        groupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set(members.map(\.identity).compactMap { $0 }),
            systemMessageDate: Date(),
            sourceCaller: .local
        )
        .done { grp in
            group = grp
            expec.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
            expec.fulfill()
        }

        wait(for: [expec], timeout: 3)

        guard let grp = group else {
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
        let sortedContactsLastName = grp.sortedMembers

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
                        identity: member,
                        verificationLevel: kVerificationLevelUnverified
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
                    identity: "MEMBER03",
                    verificationLevel: kVerificationLevelUnverified
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
                        identity: member,
                        verificationLevel: kVerificationLevelUnverified
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
        em.performBlockAndWait {
            em.entityDestroyer.deleteObject(object: groupEntity)
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
                        identity: member,
                        verificationLevel: kVerificationLevelUnverified
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
        em.performBlockAndWait {
            em.entityDestroyer.deleteObject(object: conversation)
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
    ) -> (conversation: Conversation, groupEntity: GroupEntity) {

        var conversation: Conversation!
        var groupEntity: GroupEntity!

        dbPreparer.save {
            let groupID = groupID
            groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: nil)
            conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = groupID
                    conversation.groupMyIdentity = myIdentity
                    conversation.addMembers(members)
                }
        }

        return (conversation, groupEntity)
    }
}
