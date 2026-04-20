import Foundation
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class TaskExecutionReflectIncomingMessageTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer
    }

    func testTextMessageUpdateDeliveryDate() throws {
        let expectedReflectID = BytesUtility.generateReflectID()
        let expectedReflectedAt = Date()
        let expectedToIdentity = "ECHOECHO"
        let expectedProcessedMessage = BoxTextMessage()
        expectedProcessedMessage.fromIdentity = expectedToIdentity
        expectedProcessedMessage.text = "Bla bla..."
        expectedProcessedMessage.nonce = BytesUtility.generateMessageNonce()

        var contactEntity: ContactEntity!
        var textMessage: TextMessageEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedToIdentity
            )
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)

            textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                text: expectedProcessedMessage.text,
                id: expectedProcessedMessage.messageID,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: expectedProcessedMessage.date
            )
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }

        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedReflectID,
                        message: expectedProcessedMessage.body()!
                    ),
                ]
            )
        )

        let expect = expectation(description: "Task execution")
        var expectError: Error?

        let task = TaskDefinitionReflectIncomingMessage(
            message: expectedProcessedMessage
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
        XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty)
        XCTAssertTrue(serverConnectorMock.reflectMessageCalls.isEmpty)

        XCTAssertNotEqual(textMessage.deliveryDate, expectedReflectedAt)
        XCTAssertEqual(
            textMessage.remoteSentDate,
            expectedProcessedMessage.date,
            "Remote sent date must not be changed"
        )
    }

    func testTextMessageUpdateDeliveryDateMultiDeviceActivated() throws {
        let expectedReflectID = BytesUtility.generateReflectID()
        let expectedReflectedAt = Date()
        let expectedToIdentity = "ECHOECHO"
        let expectedProcessedMessage = BoxTextMessage()
        expectedProcessedMessage.fromIdentity = expectedToIdentity
        expectedProcessedMessage.text = "Bla bla..."
        expectedProcessedMessage.nonce = BytesUtility.generateMessageNonce()

        var contactEntity: ContactEntity!
        var textMessage: TextMessageEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: expectedToIdentity
            )
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)

            textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                text: expectedProcessedMessage.text,
                id: expectedProcessedMessage.messageID,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: expectedProcessedMessage.date
            )
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }

        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            messageSender: messageSenderMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedReflectID,
                        message: expectedProcessedMessage.body()!
                    ),
                ]
            )
        )

        let expect = expectation(description: "Task execution")
        var expectError: Error?

        let task = TaskDefinitionReflectIncomingMessage(
            message: expectedProcessedMessage
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
        XCTAssertTrue(serverConnectorMock.sendMessageCalls.isEmpty)
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)

        XCTAssertEqual(textMessage.deliveryDate, expectedReflectedAt)
        XCTAssertEqual(
            textMessage.remoteSentDate,
            expectedProcessedMessage.date,
            "Remote sent date must not be changed"
        )
    }
}
