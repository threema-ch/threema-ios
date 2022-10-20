//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx)
        )

        let expec = expectation(description: "TaskDefinitionReceiveMessage")
        var expecError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 6)

        XCTAssertNotNil(expecError)
        XCTAssertEqual(
            try XCTUnwrap(expecError?.localizedDescription),
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
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )

        let expec = expectation(description: "TaskDefinitionReceiveMessage")
        var expecError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 6)

        XCTAssertNil(expecError)
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
                    message: "[0x33] sendIncomingMessageAckToChat (type: BoxedMessage; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
    }

    func testReceivedGroupTextMessage() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let groupEntity = GroupEntity(context: databaseMainCnx.current)
        groupEntity.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        groupEntity.groupCreator = nil

        let conversation = Conversation(context: databaseMainCnx.current)
        conversation.contact = nil
        conversation.groupMyIdentity = myIdentityStoreMock.identity

        let userSettingsMock = UserSettingsMock()
        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )
        let mediatorMessageProtocolMock = MediatorMessageProtocolMock()
        let messageProcessorMock = MessageProcessorMock()
        let messageSenderMock = MessageSenderMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: groupManagerMock,
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: messageSenderMock,
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            messageProcessor: messageProcessorMock
        )

        let expectedTextMessage = GroupTextMessage()
        expectedTextMessage.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        expectedTextMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.fromIdentity = "ECHOECHO"
        expectedTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.text = "Bla bla bla..."

        messageProcessorMock.abstractMessage = expectedTextMessage

        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = expectedTextMessage
            .messageID

        conversation.groupMyIdentity = frameworkInjectorMock.myIdentityStore.identity

        let expec = expectation(description: "TaskDefinitionReceiveMessage")
        var expecError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 6)

        XCTAssertNil(expecError)
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
                    message: "[0x33] sendIncomingMessageAckToChat (type: groupText; id: \(expectedBoxedMessage.messageID.hexString))"
                )
        )
    }

    func testReceivedTextMessageMultiDeviceActivated() throws {
        let deviceID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!
        let deviceGroupPathKey = BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!

        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

        let messageSenderMock = MessageSenderMock()
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: deviceID,
            deviceGroupPathKey: deviceGroupPathKey
        )
        serverConnectorMock.reflectMessageClosure = { _ -> Bool in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID
                )
                return true
            }
            return false
        }
        let messageProcessorMock = MessageProcessorMock()
        let mediatorMessageProtocolMock = MediatorMessageProtocolMock(
            deviceGroupPathKey: deviceGroupPathKey,
            returnValues: [
                MediatorMessageProtocolMock.ReflectData(
                    id: expectedReflectID,
                    message: Data([0])
                ),
            ]
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: messageSenderMock,
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            messageProcessor: messageProcessorMock
        )

        let expectedTextMessage = BoxTextMessage()
        expectedTextMessage.fromIdentity = "ECHOECHO"
        expectedTextMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedTextMessage.text = "Bla bla bla..."

        messageProcessorMock.abstractMessage = expectedTextMessage

        let expectedBoxedMessage = BoxedMessage()
        expectedBoxedMessage.messageID = expectedTextMessage
            .messageID

        let expec = expectation(description: "TaskDefinitionReceiveMessage")
        var expecError: Error?

        let task = TaskDefinitionReceiveMessage(
            message: expectedBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 6)

        XCTAssertNil(expecError)
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
}
