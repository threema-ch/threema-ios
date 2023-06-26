//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
    }

    func testContactReadReceiptSendAndDoNotSend() throws {
        try contactReadReceiptSend(readReceipt: .send)
        try contactReadReceiptSend(readReceipt: .doNotSend)
    }

    private func contactReadReceiptSend(readReceipt: ReadReceipt) throws {
        let expectedToIdentity = "ECHOECHO"

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity,
                verificationLevel: 0
            )
            contactEntity.readReceipt = readReceipt
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let messageSenderMock = MessageSenderMock(doSendReadReceiptContacts: [contactEntity])

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx,
                myIdentityStore: myIdentityStoreMock
            ),
            entityManager: EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock
        )
        var expecError: Error?
        let expec = expectation(description: "Task execution")

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: MyIdentityStoreMock().identity,
            toIdentity: expectedToIdentity,
            receiptType: UInt8(DELIVERYRECEIPT_MSGREAD),
            receiptMessageIDs: [MockData.generateMessageID()],
            receiptReadDates: [Date()]
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 3)

        XCTAssertNil(expecError)
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
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .send)
        try contactReadReceiptSendMultiDeviceActivated(readReceipt: .doNotSend)
    }

    private func contactReadReceiptSendMultiDeviceActivated(readReceipt: ReadReceipt) throws {
        let expectedToIdentity = "ECHOECHO"
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        var expectedReflectIDs = [expectedMessageReflectID]

        var contactEntity: ContactEntity!
        dbPreparer.save {
            contactEntity = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity,
                verificationLevel: 0
            )
            contactEntity.readReceipt = readReceipt
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
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID
                )
                return true
            }
            return false
        }

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx,
                myIdentityStore: myIdentityStoreMock
            ),
            entityManager: EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            messageSender: messageSenderMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                ]
            )
        )
        var expecError: Error?
        let expec = expectation(description: "Task execution")

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: MyIdentityStoreMock().identity,
            toIdentity: expectedToIdentity,
            receiptType: UInt8(DELIVERYRECEIPT_MSGREAD),
            receiptMessageIDs: [MockData.generateMessageID()],
            receiptReadDates: [Date()]
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        wait(for: [expec], timeout: 3)

        XCTAssertNil(expecError)
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
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
}
