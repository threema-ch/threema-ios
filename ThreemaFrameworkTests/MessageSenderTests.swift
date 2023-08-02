//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import Foundation
import XCTest

@testable import ThreemaFramework

class MessageSenderTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    
    private var ddLoggerMock: DDLoggerMock!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    func testSendDeliveryReceipt() throws {
        let testMessages: [AbstractMessage] = [
            BoxAudioMessage(),
            BoxBallotCreateMessage(),
            BoxBallotVoteMessage(),
            BoxFileMessage(),
            BoxImageMessage(),
            BoxLocationMessage(),
            BoxTextMessage(),
            BoxVideoMessage(),
            BoxVoIPCallAnswerMessage(),
            BoxVoIPCallHangupMessage(),
            BoxVoIPCallIceCandidatesMessage(),
            BoxVoIPCallOfferMessage(),
            BoxVoIPCallRingingMessage(),
            ContactDeletePhotoMessage(),
            ContactRequestPhotoMessage(),
            ContactSetPhotoMessage(),
            DeliveryReceiptMessage(),
            GroupAudioMessage(),
            GroupBallotCreateMessage(),
            GroupBallotVoteMessage(),
            GroupCreateMessage(),
            GroupDeletePhotoMessage(),
            GroupDeliveryReceiptMessage(),
            GroupFileMessage(),
            GroupImageMessage(),
            GroupLeaveMessage(),
            GroupLocationMessage(),
            GroupRenameMessage(),
            GroupRequestSyncMessage(),
            GroupSetPhotoMessage(),
            GroupTextMessage(),
            GroupVideoMessage(),
            TypingIndicatorMessage(),
            UnknownTypeMessage(),
            GroupCallStartMessage(),
        ]

        var expectedExcludeFromSending = [Data]()
        for testMessage in testMessages {
            testMessage.fromIdentity = "ECHOECHO"

            var expectedExcludeFromSending = [Data]()
            if testMessage.noDeliveryReceiptFlagSet() {
                expectedExcludeFromSending.append(testMessage.messageID)
            }

            let taskManagerMock = TaskManagerMock()

            let messageSender = MessageSender(
                serverConnector: ServerConnectorMock(),
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupManager: GroupManagerMock(),
                taskManager: taskManagerMock,
                entityManager: EntityManager(databaseContext: dbMainCnx)
            )

            let expect = expectation(description: "Send delivery receipt")

            _ = messageSender.sendDeliveryReceipt(for: testMessage)
                .done {
                    expect.fulfill()
                }

            wait(for: [expect], timeout: 3)

            let task = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendDeliveryReceiptsMessage)
            XCTAssertEqual(task.excludeFromSending, expectedExcludeFromSending)
        }
    }

    func testSendReadReceipt() async throws {
        let expectedThreemaIdentity = "ECHOECHO"
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendDeliveryReceiptsMessage else {
                    return false
                }
                return task.receiptType == .read &&
                    task.toIdentity == expectedThreemaIdentity &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testSendReadReceiptDefaultNoReadReceipt() async throws {
        let expectedThreemaIdentity = "ECHOECHO"

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let userSettings = UserSettingsMock()
        userSettings.sendReadReceipts = false

        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettings,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptContactNoReadReceipt() async throws {
        let expectedThreemaIdentity = "ECHOECHO"

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)
            contactEntity.readReceipt = .doNotSend

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptContactNoReadReceiptButMultiDeviceActivated() async throws {
        let expectedThreemaIdentity = "ECHOECHO"
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)
            contactEntity.readReceipt = .doNotSend

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: serverConnectorMock,
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendDeliveryReceiptsMessage else {
                    return false
                }
                return task.receiptType == .read &&
                    task.toIdentity == expectedThreemaIdentity &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testSendReadReceiptGroup() async throws {
        let expectedGroupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: "ECHOECHO")
        let expectedThreemaIdentity = "ECHOECHO"

        let (groupEntity, message) = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupIdentity.id,
                groupCreator: nil
            )

            let conversation = dbPreparer.createConversation(groupID: groupEntity.groupID)
            return (groupEntity, dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            ))
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: message.conversation,
            lastSyncRequest: nil
        )
        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toGroupIdentity: expectedGroupIdentity)

        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptGroupButMultiDeviceActivated() async throws {
        let expectedGroupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: "ECHOECHO")
        let expectedThreemaIdentity = "ECHOECHO"
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let (groupEntity, message) = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity)

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupIdentity.id,
                groupCreator: nil
            )

            let conversation = dbPreparer.createConversation(groupID: groupEntity.groupID)
            return (groupEntity, dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            ))
        }

        let userSettingsMock = UserSettingsMock(enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: message.conversation,
            lastSyncRequest: nil
        )
        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: serverConnectorMock,
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: groupManagerMock,
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendReadReceipt(for: [message], toGroupIdentity: expectedGroupIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendGroupDeliveryReceiptsMessage else {
                    return false
                }
                print(task.groupID == expectedGroupIdentity.id)
                print(task.groupCreatorIdentity == expectedGroupIdentity.creator)
                print(task.receiptMessageIDs.contains(expectedMessageID))

                return task.receiptType == .read &&
                    task.groupID == expectedGroupIdentity.id &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testNotAllwedDonateInteractionForOutgoingMessage() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = false

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: TaskManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        messageSender.donateInteractionForOutgoingMessage(in: objectID).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }
    
    func testDoNotDonateInteractionForOutgoingMessageIfConversationIsPrivate() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = true

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            conversation.conversationCategory = .private
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: TaskManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        messageSender.donateInteractionForOutgoingMessage(
            in: objectID,
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx)
        ).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Do not donate for private conversations"))
    }
    
    func testAllowedDonateInteractionForOutgoingMessage() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = true

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        
        let expectation = XCTestExpectation()
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: TaskManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        messageSender.donateInteractionForOutgoingMessage(
            in: objectID,
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx
            )
        ).done { _ in
            // We don't care about success here and only check the absence of a certain log message below
            // because we don't have enabled all entitlements in all targets

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertFalse(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }

    func testDoSendReadReceiptToContactEntityIsNil() throws {
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: TaskManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        XCTAssertFalse(messageSender.doSendReadReceipt(to: nil))
    }
}
