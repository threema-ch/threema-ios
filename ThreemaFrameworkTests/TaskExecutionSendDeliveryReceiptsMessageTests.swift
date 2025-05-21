//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

final class TaskExecutionSendDeliveryReceiptsMessageTests: XCTestCase {
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

    func testContactReadReceiptSendAndDoNotSend() throws {
        try contactReadReceiptSend(readReceipt: .send)
        try contactReadReceiptSend(readReceipt: .doNotSend)
    }

    private func contactReadReceiptSend(readReceipt: ContactEntity.ReadReceipt) throws {
        let expectedToIdentity = "ECHOECHO"

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity
            )
            contactEntity.readReceipt = readReceipt

            dbPreparer.createConversation(contactEntity: contactEntity)
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock
        )

        let expect = expectation(description: "Task execution")
        var expectError: Error?

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: MyIdentityStoreMock().identity,
            toIdentity: expectedToIdentity,
            receiptType: .read,
            receiptMessageIDs: [MockData.generateMessageID()],
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

        let readReceiptMessageIDs = [MockData.generateMessageID(), MockData.generateMessageID()]
        let messageReflectID = MockData.generateReflectID()
        let messageReflect = BytesUtility.generateRandomBytes(length: 16)!
        var reflectIDs = [messageReflectID]

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity
            )
            contactEntity.readReceipt = readReceipt

            dbPreparer.createConversation(contactEntity: contactEntity)
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
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
