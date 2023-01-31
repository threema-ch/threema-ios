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

import XCTest
@testable import ThreemaFramework

class TaskExecutionTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    private var deviceGroupKeys: DeviceGroupKeys!

    private var ddLoggerMock: DDLoggerMock!

    private var userSettingsMock: UserSettingsMock!
    private var serverConnectorMock: ServerConnectorMock!
    private var myIdentityStoreMock: MyIdentityStoreMock!
    private var frameworkInjectorMock: BusinessInjectorMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
        
        deviceGroupKeys = DeviceGroupKeys(
            dgpk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgrk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgdik: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgsddk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgtsk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            deviceGroupIDFirstByteHex: "a1"
        )

        userSettingsMock = UserSettingsMock()
        serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupKeys: deviceGroupKeys
        )
        myIdentityStoreMock = MyIdentityStoreMock()
        frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
    }

    func testSendMessageAlreadySent() throws {
        let expectedToIdentity1 = "TESTER01"
        let expectedToIdentity2 = "TESTER02"

        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity1,
                verificationLevel: 0
            )
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity2,
                verificationLevel: 0
            )
        }

        let cnx = TaskContext()
        let msg1 = BoxTextMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1
        msg1.text = "Test message 1"

        let msg2 = BoxTextMessage()
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = expectedToIdentity2
        msg2.text = "Test message 1"

        let task = TaskDefinitionSendAbstractMessage(message: msg1, doOnlyReflect: false, isPersistent: false)
        task.messageAlreadySentTo.append(expectedToIdentity1)

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            frameworkInjector: frameworkInjectorMock
        )

        let expect = expectation(description: "Send message")

        var sendMessages = [Promise<AbstractMessage?>]()
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg1,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg2,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )

        var totalMessagesSentCount = 0

        when(fulfilled: sendMessages)
            .done { messages in
                totalMessagesSentCount = messages.filter { $0 != nil }.count
                expect.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        waitForExpectations(timeout: 6)

        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(2, totalMessagesSentCount)
        XCTAssertEqual(2, task.messageAlreadySentTo.count)
        XCTAssertTrue(task.messageAlreadySentTo.contains(expectedToIdentity1))
        XCTAssertTrue(task.messageAlreadySentTo.contains(expectedToIdentity2))
    }

    func testSendMessageInvalidGroupContact() throws {
        let expectedToIdentity1 = "TESTER01"
        let expectedToIdentity2 = "TESTER02"

        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity1,
                verificationLevel: 0
            )
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity2,
                verificationLevel: 0
            )
            contact.state = NSNumber(integerLiteral: kStateInvalid)
        }

        let cnx = TaskContext()
        let msg1 = GroupTextMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1
        msg1.text = "Test message 1"

        let msg2 = GroupTextMessage()
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = expectedToIdentity2
        msg2.text = "Test message 1"

        let task = TaskDefinitionSendAbstractMessage(message: msg1, doOnlyReflect: false, isPersistent: false)

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            frameworkInjector: frameworkInjectorMock
        )

        let expect = expectation(description: "Send message")

        var sendMessages = [Promise<AbstractMessage?>]()
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg1,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg2,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )

        var messagesSentCount = 0

        when(fulfilled: sendMessages)
            .done { messages in
                messagesSentCount = messages.filter { $0 != nil }.count
                expect.fulfill()
            }
            .catch { error in
                XCTFail("\(error)")
            }

        waitForExpectations(timeout: 6)

        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(1, messagesSentCount)
        XCTAssertEqual(1, task.messageAlreadySentTo.count)
        XCTAssertTrue(task.messageAlreadySentTo.contains(expectedToIdentity1))
    }

    func testSendMessageContactNotFound() throws {
        let expectedToIdentity1 = "TESTER01"

        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity1,
                verificationLevel: 0
            )
        }

        let cnx = TaskContext()
        let msg1 = BoxTextMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1
        msg1.text = "Test message 1"

        let msg2 = BoxTextMessage()
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = "TESTER02"
        msg2.text = "Test message 2"

        let task = TaskDefinitionSendAbstractMessage(message: msg1, doOnlyReflect: false, isPersistent: false)

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            frameworkInjector: frameworkInjectorMock
        )

        let expect = expectation(description: "Send message")

        var sendMessages = [Promise<AbstractMessage?>]()
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg1,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )
        sendMessages.append(
            taskExecution.sendMessage(
                message: msg2,
                ltSend: .sendOutgoingMessageToChat,
                ltAck: .receiveOutgoingMessageAckFromChat
            )
        )

        var resultError: Error?

        when(fulfilled: sendMessages)
            .done { _ in
                XCTFail("Send message should be failed")
            }
            .catch { error in
                resultError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNotNil(resultError)
        XCTAssertGreaterThanOrEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertGreaterThanOrEqual(1, task.messageAlreadySentTo.count)
        if !task.messageAlreadySentTo.isEmpty {
            XCTAssertTrue(task.messageAlreadySentTo.contains(expectedToIdentity1))
        }
    }
}
