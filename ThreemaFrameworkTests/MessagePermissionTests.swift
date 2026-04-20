import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class MessagePermissionTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var myIdentityStoreMock: MyIdentityStoreMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.preparer

        myIdentityStoreMock = MyIdentityStoreMock(
            identity: "IDENTITY",
            secretKey: BytesUtility.generateRandomBytes(length: Int(32))!
        )
    }

    override func tearDownWithError() throws { }

    func testCanSendToIdentityAllowed() throws {
        let toIdentity = "TESTER01"

        dbPreparer.save {
            let dbContatct = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: toIdentity
            )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContatct
                }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(to: toIdentity)

        XCTAssertTrue(result.isAllowed)
        XCTAssertNil(result.reason)
    }

    func testCanSendToIdentityBlocked() throws {
        let toIdentity = "TESTER01"

        dbPreparer.save {
            let dbContatct = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: toIdentity
            )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContatct
                }
        }

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blacklist = [toIdentity]

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(to: toIdentity)

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("contact_blocked_cannot_send", result.reason)
    }

    func testCanSendToIdentityAllowedObjc() throws {
        let toIdentity = "TESTER01"

        dbPreparer.save {
            let dbContatct = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: toIdentity
            )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContatct
                }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager
        )
        
        let reason = UnsafeMutablePointer<NSString?>.allocate(capacity: 2048)
        var string: NSString?
        reason.initialize(from: &string, count: 1)
        defer {
            reason.deallocate()
        }

        let isAllowed = mp.canSend(to: toIdentity, reason: reason)

        XCTAssertTrue(isAllowed)
        XCTAssertNil(reason.pointee)
    }

    func testCanSendToIdentityBlockedObjc() throws {
        let toIdentity = "TESTER01"

        dbPreparer.save {
            let dbContact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: toIdentity
            )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContact
                }
        }

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blacklist = [toIdentity]

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager
        )

        let reason = UnsafeMutablePointer<NSString?>.allocate(capacity: 2048)
        var string: NSString?
        reason.initialize(from: &string, count: 1)
        defer {
            reason.deallocate()
        }

        let isAllowed = mp.canSend(to: toIdentity, reason: reason)

        XCTAssertFalse(isAllowed)
        XCTAssertEqual("contact_blocked_cannot_send", reason.pointee)
    }

    func testCanSendToIdentityInvalidContact() throws {
        let toIdentity = "TESTER01"

        dbPreparer.save {
            let dbContact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: toIdentity
            )
            dbContact.contactState = .invalid
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContact
                }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(to: toIdentity)

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("contact_invalid_cannot_send", result.reason)
    }

    func testCanSendToGroupDifferentGroupMyIdentity() throws {
        let oldGroupMyIdentity = "MYOLDID1"
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!

        var group: Group!

        dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil
            )
            let dbConversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.groupID = groupEntity.groupID
                    dbConversation.groupMyIdentity = oldGroupMyIdentity
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: groupEntity,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        groupManagerMock.getGroupReturns.append(group)

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(
            groudID: groupID,
            groupCreatorIdentity: myIdentityStoreMock.identity
        )

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("group_different_identity", result.reason)
    }

    func testCanSendToGroupNoMembers() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"

        var group: Group!

        dbPreparer.save {
            let dbContactGroupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: groupCreatorIdentity
            )
            let dbGroup = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: groupCreatorIdentity
            )
            let dbConversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContactGroupCreator
                    dbConversation.groupMyIdentity = self.myIdentityStoreMock.identity
                    dbConversation.groupID = dbGroup.groupID
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(group)

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(groudID: groupID, groupCreatorIdentity: groupCreatorIdentity)

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("no_more_members", result.reason)
    }

    func testCanSendToNoteGroup() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = myIdentityStoreMock.identity

        var group: Group!

        dbPreparer.save {
            let dbGroup = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil
            )
            let dbConversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = nil
                    dbConversation.groupMyIdentity = self.myIdentityStoreMock.identity
                    dbConversation.groupID = dbGroup.groupID
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(group)

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(groudID: groupID, groupCreatorIdentity: groupCreatorIdentity)

        XCTAssertTrue(result.isAllowed)
        XCTAssertNil(result.reason)
    }

    func testCanSendToGroupDidLeaveGroup() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR1"
        let groupMember = "MEMBER01"

        var conversation: ConversationEntity!
        var group: Group!

        dbPreparer.save {
            let dbContactGroupMember = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupMember
            )
            let dbContactGroupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: groupCreatorIdentity
            )
            let dbGroup = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: groupCreatorIdentity
            )
            dbGroup
                .setValue(
                    NSNumber(integerLiteral: 2), // kGroupStateLeft
                    forKey: "state"
                )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { dbConversation in
                    dbConversation.contact = dbContactGroupCreator
                    dbConversation.groupID = dbGroup.groupID
                    dbConversation.members = Set<ContactEntity>([dbContactGroupMember])

                    conversation = dbConversation
                }

            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: dbGroup,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(group)

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager
        )

        let result = mp.canSend(
            groudID: groupID,
            groupCreatorIdentity: groupCreatorIdentity
        )

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("group_is_not_member", result.reason)
    }
}
