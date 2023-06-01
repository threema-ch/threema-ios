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

    func testExecuteTextMessageWithoutReflectingConnectionSateDisconnected() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"

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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(message: textMessage, group: nil, sendContactProfilePicture: false)
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                if let expectedError = try? XCTUnwrap(expecError as? TaskExecutionError) {
                    XCTAssertEqual(
                        "\(expectedError)",
                        "\(TaskExecutionError.sendMessageFailed(message: "(type: text; id: \(expectedMessageID.hexString))"))"
                    )
                }
                else {
                    XCTFail("Execption should be thrown")
                }
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertEqual(textMessage.sent.boolValue, false)
            }
        }
    }

    func testExecuteTextMessageWithoutReflecting() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"

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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(message: textMessage, group: nil, sendContactProfilePicture: false)
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.sendMessageCalls.filter { $0.messageID.elementsEqual(expectedMessageID) }.count
                )
                XCTAssertEqual(textMessage.sent.boolValue, true)
            }
        }
    }

    func testExecuteTextMessageWithoutReflectingToInvalidContact() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedToIdentity = "ECHOECHO"
        let expectedText = "Test 123"

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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(message: textMessage, group: nil, sendContactProfilePicture: false)
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                if let expecError = expecError,
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
                XCTAssertEqual(textMessage.sent.boolValue, false)
                XCTAssertEqual(textMessage.remoteSentDate, textMessage.date)
            }
        }
    }
    
    func testExecuteTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

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
        let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(message: textMessage, group: nil, sendContactProfilePicture: false)
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
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
                XCTAssertEqual(textMessage.sent.boolValue, true)
                XCTAssertNotEqual(textMessage.remoteSentDate, textMessage.date)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflecting() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"])
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
        let myIdentityStoreMock = MyIdentityStoreMock()
        let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
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

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
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
                XCTAssertEqual(textMessage.sent.boolValue, true)
                XCTAssertNotEqual(textMessage.remoteSentDate, textMessage.date)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflectingAndOneInvalidContact() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"])
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
        let myIdentityStoreMock = MyIdentityStoreMock()
        let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
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

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "Do not sending message to invalid identity Optional(\"MEMBER04\") ((type: groupText; id: \(expectedMessageID.hexString); groupCreator: \(group.groupCreatorIdentity) - groupId: \(group.groupID.hexString)))"
                        )
                )
                XCTAssertNil(expecError)
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
                XCTAssertEqual(textMessage.sent.boolValue, true)
                XCTAssertNotEqual(textMessage.remoteSentDate, textMessage.date)
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflectingAlreadySent() throws {
        let expectedMessageReflectID = MockData.generateReflectID()
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = MockData.generateReflectID()
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"])
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
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

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            group: group,
            sendContactProfilePicture: false
        )
        task.messageAlreadySentTo.append("MEMBER01")
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
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
            }
        }
    }

    func testExecuteNoticeGroupTextMessageWithReflecting() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID
                )
                return true
            }
            return false
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx,
                myIdentityStore: myIdentityStoreMock
            ),
            entityManager: EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            myIdentityStore: myIdentityStoreMock,
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
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

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(
            message: textMessage,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error = error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
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
                XCTAssertEqual(textMessage.sent.boolValue, true)
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
            let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMessageSentReflectID = MockData.generateReflectID()
            let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMessageID = MockData.generateMessageID()
            let expectedText = "Test 123"
            let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", "*ADMIN01"]
            var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

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
            let myIdentityStoreMock = MyIdentityStoreMock()
            let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
            let frameworkInjectorMock = BusinessInjectorMock(
                backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
                entityManager: EntityManager(databaseContext: dbMainCnx),
                myIdentityStore: myIdentityStoreMock,
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
                            text: expectedText,
                            date: Date(),
                            delivered: false,
                            id: expectedMessageID,
                            isOwn: true,
                            read: false,
                            sent: false,
                            userack: false,
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

            let expec = expectation(description: "TaskDefinitionSendBaseMessage")
            var expecError: Error?

            let task = TaskDefinitionSendBaseMessage(
                message: textMessage,
                group: group,
                sendContactProfilePicture: false
            )
            task.create(frameworkInjector: frameworkInjectorMock).execute()
                .done {
                    expec.fulfill()
                }
                .catch { error in
                    expecError = error
                    expec.fulfill()
                }

            waitForExpectations(timeout: 6) { error in
                if let error = error {
                    XCTFail(error.localizedDescription)
                }
                else {
                    XCTAssertNil(expecError)
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
                }
            }
        }
    }
    
    func testExecuteTextMessageWithReflectingConnectionStateDisconnected() throws {
        let expectedReflectID = MockData.generateReflectID()
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .disconnected,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
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
                    text: expectedText,
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact,
                    remoteSentDate: nil
                )
            }
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBaseMessage(message: textMessage, group: nil, sendContactProfilePicture: false)
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6)

        let expectedError = try XCTUnwrap(expecError as? TaskExecutionError)
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
