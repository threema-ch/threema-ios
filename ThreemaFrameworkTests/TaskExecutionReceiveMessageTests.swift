//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

class TaskExecutionReceiveMessageTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!
    private var databasePreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        databasePreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testReceivedMessageNotValidServerDisconnected() throws {
        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx)
        )

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 6)

        XCTAssertNotNil(expectError)
        XCTAssertEqual(
            try XCTUnwrap(expectError?.localizedDescription),
            TaskExecutionError.processIncomingMessageFailed(message: expectedBoxedMessage.messageID.hexString)
                .localizedDescription
        )
        let serverConnectorMock: ServerConnectorMock = try XCTUnwrap(
            frameworkInjectorMock
                .serverConnector as? ServerConnectorMock
        )
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
        )
        let backgroundGroupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .backgroundGroupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
    }

    func testReceivedMessageNotValid() throws {
        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            serverConnector: serverConnectorMock
        )

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
        )
        let backgroundGroupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .backgroundGroupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "Message would not be processed (skip reflecting message)"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "Message would not be processed (skip send delivery receipt)"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
    }

    func testReceivedGroupTextMessage() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let groupEntity = GroupEntity(context: databaseMainCnx.current)
        groupEntity.groupID = MockData.generateGroupID()
        groupEntity.groupCreator = nil

        let conversation = Conversation(context: databaseMainCnx.current)
        conversation.contact = nil
        conversation.groupMyIdentity = myIdentityStoreMock.identity

        let userSettingsMock = UserSettingsMock()
        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        ))
        let messageProcessorMock = MessageProcessorMock()
        let messageSenderMock = MessageSenderMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            messageSender: messageSenderMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock
        )

        let expectedTextMessage = GroupTextMessage()
        expectedTextMessage.groupID = groupEntity.groupID
        expectedTextMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.nonce = MockData.generateMessageNonce()
        expectedTextMessage.fromIdentity = "ECHOECHO"
        expectedTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.text = "Bla bla bla..."

        messageProcessorMock.abstractMessage = expectedTextMessage

        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = expectedTextMessage
            .messageID

        conversation.groupMyIdentity = frameworkInjectorMock.myIdentityStore.identity

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(1, messageSenderMock.sendDeliveryReceiptCalls.count)
        XCTAssertEqual(
            1,
            messageSenderMock.sendDeliveryReceiptCalls
                .filter { $0.messageID.elementsEqual(expectedTextMessage.messageID) }.count
        )
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
        )
        let backgroundGroupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .backgroundGroupManager as? GroupManagerMock
        )
        XCTAssertEqual(1, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )

        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: groupText; id: \(expectedBoxedMessage.messageID.hexString); groupIdentity: id: \(expectedTextMessage.groupID.hexString) creator: \(expectedTextMessage.groupCreator!))"
                )
        )
    }

    func testReceivedGroupRenameMessage() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let groupEntity = GroupEntity(context: databaseMainCnx.current)
        groupEntity.groupID = MockData.generateGroupID()
        groupEntity.groupCreator = nil

        let conversation = Conversation(context: databaseMainCnx.current)
        conversation.contact = nil
        conversation.groupMyIdentity = myIdentityStoreMock.identity

        let userSettingsMock = UserSettingsMock()
        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        ))
        let messageProcessorMock = MessageProcessorMock()
        let messageSenderMock = MessageSenderMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: groupManagerMock,
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            messageSender: messageSenderMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock
        )

        let expectedGroupRenameMessage = GroupRenameMessage()
        expectedGroupRenameMessage.groupID = groupEntity.groupID
        expectedGroupRenameMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedGroupRenameMessage.nonce = MockData.generateMessageNonce()
        expectedGroupRenameMessage.fromIdentity = "ECHOECHO"
        expectedGroupRenameMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedGroupRenameMessage.name = "New group name"

        messageProcessorMock.abstractMessage = expectedGroupRenameMessage

        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = expectedGroupRenameMessage
            .messageID

        conversation.groupMyIdentity = frameworkInjectorMock.myIdentityStore.identity

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(1, messageSenderMock.sendDeliveryReceiptCalls.count)
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
        )
        let backgroundGroupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .backgroundGroupManager as? GroupManagerMock
        )
        XCTAssertEqual(1, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )

        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: groupName; id: \(expectedBoxedMessage.messageID.hexString); groupIdentity: id: \(expectedGroupRenameMessage.groupID.hexString) creator: \(expectedGroupRenameMessage.groupCreator!))"
                )
        )

        ddLoggerMock.logMessages.forEach { m in
            print(m.message)
        }
    }

    func testReceivedTextMessageMultiDeviceActivated() throws {
        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

        let messageSenderMock = MessageSenderMock()
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: Date()]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }
        let messageProcessorMock = MessageProcessorMock()
        let mediatorMessageProtocolMock = MediatorMessageProtocolMock(
            deviceGroupKeys: MockData.deviceGroupKeys,
            returnValues: [
                MediatorMessageProtocolMock.ReflectData(
                    id: expectedReflectID,
                    message: Data([0])
                ),
            ]
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            messageSender: messageSenderMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            messageProcessor: messageProcessorMock
        )

        let expectedTextMessage = BoxTextMessage()
        expectedTextMessage.fromIdentity = "ECHOECHO"
        expectedTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.text = "Bla bla bla..."
        expectedTextMessage.nonce = MockData.generateMessageNonce()

        messageProcessorMock.abstractMessage = expectedTextMessage

        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = expectedTextMessage
            .messageID

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(1, messageSenderMock.sendDeliveryReceiptCalls.count)
        XCTAssertEqual(
            1,
            messageSenderMock.sendDeliveryReceiptCalls
                .filter { $0.messageID.elementsEqual(expectedTextMessage.messageID) }.count
        )
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
        )
        let backgroundGroupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .backgroundGroupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x91] reflectIncomingMessageToMediator (Reflect ID: \(expectedReflectID.hexString) (unknown multi device message type))"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x24] receiveIncomingMessageAckFromMediator (Reflect ID: \(expectedReflectID.hexString) (unknown multi device message type))"
                )
        )
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: text; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
    }

    // MARK: Incomping VoIP message

    func testReceivedVoIPMessage() throws {
        AppGroup.setAppID("Threema")

        let tests: [(isNotificationExtension: Bool, isSenderBlocked: Bool, ackMessage: Bool)] = [
            (true, true, true),
            (false, true, true),
            (true, false, false),
            (false, false, true),
        ]

        for test in tests {
            AppGroup.setActive(test.isNotificationExtension, for: AppGroupTypeNotificationExtension)

            let userSettingsMock = UserSettingsMock()
            if test.isSenderBlocked {
                userSettingsMock.blacklist = ["ECHOECHO"]
            }

            let messageSenderMock = MessageSenderMock()
            let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
            let messageProcessorMock = MessageProcessorMock()
            let frameworkInjectorMock = BusinessInjectorMock(
                backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
                entityManager: EntityManager(databaseContext: databaseMainCnx),
                messageSender: messageSenderMock,
                userSettings: userSettingsMock,
                serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(),
                messageProcessor: messageProcessorMock
            )

            let expectedVoIPCallOffer = BoxVoIPCallOfferMessage()
            expectedVoIPCallOffer.fromIdentity = "ECHOECHO"
            expectedVoIPCallOffer.toIdentity = frameworkInjectorMock.myIdentityStore.identity
            expectedVoIPCallOffer.nonce = MockData.generateMessageNonce()

            messageProcessorMock.abstractMessage = expectedVoIPCallOffer

            let expectedBoxedMessage = BoxedMessage()
            expectedBoxedMessage.messageID = expectedVoIPCallOffer
                .messageID

            let expect = expectation(description: "TaskDefinitionReceiveMessage")
            var expectError: Error?

            let task = TaskDefinitionReceiveMessage(
                message: expectedBoxedMessage,
                receivedAfterInitialQueueSend: true,
                maxBytesToDecrypt: 0,
                timeoutDownloadThumbnail: 0
            )
            task.create(frameworkInjector: frameworkInjectorMock).execute()
                .done {
                    expect.fulfill()
                }
                .catch { error in
                    expectError = error
                    expect.fulfill()
                }

            wait(for: [expect], timeout: 6)

            XCTAssertNil(expectError)
            XCTAssertEqual(1, messageSenderMock.sendDeliveryReceiptCalls.count)
            XCTAssertEqual(
                1,
                messageSenderMock.sendDeliveryReceiptCalls
                    .filter { $0.messageID.elementsEqual(expectedVoIPCallOffer.messageID) }.count
            )
            XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
            XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
            let backgroundGroupManagerMock = try XCTUnwrap(
                frameworkInjectorMock
                    .backgroundGroupManager as? GroupManagerMock
            )
            XCTAssertEqual(0, backgroundGroupManagerMock.periodicSyncIfNeededCalls.count)
            XCTAssertTrue(
                ddLoggerMock
                    .exists(
                        message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                    )
            )

            if test.ackMessage {
                XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.completedProcessingMessageCalls
                        .filter { $0.messageID.elementsEqual(expectedBoxedMessage.messageID) }.count
                )
                XCTAssertTrue(
                    ddLoggerMock
                        .exists(
                            message: "[0x33] sendIncomingMessageAckToChat (type: callOffer; id: \(expectedBoxedMessage.messageID.hexString))"
                        )
                )
            }
            else {
                XCTAssertEqual(0, serverConnectorMock.completedProcessingMessageCalls.count)
            }
        }
    }
}
