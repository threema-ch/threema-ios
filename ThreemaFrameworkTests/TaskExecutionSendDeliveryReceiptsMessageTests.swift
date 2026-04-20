import ThreemaEssentials

import XCTest
@testable import ThreemaFramework

final class TaskExecutionSendDeliveryReceiptsMessageTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testContactReadReceiptSendAndDoNotSend() throws {
        try contactReadReceiptSend(readReceipt: .send)
        try contactReadReceiptSend(readReceipt: .doNotSend)
    }

    private func contactReadReceiptSend(readReceipt: ContactEntity.ReadReceipt) throws {
        let expectedToIdentity = "ECHOECHO"

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedToIdentity
            )
            contactEntity.readReceipt = readReceipt

            dbPreparer.createConversation(contactEntity: contactEntity)
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock
        )

        let expect = expectation(description: "Task execution")
        var expectError: Error?

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: MyIdentityStoreMock().identity,
            toIdentity: expectedToIdentity,
            receiptType: .read,
            receiptMessageIDs: [BytesUtility.generateMessageID()],
            receiptReadDates: [Date()],
            excludeFromSending: [Data]()
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 3)

        XCTAssertNil(expectError)
        XCTAssertTrue(serverConnectorMock.reflectMessageCalls.isEmpty)
        switch readReceipt {
        case .send:
            XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
            XCTAssertTrue(
                serverConnectorMock.sendMessageCalls
                    .contains(where: { $0.toIdentity == expectedToIdentity })
            )
        case .default:
            break
        case .doNotSend:
            XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty)
        }
    }

    func testContactReadReceiptSendAndDoNotSendMultiDeviceActivated() throws {
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .send, excludeAll: false)
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .send, excludeAll: true)
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .doNotSend, excludeAll: false)
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .doNotSend, excludeAll: true)
    }

    private func contactReadReceiptSendMultiDeviceActivated(
        readReceipt: ContactEntity.ReadReceipt,
        excludeAll: Bool
    ) throws {
        let expectedToIdentity = "ECHOECHO"

        let readReceiptMessageIDs = [BytesUtility.generateMessageID(), BytesUtility.generateMessageID()]
        let messageReflectID = BytesUtility.generateReflectID()
        let messageReflect = BytesUtility.generateRandomBytes(length: 16)!
        var reflectIDs = [messageReflectID]

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedToIdentity
            )
            contactEntity.readReceipt = readReceipt

            dbPreparer.createConversation(contactEntity: contactEntity)
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = reflectIDs.remove(at: 0)
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

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            messageSender: messageSenderMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: messageReflectID,
                        message: messageReflect
                    ),
                ]
            )
        )

        let expect = expectation(description: "Task execution")
        var expectError: Error?

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: MyIdentityStoreMock().identity,
            toIdentity: expectedToIdentity,
            receiptType: .read,
            receiptMessageIDs: readReceiptMessageIDs,
            receiptReadDates: [Date()],
            excludeFromSending: excludeAll ? readReceiptMessageIDs : [readReceiptMessageIDs[0]]
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        wait(for: [expect], timeout: 3)

        let testParameter = "Test parameters -> Read receipt: \(readReceipt) / exclude all: \(excludeAll)"

        XCTAssertNil(expectError, testParameter)
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count, testParameter)
        switch readReceipt {
        case .send:
            if excludeAll {
                XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty, testParameter)
            }
            else {
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count, testParameter)
                XCTAssertTrue(
                    serverConnectorMock.sendMessageCalls
                        .contains(where: { $0.toIdentity == expectedToIdentity }),
                    testParameter
                )
            }
        case .default:
            break
        case .doNotSend:
            XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty, testParameter)
        }
    }
}
