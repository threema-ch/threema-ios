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

    private var ddLoggerMock: DDLoggerMock!

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
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testExecuteTextMessageWithoutReflectingConnectionStateDisconnected() throws {
        let expectedMessageID = MockData.generateMessageID()

        let serverConnectorMock = ServerConnectorMock(connectionState: .disconnected)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.contact = contact

                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            receiverIdentity: textMessage.conversation.contact?.identity,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                if let expectedError = try? XCTUnwrap(expectError as? TaskExecutionError) {
                    XCTAssertEqual(
                        "\(expectedError)",
                        "\(TaskExecutionError.sendMessageFailed(message: "(type: text; id: \(expectedMessageID.hexString))"))"
                    )
                }
                else {
                    XCTFail("Exception should be thrown")
                }
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertFalse(textMessage.sent.boolValue)
            }
        }
    }

    func testExecuteTextMessageWithoutReflecting() throws {
        let expectedMessageID = MockData.generateMessageID()

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.contact = contact

                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            receiverIdentity: textMessage.conversation.contact?.identity,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expectError)
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertTrue(textMessage.sent.boolValue)
            }
        }
    }

    func testExecuteTextMessageWithoutReflectingToInvalidContact() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedToIdentity = "ECHOECHO"

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            serverConnector: serverConnectorMock
        )

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedToIdentity,
                verificationLevel: 0
            )
            contact.state = NSNumber(integerLiteral: kStateInvalid)

            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.contact = contact

                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            receiverIdentity: textMessage.conversation.contact?.identity,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                if let expecError = expectError,
                   case let TaskExecutionError.invalidContact(message: message) = expecError {
                    XCTAssertEqual(
                        message,
                        "Do not sending message to invalid identity Optional(\"\(expectedToIdentity)\") ((type: text; id: \(expectedMessageID.hexString)))"
                    )
                }
                else {
                    XCTFail()
                }
                
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
                XCTAssertFalse(textMessage.sent.boolValue)
                XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
            }
        }
    }
    
    func testExecuteTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
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

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.contact = contact
                
                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            receiverIdentity: textMessage.conversation.contact?.identity,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
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
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertTrue(textMessage.sent.boolValue)
                XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
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

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
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
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
                conversation.addMembers(members)
                
                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: nil,
                    remoteSentDate: nil
                )
                
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: userSettingsMock,
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
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

        waitForExpectations(timeout: 600) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
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
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
                XCTAssertTrue(textMessage.sent.boolValue)
                XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflectingAndOneInvalidContact() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
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

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
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
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
                conversation.addMembers(members)
                
                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: nil,
                    remoteSentDate: nil
                )
                
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: userSettingsMock,
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "Do not sending message to invalid identity Optional(\"MEMBER04\") ((type: groupText; id: \(expectedMessageID.hexString); groupCreator: \(group.groupCreatorIdentity) - groupId: \(group.groupID.hexString)))"
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
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
                XCTAssertTrue(textMessage.sent.boolValue)
                XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflectingAlreadySent() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflectedAt = Date()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
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

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
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
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
                conversation.addMembers(members)

                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: nil,
                    remoteSentDate: nil
                )

                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: userSettingsMock,
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
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
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
                XCTAssertEqual(textMessage.remoteSentDate, expectedMessageReflectedAt)
            }
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
        
        let expectedMessageID = MockData.generateMessageID()
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", myIdentityStoreMock.identity]

        var group: Group!
        dbPreparer.save {
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
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
                conversation.addMembers(members)

                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: userSettingsMock,
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )
            }
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expectError)
                XCTAssertEqual(2, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
            }
        }
    }

    func testExecuteNoticeGroupTextMessageWithReflecting() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()

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

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: MockData.generateGroupID(),
                /// See `GroupManager` line 227 for why this has to be nil
                groupCreator: nil
            )
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                /// See `GroupManager` line 227 for why this has to be nil
                conversation.contact = nil
                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: nil,
                    remoteSentDate: nil
                )
                
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: UserSettingsMock(),
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
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

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expectError)
                XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedReflectMessage) }.count
                )
                XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(
                    0,
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertTrue(textMessage.sent.boolValue)
                // Local messages don't have a remote sent date
                XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
            }
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
            let expectedMessageID = MockData.generateMessageID()
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

            var textMessage: TextMessage!
            var group: Group!
            dbPreparer.save {
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
                dbPreparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.groupID = groupEntity.groupID
                        conversation.groupName = broadcastGroupTest[0] as? String
                        conversation.contact = members.first(where: { $0.identity == "*ADMIN01" })
                        conversation.addMembers(members)
                    
                        textMessage = self.dbPreparer.createTextMessage(
                            conversation: conversation,
                            delivered: false,
                            id: expectedMessageID,
                            isOwn: true,
                            read: false,
                            sent: false,
                            sender: members.first,
                            remoteSentDate: nil
                        )
                    
                        group = Group(
                            myIdentityStore: myIdentityStoreMock,
                            userSettings: UserSettingsMock(),
                            groupEntity: groupEntity,
                            conversation: conversation,
                            lastSyncRequest: nil
                        )
                    }
            }

            let expect = expectation(description: "TaskDefinitionSendBaseMessage")
            var expectError: Error?

            let task = TaskDefinitionSendBaseMessage(
                message: textMessage,
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

            waitForExpectations(timeout: 6) { error in
                if let error {
                    XCTFail(error.localizedDescription)
                }
                else {
                    XCTAssertNil(expectError)
                    XCTAssertEqual(2, serverConnectorMock.reflectMessageCalls.count)
                    XCTAssertEqual(
                        1,
                        serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }
                            .count
                    )
                    XCTAssertEqual(
                        1,
                        serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                            .count
                    )
                    XCTAssertEqual(broadcastGroupTest[1] as! Int, serverConnectorMock.sendMessageCalls.count)
                    XCTAssertEqual(
                        broadcastGroupTest[1] as! Int,
                        serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }
                            .count
                    )
                    XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
                    XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER02" }.count)
                    XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
                    XCTAssertEqual(
                        broadcastGroupTest[2] as! Int,
                        serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "*ADMIN01" }.count
                    )
                    XCTAssert(textMessage.sent.boolValue)
                    XCTAssertEqual(
                        textMessage.remoteSentDate,
                        expectedMessageReflectedAt
                    )
                }
            }
        }
    }
    
    func testExecuteTextMessageWithReflectingConnectionStateDisconnected() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()

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

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.contact = contact
                
                textMessage = self.dbPreparer.createTextMessage(
                    conversation: conversation,
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expect = expectation(description: "TaskDefinitionSendBaseMessage")
        var expectError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            receiverIdentity: textMessage.conversation.contact?.identity,
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
            "\(TaskExecutionError.reflectMessageFailed(message: "(Reflect ID: \(expectedReflectID.hexString) (type: text; id: \(expectedMessageID.hexString)))"))"
        )
        XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
        XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
        XCTAssertEqual(textMessage.sent.boolValue, false)
        XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
    }
}
