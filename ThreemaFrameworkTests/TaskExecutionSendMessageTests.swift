//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import CocoaLumberjackSwift
import XCTest
@testable import ThreemaFramework

class TaskExecutionSendMessageTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    private var entityManager: EntityManager!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
        entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: mainCnx, backgroundContext: nil))

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testExecuteTextMessageWithoutReflectingConnectionStateDisconnected() throws {
        let serverConnectorMock = ServerConnectorMock(connectionState: .disconnected)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        let (messageID, receiverIdentity, conversation) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: receiverIdentity,
                verificationLevel: 0
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: contact,
                remoteSentDate: nil
            )

            return (messageID, receiverIdentity, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        if let expectedError = try? XCTUnwrap(expectError as? TaskExecutionError) {
            XCTAssertEqual(
                "\(expectedError)",
                "\(TaskExecutionError.sendMessageFailed(message: "(type: text; id: \(messageID.hexString))"))"
            )
        }
        else {
            XCTFail("Exception should be thrown")
        }
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID) }.count
        )
        XCTAssertFalse(
            try XCTUnwrap(
                entityManager.entityFetcher.message(
                    with: messageID,
                    conversation: conversation
                ) as? TextMessage
            ).sent.boolValue
        )
    }

    func testExecuteTextMessageWithoutReflecting() throws {
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        let (messageID, receiverIdentity, conversation) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: receiverIdentity,
                verificationLevel: 0
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: contact,
                remoteSentDate: nil
            )

            return (messageID, receiverIdentity, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID) }.count
        )
        XCTAssertTrue(
            try XCTUnwrap(
                entityManager.entityFetcher.message(
                    with: messageID,
                    conversation: conversation
                ) as? TextMessage
            ).sent.boolValue
        )
    }

    func testExecuteTextMessageWithoutReflectingToInvalidContact() throws {
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        let (messageID, receiverIdentity, conversation) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: receiverIdentity,
                verificationLevel: 0
            )
            contact.state = NSNumber(integerLiteral: kStateInvalid)

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: contact,
                remoteSentDate: nil
            )

            return (messageID, receiverIdentity, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        if let expectError,
           case let TaskExecutionError.invalidContact(message: message) = expectError {
            XCTAssertEqual(
                message,
                "Do not sending message to invalid identity Optional(\"\(receiverIdentity)\") ((type: text; id: \(messageID.hexString)))"
            )
        }
        else {
            XCTFail()
        }

        XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertFalse(textMessage.sent.boolValue)
            XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
        }
    }

    func testExecuteTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
        // Second date (reflected at) is used when reflecting message sent
        var expectedReflectedAtDates = [expectedMessageReflectedAt, Date().addingTimeInterval(10)]

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                let expectedReflectedAt = expectedReflectedAtDates.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return true
            }
            return false
        }
        XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (messageID, receiverIdentity, conversation) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: receiverIdentity,
                verificationLevel: 0
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: contact,
                remoteSentDate: nil
            )

            return (messageID, receiverIdentity, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
        )
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                .count
        )
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID)
            }.count
        )

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertTrue(textMessage.sent.boolValue)
            XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
        }
    }

    func testExecuteGroupTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
        // Second date (reflected at) is used when reflecting message sent
        var expectedReflectedAtDates = [expectedMessageReflectedAt, Date().addingTimeInterval(10)]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"], enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                let expectedReflectedAt = expectedReflectedAtDates.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return true
            }
            return false
        }
        let myIdentityStoreMock = MyIdentityStoreMock()
        XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (messageID, group, conversation) = dbPreparer.save {
            var members = Set<ContactEntity>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                groupCreator: "MEMBER01"
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.addMembers(members)

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: nil,
                remoteSentDate: nil
            )

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )

            return (messageID, group, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
        )
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                .count
        )
        XCTAssertEqual(2, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            2,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID)
            }.count
        )
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertTrue(textMessage.sent.boolValue)
            XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
        }
    }

    func testExecuteGroupTextMessageWithReflectingAndOneInvalidContact() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
        // Second date (reflected at) is used when reflecting message sent
        var expectedReflectedAtDates = [expectedMessageReflectedAt, Date().addingTimeInterval(10)]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"], enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                let expectedReflectedAt = expectedReflectedAtDates.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return true
            }
            return false
        }
        let myIdentityStoreMock = MyIdentityStoreMock()
        XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (messageID, group, conversation) = dbPreparer.save {
            var members = Set<ContactEntity>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)

                if member == "MEMBER04" {
                    contact.state = NSNumber(integerLiteral: kStateInvalid)
                }
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                groupCreator: "MEMBER01"
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.addMembers(members)

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: nil,
                remoteSentDate: nil
            )

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )

            return (messageID, group, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "Do not sending message to invalid identity Optional(\"MEMBER04\") ((type: groupText; id: \(messageID.hexString); groupCreator: \(group.groupCreatorIdentity) - groupId: \(group.groupID.hexString)))"
                )
        )
        XCTAssertNil(expectError)
        XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
        )
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                .count
        )
        XCTAssertEqual(2, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            2,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID)
            }.count
        )
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertTrue(textMessage.sent.boolValue)
            XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
        }
    }

    func testExecuteGroupTextMessageWithReflectingAlreadySent() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
        // Second date (reflected at) is used when reflecting message sent
        var expectedReflectedAtDates = [expectedMessageReflectedAt, Date().addingTimeInterval(10)]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"], enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                let expectedReflectedAt = expectedReflectedAtDates.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: expectedReflectedAt]
                )
                return true
            }
            return false
        }
        let myIdentityStoreMock = MyIdentityStoreMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (messageID, group, conversation) = dbPreparer.save {
            var members = Set<ContactEntity>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                groupCreator: "MEMBER01"
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.addMembers(members)

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: nil,
                remoteSentDate: nil
            )

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )

            return (messageID, group, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        task.messageAlreadySentTo["MEMBER01"] = MockData.generateMessageNonce()
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
        )
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                .count
        )
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID)
            }.count
        )
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
        }
    }

    func testExecuteGroupCreateMessageWithOwnIdentityAsMemberAlreadySent() throws {
        let userSettingsMock = UserSettingsMock()
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn
        )
        let myIdentityStoreMock = MyIdentityStoreMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock
        )

        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", myIdentityStoreMock.identity]

        let group = dbPreparer.save {
            var members = Set<ContactEntity>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: member,
                    verificationLevel: 0
                )
                if myIdentityStoreMock.identity != member {
                    members.insert(contact)
                }
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                groupCreator: "MEMBER01"
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.addMembers(members)

            return Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendGroupCreateMessage(
            group: group,
            to: Array(expectedMembers),
            members: expectedMembers
        )
        task.messageAlreadySentTo["MEMBER01"] = MockData.generateMessageNonce()
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(2, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
    }

    func testExecuteNoticeGroupTextMessageWithReflecting() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!

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
                return true
            }
            return false
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx,
                myIdentityStore: myIdentityStoreMock
            ),
            entityManager: EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            )
        )

        let (messageID, group, conversation) = dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                /// See `GroupManager` line 227 for why this has to be nil
                groupCreator: nil
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.groupMyIdentity = myIdentityStoreMock.identity
            /// See `GroupManager` line 227 for why this has to be nil
            conversation.contact = nil

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: nil,
                remoteSentDate: nil
            )

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )

            return (messageID, group, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        XCTAssertNil(expectError)
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(
            1,
            serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedReflectMessage) }.count
        )
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(
            0,
            serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID)
            }.count
        )

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertTrue(textMessage.sent.boolValue)
            // Local messages don't have a remote sent date
            XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
        }
    }

    func testExecuteBroadcastGroupTextMessageWithReflecting() throws {
        let broadcastGroupTests = [
            // group name, count of message receivers, group admin receive message
            ["☁Test group", 4, 1],
            ["Test group", 3, 0],
        ]

        for broadcastGroupTest in broadcastGroupTests {
            let expectedMessageReflectID = MockData.generateReflectID()
            let expectedMessageReflectedAt = Date()
            let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMessageSentReflectID = MockData.generateReflectID()
            let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", "*ADMIN01"]
            var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
            // Second date (reflected at) is used when reflecting message sent
            var expectedReflectedAtDates = [expectedMessageReflectedAt, Date().addingTimeInterval(10)]

            let serverConnectorMock = ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: MockData.deviceID,
                deviceGroupKeys: MockData.deviceGroupKeys
            )
            serverConnectorMock.reflectMessageClosure = { _ in
                if serverConnectorMock.connectionState == .loggedIn {
                    let expectedReflectID = expectedReflectIDs.remove(at: 0)
                    let expectedReflectedAt = expectedReflectedAtDates.remove(at: 0)
                    NotificationCenter.default.post(
                        name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                        object: expectedReflectID,
                        userInfo: [expectedReflectID: expectedReflectedAt]
                    )
                    return true
                }
                return false
            }
            let myIdentityStoreMock = MyIdentityStoreMock()
            XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
            let frameworkInjectorMock = BusinessInjectorMock(
                backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
                entityManager: EntityManager(databaseContext: dbMainCnx),
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(enableMultiDevice: true),
                serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(
                    deviceGroupKeys: MockData.deviceGroupKeys,
                    returnValues: [
                        MediatorMessageProtocolMock.ReflectData(
                            id: expectedMessageReflectID,
                            message: expectedMessageReflect
                        ),
                        MediatorMessageProtocolMock.ReflectData(
                            id: expectedMessageSentReflectID,
                            message: expectedMessageSentReflect
                        ),
                    ]
                )
            )

            let (messageID, group, conversation) = dbPreparer.save {
                var members = Set<ContactEntity>()
                for member in expectedMembers {
                    let contact = dbPreparer.createContact(
                        publicKey: MockData.generatePublicKey(),
                        identity: member,
                        verificationLevel: 0
                    )
                    members.insert(contact)
                }

                let groupEntity = dbPreparer.createGroupEntity(
                    groupID: MockData.generateGroupID(),
                    groupCreator: "*ADMIN01"
                )

                let conversation = dbPreparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
                conversation.groupID = groupEntity.groupID
                conversation.groupName = broadcastGroupTest[0] as? String
                conversation.contact = members.first(where: { $0.identity == "*ADMIN01" })
                conversation.addMembers(members)

                let messageID = MockData.generateMessageID()
                self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: messageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: members.first,
                    remoteSentDate: nil
                )

                let group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: UserSettingsMock(),
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )

                return (messageID, group, conversation)
            }

            let expect = expectation(description: "TaskDefinitionSendBaseMessage")
            var expectError: Error?

            let task = TaskDefinitionSendBaseMessage(
                messageID: messageID,
                receiverIdentity: nil,
                group: group,
                sendContactProfilePicture: false
            )
            task.create(frameworkInjector: frameworkInjectorMock).execute()
                .done {
                    expect.fulfill()
                }
                .catch { error in
                    expectError = error
                    expect.fulfill()
                }

            waitForExpectations(timeout: 6)

            XCTAssertNil(expectError)
            XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
            XCTAssertEqual(
                1,
                serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }
                    .count
            )
            XCTAssertEqual(
                1,
                serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect)
                }
                .count
            )
            XCTAssertEqual(broadcastGroupTest[1] as! Int, serverConnectorMock.sendMessageCalls.count)
            XCTAssertEqual(
                broadcastGroupTest[1] as! Int,
                serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(messageID) }
                    .count
            )
            XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01"
            }.count)
            XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER02"
            }.count)
            XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03"
            }.count)
            XCTAssertEqual(
                broadcastGroupTest[2] as! Int,
                serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "*ADMIN01" }.count
            )

            try entityManager.performAndWait {
                let textMessage = try XCTUnwrap(
                    self.entityManager.entityFetcher
                        .message(with: messageID, conversation: conversation)
                )
                XCTAssert(textMessage.sent.boolValue)
                XCTAssertEqual(
                    textMessage.remoteSentDate,
                    expectedMessageReflectedAt
                )
            }
        }
    }

    func testExecuteTextMessageWithReflectingConnectionStateDisconnected() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .disconnected,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        XCTAssertNotNil(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: MockData.deviceGroupKeys,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            )
        )

        let (messageID, receiverIdentity, conversation) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: receiverIdentity,
                verificationLevel: 0
            )

            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let messageID = MockData.generateMessageID()
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                delivered: false,
                id: messageID,
                isOwn: true,
                read: false,
                sent: false,
                sender: contact,
                remoteSentDate: nil
            )

            return (messageID, receiverIdentity, conversation)
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6)

        let expectedError = try XCTUnwrap(expectError as? TaskExecutionError)
        XCTAssertEqual(
            "\(expectedError)",
            "\(TaskExecutionError.reflectMessageFailed(message: "(Reflect ID: \(expectedReflectID.hexString) (type: text; id: \(messageID.hexString)))"))"
        )
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)

        try entityManager.performAndWait {
            let textMessage = try XCTUnwrap(
                self.entityManager.entityFetcher
                    .message(with: messageID, conversation: conversation)
            )
            XCTAssertEqual(textMessage.sent.boolValue, false)
            XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
        }
    }
}
