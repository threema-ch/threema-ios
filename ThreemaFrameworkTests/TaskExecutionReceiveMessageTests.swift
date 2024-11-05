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
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: backgroundCnx!)

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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx)
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
        let groupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .groupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, groupManagerMock.periodicSyncIfNeededCalls.count)
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
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
        let groupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .groupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, groupManagerMock.periodicSyncIfNeededCalls.count)
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
        let groupID = MockData.generateGroupID()
        let groupEntity = GroupEntity(context: dbMainCnx.current, groupID: groupID, state: 0)
        groupEntity.groupCreator = nil

        let conversation = ConversationEntity(context: dbMainCnx.current)
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
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            groupManager: groupManagerMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock
        )

        let expectedIncomingGroupTextMessage = GroupTextMessage()
        // swiftformat:disable:next acronyms
        expectedIncomingGroupTextMessage.groupID = groupEntity.groupId
        expectedIncomingGroupTextMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedIncomingGroupTextMessage.nonce = MockData.generateMessageNonce()
        expectedIncomingGroupTextMessage.fromIdentity = "ECHOECHO"
        expectedIncomingGroupTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedIncomingGroupTextMessage.text = "Bla bla bla..."

        messageProcessorMock.abstractMessage = expectedIncomingGroupTextMessage

        let expectedIncomingBoxedMessage = BoxedMessage()
        expectedIncomingBoxedMessage.messageID = expectedIncomingGroupTextMessage.messageID

        conversation.groupMyIdentity = frameworkInjectorMock.myIdentityStore.identity

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedIncomingBoxedMessage,
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
        XCTAssertEqual(
            0,
            serverConnectorMock.sendMessageCalls.count,
            "Send no delivery receipt for incoming group message"
        )
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedIncomingBoxedMessage.messageID) }.count
        )
        XCTAssertEqual(1, groupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
                )
        )

        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: groupText; id: \(expectedIncomingBoxedMessage.messageID.hexString); groupIdentity: id: \(expectedIncomingGroupTextMessage.groupID.hexString) creator: \(expectedIncomingGroupTextMessage.groupCreator!))"
                )
        )
    }

    func testReceivedGroupRenameMessage() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let groupID = MockData.generateGroupID()
        let groupEntity = GroupEntity(context: dbMainCnx.current, groupID: groupID, state: 0)
        groupEntity.groupCreator = nil

        let conversation = ConversationEntity(context: dbMainCnx.current)
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
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            groupManager: groupManagerMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock
        )

        let expectedIncomingGroupRenameMessage = GroupRenameMessage()
        // swiftformat:disable:next acronyms
        expectedIncomingGroupRenameMessage.groupID = groupEntity.groupId
        expectedIncomingGroupRenameMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedIncomingGroupRenameMessage.nonce = MockData.generateMessageNonce()
        expectedIncomingGroupRenameMessage.fromIdentity = "ECHOECHO"
        expectedIncomingGroupRenameMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedIncomingGroupRenameMessage.name = "New group name"

        messageProcessorMock.abstractMessage = expectedIncomingGroupRenameMessage

        let expectedIncomingBoxedMessage = BoxedMessage()
        expectedIncomingBoxedMessage.messageID = expectedIncomingGroupRenameMessage.messageID

        conversation.groupMyIdentity = frameworkInjectorMock.myIdentityStore.identity

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedIncomingBoxedMessage,
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
        XCTAssertEqual(
            0,
            serverConnectorMock.sendMessageCalls.count,
            "Send no delivery receipt for incoming group message"
        )
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedIncomingBoxedMessage.messageID) }.count
        )
        XCTAssertEqual(1, groupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
                )
        )

        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x33] sendIncomingMessageAckToChat (type: groupName; id: \(expectedIncomingBoxedMessage.messageID.hexString); groupIdentity: id: \(expectedIncomingGroupRenameMessage.groupID.hexString) creator: \(expectedIncomingGroupRenameMessage.groupCreator!))"
                )
        )

        for m in ddLoggerMock.logMessages {
            print(m.message)
        }
    }

    func testReceivedTextMessageMultiDeviceActivated() throws {

        let expectedSender = dbPreparer.save {
            dbPreparer.createContact(identity: "ECHOECHO")
        }

        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

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
                MediatorMessageProtocolMock.ReflectData(
                    id: expectedReflectID,
                    message: Data([0])
                ),
            ]
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            messageProcessor: messageProcessorMock
        )

        let expectedIncomingTextMessage = BoxTextMessage()
        expectedIncomingTextMessage.fromIdentity = expectedSender.identity
        expectedIncomingTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedIncomingTextMessage.text = "Bla bla bla..."
        expectedIncomingTextMessage.nonce = MockData.generateMessageNonce()

        messageProcessorMock.abstractMessage = expectedIncomingTextMessage

        let expectedIncomingBoxedMessage = BoxedMessage()
        expectedIncomingBoxedMessage.messageID = expectedIncomingTextMessage.messageID

        let expect = expectation(description: "TaskDefinitionReceiveMessage")
        var expectError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedIncomingBoxedMessage,
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
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count, "Send delivery receipt")
        XCTAssertEqual(
            2,
            serverConnectorMock.reflectMessageCalls.count,
            "Reflect incoming message and reflect delivery receipt"
        )
        XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.completedProcessingMessageCalls
                .filter { $0.messageID.elementsEqual(expectedIncomingBoxedMessage.messageID) }.count
        )
        let groupManagerMock = try XCTUnwrap(
            frameworkInjectorMock
                .groupManager as? GroupManagerMock
        )
        XCTAssertEqual(0, groupManagerMock.periodicSyncIfNeededCalls.count)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
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
                    message: "[0x33] sendIncomingMessageAckToChat (type: text; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
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

            let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
            let messageProcessorMock = MessageProcessorMock()
            let frameworkInjectorMock = BusinessInjectorMock(
                entityManager: EntityManager(databaseContext: dbBackgroundCnx),
                userSettings: userSettingsMock,
                serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(),
                messageProcessor: messageProcessorMock
            )

            let expectedIncomingVoIPCallOffer = BoxVoIPCallOfferMessage()
            expectedIncomingVoIPCallOffer.fromIdentity = "ECHOECHO"
            expectedIncomingVoIPCallOffer.toIdentity = frameworkInjectorMock.myIdentityStore.identity
            expectedIncomingVoIPCallOffer.nonce = MockData.generateMessageNonce()

            messageProcessorMock.abstractMessage = expectedIncomingVoIPCallOffer

            let expectedIncomingBoxedMessage = BoxedMessage()
            expectedIncomingBoxedMessage.messageID = expectedIncomingVoIPCallOffer.messageID

            let expect = expectation(description: "TaskDefinitionReceiveMessage")
            var expectError: Error?

            let task = TaskDefinitionReceiveMessage(
                message: expectedIncomingBoxedMessage,
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
            XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count, "Send no delivery receipt")
            XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
            let groupManagerMock = try XCTUnwrap(
                frameworkInjectorMock
                    .groupManager as? GroupManagerMock
            )
            XCTAssertEqual(0, groupManagerMock.periodicSyncIfNeededCalls.count)
            XCTAssertTrue(
                ddLoggerMock
                    .exists(
                        message: "[0x15] receiveIncomingMessageFromChat (type: BoxedMessage; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
                    )
            )

            if test.ackMessage {
                XCTAssertEqual(1, serverConnectorMock.completedProcessingMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.completedProcessingMessageCalls
                        .filter { $0.messageID.elementsEqual(expectedIncomingBoxedMessage.messageID) }.count
                )
                XCTAssertTrue(
                    ddLoggerMock
                        .exists(
                            message: "[0x33] sendIncomingMessageAckToChat (type: callOffer; id: \(expectedIncomingBoxedMessage.messageID.hexString))"
                        )
                )
            }
            else {
                XCTAssertEqual(0, serverConnectorMock.completedProcessingMessageCalls.count)
            }
        }
    }
}
