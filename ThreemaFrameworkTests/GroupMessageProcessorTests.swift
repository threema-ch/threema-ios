//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class GroupMessageProcessorTests: XCTestCase {
    private var databaseCnx: DatabaseContext!
    private var databasePreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!
    
    override func setUpWithError() throws {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        databaseCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }
    
    func testHandleMessageGroupNotExists() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        // 0: test description
        // test config:
        // 1: group message type
        // 2: group creator
        // 3: message sender
        // expected results:
        // 4: sync request calls
        // 5: add to pending messages
        let tests = [
            [
                "Send GroupRequestSyncMessage and add to pending messages, because group not found for regular group message (creator=sender)",
                GroupTextMessage(),
                "CREATOR1",
                "CREATOR1",
                1,
                true,
            ],
            [
                "Send GroupRequestSyncMessage and add to pending messages, because group not found for regular group message",
                GroupTextMessage(),
                "CREATOR1",
                "JAMES007",
                1,
                true,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: When receiving this message: 1.
            [
                "Do nothing, because no group found for incoming GroupRequestSyncMessage (creator=sender)",
                GroupRequestSyncMessage(),
                "CREATOR1",
                "CREATOR1",
                0,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: When receiving this message: 2.
            [
                "Do nothing, because no group found for incoming GroupRequestSyncMessage",
                GroupRequestSyncMessage(),
                "CREATOR1",
                "JAMES007",
                0,
                false,
            ],
            
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 1.
            [
                "Do nothing, because no group found for incoming GroupLeaveMessage from creator",
                GroupLeaveMessage(),
                "CREATOR1",
                "CREATOR1",
                0,
                false,
            ],
            
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 3. / 1.
            [
                "Do nothing, because no group found for incoming GroupLeaveMessage from member and i'm creator",
                GroupLeaveMessage(),
                myIdentityStoreMock.identity,
                "JAMES007",
                0,
                false,
            ],
            
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 3. / 2.
            [
                "Send GroupRequestSyncMessage and add do pending messages, because no group found for regular GroupLeaveMessage from member",
                GroupLeaveMessage(),
                "CREATOR1",
                "JAMES007",
                1,
                true,
            ],
        ]

        // run tests
        
        for test in tests {
            let testDescription = test[0] as! String

            let userSettingsMock = UserSettingsMock()
            let groupManagerMock: GroupManagerProtocolObjc = GroupManagerMock()

            (test[1] as! AbstractGroupMessage).nonce = BytesUtility.generateRandomBytes(length: Int(kNonceLen))
            (test[1] as! AbstractGroupMessage).groupCreator = test[2] as? String
            (test[1] as! AbstractGroupMessage).fromIdentity = test[3] as? String

            let groupMessageProcessor = GroupMessageProcessor(
                message: test[1] as! AbstractGroupMessage,
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupManager: groupManagerMock as! NSObject,
                entityManager: EntityManager(databaseContext: databaseCnx),
                nonceGuard: NonceGuardMock()
            )

            let expec = expectation(description: "Group message processed")
            
            var resultDidHandleMessage: Bool?
            var resultError: Error?
            
            groupMessageProcessor.handleMessage(onCompletion: { didHandleMessage in
                resultDidHandleMessage = didHandleMessage
                expec.fulfill()
            }, onError: { error in
                resultError = error
                expec.fulfill()
            })

            wait(for: [expec], timeout: 2)
            
            XCTAssertNil(resultError, testDescription)
            XCTAssertTrue(try XCTUnwrap(resultDidHandleMessage), testDescription)
            XCTAssertEqual(0, userSettingsMock.unknownGroupAlertList.count, testDescription)
            XCTAssertEqual(0, (groupManagerMock as! GroupManagerMock).unknownGroupCalls.count, testDescription)
            XCTAssertEqual(
                test[4] as! Int,
                (groupManagerMock as! GroupManagerMock).sendSyncRequestCalls.count,
                testDescription
            )
            XCTAssertEqual(test[5] as! Bool, groupMessageProcessor.addToPendingMessages, testDescription)
        }
    }

    func testHandleMessageGroupExistsIamMember() throws {
        let expectedMember01 = "MEMBER01"
        let expectedMember02 = "MEMBER02"
        let expectedMember03 = "MEMBER03"

        // prepare test db

        [expectedMember01, expectedMember02, expectedMember03].forEach { member in
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: member,
                verificationLevel: 0
            )
        }

        // 0: test description
        // incoming message:
        // 1: message
        // 2: sender
        // expected results:
        // 3: request sync
        // 4: left the group
        // 5: sync add member
        // 6: sync remove member
        // 7: did handle message
        // 8: add to pending messages
        let tests = [
            [
                "Group found all good, group chat message can be processed",
                GroupTextMessage(),
                expectedMember01,
                false,
                false,
                false,
                false,
                false,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#n:e2e:groups
            // Section: Receiving 4.
            [
                "Send GroupRequestSyncMessage, because the member of this message is not in group and i'm NOT creator",
                GroupTextMessage(),
                "MEMBER04",
                false,
                false,
                false,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: 1.
            [
                "Do nothing, sender is creator of the group",
                GroupRequestSyncMessage(),
                expectedMember01,
                false,
                false,
                false,
                false,
                true,
                false,
            ],
            [
                "Do nothing, because received GroupRequestSyncMessage form member but i'm not creator",
                GroupRequestSyncMessage(),
                expectedMember02,
                false,
                false,
                false,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 4.
            [
                "Member left the group",
                GroupLeaveMessage(),
                expectedMember02,
                false,
                true,
                false,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 4.
            [
                "Creator left the group",
                GroupLeaveMessage(),
                expectedMember01,
                false,
                true,
                false,
                false,
                true,
                false,
            ],
        ]

        // run tests

        for test in tests {
            let testDescription = test[0] as! String

            let myIdentityStoreMock = MyIdentityStoreMock()
            let userSettingsMock = UserSettingsMock()
            let taskManagerMock = TaskManagerMock()
            let entityManager = EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock)

            let groupManager = GroupManager(
                myIdentityStoreMock,
                ContactStoreMock(callOnCompletion: true),
                taskManagerMock,
                UserSettingsMock(),
                entityManager,
                GroupPhotoSenderMock()
            )

            let expectedGroupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            let expectedCreator = expectedMember01

            let group = try XCTUnwrap(createOrUpdateDBWait(
                groupManager: groupManager,
                groupID: expectedGroupID,
                creator: expectedCreator,
                members: Set<String>([
                    myIdentityStoreMock.identity,
                    expectedMember01,
                    expectedMember02,
                    expectedMember03,
                ])
            ))

            XCTAssertNotNil(group)

            let message: AbstractGroupMessage = (test[1] as! AbstractGroupMessage)
            message.nonce = BytesUtility.generateRandomBytes(length: Int(kNonceLen))
            message.groupID = expectedGroupID
            message.groupCreator = expectedCreator
            message.fromIdentity = test[2] as? String
            message.toIdentity = myIdentityStoreMock.identity

            let groupMessageProcessor = GroupMessageProcessor(
                message: message,
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupManager: groupManager,
                entityManager: entityManager,
                nonceGuard: NonceGuardMock()
            )

            let expec = expectation(description: "Group message processed")

            var resultDidHandleMessage: Bool?
            var resultError: Error?

            groupMessageProcessor.handleMessage(onCompletion: { didHandleMessage in
                resultDidHandleMessage = didHandleMessage
                expec.fulfill()
            }, onError: { error in
                resultError = error
                expec.fulfill()
            })

            wait(for: [expec], timeout: 2)

            DDLog.flushLog()

            XCTAssertNil(resultError, testDescription)
            XCTAssertEqual(0, userSettingsMock.unknownGroupAlertList.count, testDescription)
            XCTAssertEqual(
                test[3] as! Bool,
                ddLoggerMock
                    .exists(
                        message: "\(message.fromIdentity!) is not member of group \(message.groupID.hexString), add to pending messages and request group sync"
                    ),
                testDescription
            )
            XCTAssertEqual(
                test[4] as! Bool,
                ddLoggerMock
                    .exists(
                        message: "Member \(message.fromIdentity!) left the group \(message.groupID.hexString) \(message.groupCreator!)"
                    ),
                testDescription
            )
            XCTAssertEqual(
                test[5] as! Bool,
                (taskManagerMock.addedTasks.first as? TaskDefinitionSendGroupCreateMessage)?
                    .toMembers
                    .filter { $0 == (test[2] as! String) }.count ?? 0 == 1,
                testDescription
            )
            XCTAssertEqual(
                test[6] as! Bool,
                (taskManagerMock.addedTasks.first as? TaskDefinitionSendGroupCreateMessage)?
                    .removedMembers?
                    .filter { $0 == "MEMBER04" }.count ?? 0 == 1,
                testDescription
            )
            XCTAssertEqual(test[7] as! Bool, try XCTUnwrap(resultDidHandleMessage), testDescription)
            XCTAssertEqual(test[8] as! Bool, groupMessageProcessor.addToPendingMessages, testDescription)
        }
    }

    func testHandleMessageGroupExistsIamCreator() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedMember01 = "MEMBER01"
        let expectedMember02 = "MEMBER02"
        let expectedMember03 = "MEMBER03"
        let expectedCreator = myIdentityStoreMock.identity

        // prepare test db

        [expectedMember01, expectedMember02, expectedMember03].forEach { member in
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: member,
                verificationLevel: 0
            )
        }

        // 0: test description
        // test config:
        // 1: message
        // 2: sender
        // expected results:
        // 3: request sync
        // 4: left the group
        // 5: sync add member
        // 6: sync remove member
        // 7: did handle message
        // 8: add to pending messages
        let tests = [
            [
                "Group found all good, process group message",
                GroupTextMessage(),
                expectedMember01,
                false,
                false,
                false,
                false,
                false,
                false,
            ],
            [
                "Sync this group (remove member), because member is not in group and i'm creator",
                GroupTextMessage(),
                "MEMBER04",
                false,
                false,
                false,
                true,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: 1.
            [
                "Do nothing, sender is creator of the group",
                GroupRequestSyncMessage(),
                expectedCreator,
                false,
                false,
                false,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: When receiving this message: 4.
            [
                "Sync this group, because answer regular GroupRequestSyncMessage from member",
                GroupRequestSyncMessage(),
                "MEMBER04",
                false,
                false,
                false,
                true,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: When receiving this message: 5.
            [
                "Sync this group, because answer regular GroupRequestSyncMessage from member",
                GroupRequestSyncMessage(),
                expectedMember02,
                false,
                false,
                true,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 4.
            [
                "Member left the group",
                GroupLeaveMessage(),
                expectedMember02,
                false,
                true,
                false,
                false,
                true,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp-e2e/#m:e2e:group-leave
            // Section: When receiving this message: 4.
            [
                "Creator left the group",
                GroupLeaveMessage(),
                expectedCreator,
                false,
                true,
                false,
                false,
                true,
                false,
            ],
        ]

        // run tests

        for test in tests {
            let testDescription = test[0] as! String

            let userSettingsMock = UserSettingsMock()
            let taskManagerMock = TaskManagerMock()
            let entityManager = EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock)

            let groupManager = GroupManager(
                myIdentityStoreMock,
                ContactStoreMock(callOnCompletion: true),
                taskManagerMock,
                UserSettingsMock(),
                entityManager,
                GroupPhotoSenderMock()
            )

            let expectedGroupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!

            let group = try XCTUnwrap(createOrUpdateDBWait(
                groupManager: groupManager,
                groupID: expectedGroupID,
                creator: expectedCreator,
                members: Set<String>([expectedMember01, expectedMember02, expectedMember03])
            ))

            XCTAssertNotNil(group)

            let message: AbstractGroupMessage = (test[1] as! AbstractGroupMessage)
            message.nonce = BytesUtility.generateRandomBytes(length: Int(kNonceLen))
            message.groupID = expectedGroupID
            message.groupCreator = expectedCreator
            message.fromIdentity = test[2] as? String
            message.toIdentity = myIdentityStoreMock.identity

            let groupMessageProcessor = GroupMessageProcessor(
                message: message,
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupManager: groupManager,
                entityManager: entityManager,
                nonceGuard: NonceGuardMock()
            )

            let expec = expectation(description: "Group message processed")

            var resultDidHandleMessage: Bool?
            var resultError: Error?

            groupMessageProcessor.handleMessage(onCompletion: { didHandleMessage in
                resultDidHandleMessage = didHandleMessage
                expec.fulfill()
            }, onError: { error in
                resultError = error
                expec.fulfill()
            })

            wait(for: [expec], timeout: 2)

            DDLog.flushLog()

            XCTAssertNil(resultError, testDescription)
            XCTAssertEqual(0, userSettingsMock.unknownGroupAlertList.count, testDescription)
            XCTAssertEqual(
                test[3] as! Bool,
                ddLoggerMock
                    .exists(
                        message: "\(message.fromIdentity!) is not member of group \(message.groupID.hexString), add to pending messages and request group sync"
                    ),
                testDescription
            )
            XCTAssertEqual(
                test[4] as! Bool,
                ddLoggerMock
                    .exists(
                        message: "Member \(message.fromIdentity!) left the group \(message.groupID.hexString) \(message.groupCreator!)"
                    ),
                testDescription
            )
            XCTAssertEqual(
                test[5] as! Bool,
                (taskManagerMock.addedTasks.first as? TaskDefinitionSendGroupCreateMessage)?
                    .toMembers
                    .filter { $0 == "MEMBER02" }.count == 1,
                testDescription
            )
            XCTAssertEqual(
                test[6] as? Bool,
                (taskManagerMock.addedTasks.first as? TaskDefinitionSendGroupCreateMessage)?
                    .removedMembers?
                    .filter { $0 == "MEMBER04" }.count ?? 0 == 1,
                testDescription
            )
            XCTAssertEqual(test[7] as! Bool, try XCTUnwrap(resultDidHandleMessage), testDescription)
            XCTAssertEqual(test[8] as! Bool, groupMessageProcessor.addToPendingMessages, testDescription)
        }
    }

    func testHandleMessageGroupExistsIamCreatorLeftTheGroup() throws {
        let expectedMember01 = "MEMBER01"
        let expectedMember02 = "MEMBER02"
        let expectedMember03 = "MEMBER03"

        [expectedMember01, expectedMember02, expectedMember03].forEach { member in
            databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: member,
                verificationLevel: 0
            )
        }

        // 0: test description
        // test config:
        // 1: message
        // 2: sender
        // expected results:
        // 3: dissolve group
        // 4: add to pending messages
        let tests = [
            [
                "Message won't processed, because i'm creator but left the group",
                GroupTextMessage(),
                expectedMember01,
                false,
                false,
            ],
            // Spec: https://clients.pages.threema.dev/protocols/threema-protocols/structbuf/csp/#m:e2e:group-sync-request
            // Section: 3.
            [
                "Dissolve group to sender, because i'm creator but left the group",
                GroupRequestSyncMessage(),
                expectedMember02,
                true,
                false,
            ],
        ]

        // run tests

        for test in tests {
            let testDescription = test[0] as! String

            let myIdentityStoreMock = MyIdentityStoreMock()
            let userSettingsMock = UserSettingsMock()
            let taskManagerMock = TaskManagerMock()
            let entityManager = EntityManager(databaseContext: databaseCnx, myIdentityStore: myIdentityStoreMock)

            let groupManager = GroupManager(
                myIdentityStoreMock,
                ContactStoreMock(callOnCompletion: true),
                taskManagerMock,
                userSettingsMock,
                entityManager,
                GroupPhotoSenderMock()
            )

            let expectedGroupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            let expectedCreator = myIdentityStoreMock.identity

            let group = try XCTUnwrap(createOrUpdateDBWait(
                groupManager: groupManager,
                groupID: expectedGroupID,
                creator: expectedCreator,
                members: Set<String>([expectedMember01, expectedMember02, expectedMember03])
            ))

            XCTAssertEqual(.active, group.state)

            groupManager.leaveDB(
                groupID: expectedGroupID,
                creator: expectedCreator,
                member: expectedCreator,
                systemMessageDate: Date()
            )

            XCTAssertEqual(.left, group.state)

            let message: AbstractGroupMessage = (test[1] as! AbstractGroupMessage)
            message.nonce = BytesUtility.generateRandomBytes(length: Int(kNonceLen))
            message.groupID = expectedGroupID
            message.groupCreator = expectedCreator
            message.fromIdentity = (test[2] as! String)
            message.toIdentity = myIdentityStoreMock.identity

            let groupMessageProcessor = GroupMessageProcessor(
                message: message,
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupManager: groupManager,
                entityManager: entityManager,
                nonceGuard: NonceGuardMock()
            )

            let expec = expectation(description: "Group message processed")

            var resultDidHandleMessage: Bool?
            var resultError: Error?

            groupMessageProcessor.handleMessage(onCompletion: { didHandleMessage in
                resultDidHandleMessage = didHandleMessage
                expec.fulfill()
            }, onError: { error in
                resultError = error
                expec.fulfill()
            })

            wait(for: [expec], timeout: 2)

            DDLog.flushLog()

            XCTAssertNil(resultError, testDescription)
            XCTAssertTrue(try XCTUnwrap(resultDidHandleMessage), testDescription)
            XCTAssertEqual(0, userSettingsMock.unknownGroupAlertList.count, testDescription)
            XCTAssertEqual(
                test[3] as! Bool,
                (taskManagerMock.addedTasks.first as? TaskDefinitionGroupDissolve)?
                    .toMembers.contains(where: { $0 == (test[2] as! String) }) ?? false,
                testDescription
            )
            XCTAssertEqual(test[4] as! Bool, groupMessageProcessor.addToPendingMessages, testDescription)
        }
    }

    /// Create or update group in DB and wait until finished.
    @discardableResult private func createOrUpdateDBWait(
        groupManager: GroupManagerProtocol,
        groupID: Data,
        creator: String,
        members: Set<String>
    ) -> Group? {
        var group: Group?

        let expec = expectation(description: "Group create or update")

        groupManager.createOrUpdateDB(
            groupID: groupID,
            creator: creator,
            members: members,
            systemMessageDate: Date(),
            sourceCaller: .local
        )
        .done { grp in
            group = grp
            expec.fulfill()
        }
        .catch { error in
            XCTFail(error.localizedDescription)
        }

        wait(for: [expec], timeout: 30)

        return group
    }
}
