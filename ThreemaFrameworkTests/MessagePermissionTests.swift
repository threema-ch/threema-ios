//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class MessagePermissionTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var myIdentityStoreMock: MyIdentityStoreMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let cnx = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: cnx.mainContext, backgroundContext: nil)
        dbPreparer = DatabasePreparer(context: cnx.mainContext)

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
                identity: toIdentity,
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContatct
            }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
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
                identity: toIdentity,
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContatct
            }
        }

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blacklist = [toIdentity]

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
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
                identity: toIdentity,
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContatct
            }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        let reason = UnsafeMutablePointer<NSString?>.allocate(capacity: 2048)
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
                identity: toIdentity,
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContact
            }
        }

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blacklist = [toIdentity]

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        let reason = UnsafeMutablePointer<NSString?>.allocate(capacity: 2048)
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
                identity: toIdentity,
                verificationLevel: 0
            )
            dbContact.state = NSNumber(integerLiteral: kStateInvalid)
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContact
            }
        }

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
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
            let dbGroup = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil
            )
            let dbConversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                    dbConversation.groupID = dbGroup.groupID
                    dbConversation.groupMyIdentity = oldGroupMyIdentity
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = group

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        let result = mp.canSend(
            groudID: groupID,
            groupCreatorIdentity: oldGroupMyIdentity
        )

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("group_different_identity", result.reason)
    }

    func testCanSendToGroupNoMembers() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"

        var group: Group!

        dbPreparer.save {
            let dbContactGroupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
            )
            let dbGroup = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: groupCreatorIdentity
            )
            let dbConversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                    dbConversation.contact = dbContactGroupCreator
                    dbConversation.groupMyIdentity = self.myIdentityStoreMock.identity
                    dbConversation.groupID = dbGroup.groupID
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = group

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
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
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                    dbConversation.contact = nil
                    dbConversation.groupMyIdentity = self.myIdentityStoreMock.identity
                    dbConversation.groupID = dbGroup.groupID
                }

            group = Group(
                myIdentityStore: myIdentityStoreMock,
                groupEntity: dbGroup,
                conversation: dbConversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = group

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        let result = mp.canSend(groudID: groupID, groupCreatorIdentity: groupCreatorIdentity)

        XCTAssertTrue(result.isAllowed)
        XCTAssertNil(result.reason)
    }

    func testCanSendToGroupDidLeaveGroup() throws {
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreatorIdentity = "CREATOR01"
        let groupMember = "MEMBER01"

        var conversation: Conversation!
        var group: Group!

        dbPreparer.save {
            let dbContactGroupMember = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupMember,
                verificationLevel: 0
            )
            let dbContactGroupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: groupCreatorIdentity,
                verificationLevel: 0
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
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { dbConversation in
                dbConversation.contact = dbContactGroupCreator
                dbConversation.groupID = dbGroup.groupID
                dbConversation.members = Set<Contact>([dbContactGroupMember])

                conversation = dbConversation
            }

            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                groupEntity: dbGroup,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = group

        let mp = MessagePermission(
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        let result = mp.canSend(
            groudID: groupID,
            groupCreatorIdentity: groupCreatorIdentity
        )

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual("group_is_not_member", result.reason)
    }
}
