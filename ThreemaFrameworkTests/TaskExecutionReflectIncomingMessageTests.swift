//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

class TaskExecutionReflectIncomingMessageTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: backgroundCnx!)
    }

    func testTextMessageUpdateDeliveryDate() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectedAt = Date()
        let expectedToIdentity = "ECHOECHO"
        let expectedProcessedMessage = BoxTextMessage()
        expectedProcessedMessage.fromIdentity = expectedToIdentity
        expectedProcessedMessage.text = "Bla bla..."
        expectedProcessedMessage.nonce = MockData.generateMessageNonce()

        var contactEntity: ContactEntity!
        var textMessage: TextMessage!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity,
                verificationLevel: 0
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
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
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectedAt = Date()
        let expectedToIdentity = "ECHOECHO"
        let expectedProcessedMessage = BoxTextMessage()
        expectedProcessedMessage.fromIdentity = expectedToIdentity
        expectedProcessedMessage.text = "Bla bla..."
        expectedProcessedMessage.nonce = MockData.generateMessageNonce()

        var contactEntity: ContactEntity!
        var textMessage: TextMessage!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity,
                verificationLevel: 0
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
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
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
