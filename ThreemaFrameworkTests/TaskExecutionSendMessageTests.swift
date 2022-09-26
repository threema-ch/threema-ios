//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(connectionState: .disconnected)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
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

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: contact
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
            }
        }
    }

    func testExecuteTextMessageWithoutReflecting() throws {
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
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

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: contact
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
            }
        }
    }

    func testExecuteTextMessageWithoutReflectingToInvalidContact() throws {
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedToIdentity = "ECHOECHO"
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
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

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity,
                verificationLevel: 0
            )
            contact.state = NSNumber(integerLiteral: kStateInvalid)

            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: contact
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
                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "Do not sending message to invalid identity Optional(\"\(expectedToIdentity)\") ((type: text; id: \(expectedMessageID.hexString)))"
                        )
                )
                XCTAssertNil(expecError)
                XCTAssertEqual(0, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
            }
        }
    }
    
    func testExecuteTextMessageWithReflecting() throws {
        let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupPathKey: BytesUtility.generateRandomBytes(length: 32)!
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
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
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
            ),
            messageProcessor: MessageProcessorMock()
        )

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: contact
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
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflecting() throws {
        let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"])
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupPathKey: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
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
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
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
            ),
            messageProcessor: MessageProcessorMock()
        )

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
            var members = Set<Contact>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: "MEMBER01"
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: nil
                )
                
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
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
            }
        }
    }
    
    func testExecuteGroupTextMessageWithReflectingAlreadySent() throws {
        let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"])
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupPathKey: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
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
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
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
            ),
            messageProcessor: MessageProcessorMock()
        )

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
            var members = Set<Contact>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: "MEMBER01"
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: nil
                )

                group = Group(
                    myIdentityStore: myIdentityStoreMock,
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
        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupPathKey: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
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
        let frameworkInjectorMock = BusinessInjectorMock(
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
            userSettings: UserSettingsMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            ),
            messageProcessor: MessageProcessorMock()
        )

        var textMessage: TextMessage!
        var group: Group!
        dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: nil
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity
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
                    sender: nil
                )
                
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
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
            let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMessageSentReflectID = BytesUtility
                .generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
            let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            let expectedText = "Test 123"
            let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03", "*ADMIN01"]
            var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

            let serverConnectorMock = ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
                deviceGroupPathKey: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
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
                backgroundGroupManager: GroupManagerMock(),
                backgroundUnreadMessages: UnreadMessagesMock(),
                contactStore: ContactStoreMock(),
                entityManager: EntityManager(databaseContext: dbMainCnx),
                groupManager: GroupManagerMock(),
                licenseStore: LicenseStore.shared(),
                messageSender: MessageSenderMock(),
                multiDeviceManager: MultiDeviceManagerMock(),
                myIdentityStore: myIdentityStoreMock,
                userSettings: UserSettingsMock(),
                serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(
                    deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
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
                ),
                messageProcessor: MessageProcessorMock()
            )

            var textMessage: TextMessage!
            var group: Group!
            dbPreparer.save {
                var members = Set<Contact>()
                for member in expectedMembers {
                    let contact = dbPreparer.createContact(
                        publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                        identity: member,
                        verificationLevel: 0
                    )
                    members.insert(contact)
                }

                let groupEntity = dbPreparer.createGroupEntity(
                    groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                    groupCreator: "*ADMIN01"
                )
                dbPreparer
                    .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                            sender: members.first
                        )
                    
                        group = Group(
                            myIdentityStore: myIdentityStoreMock,
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
                }
            }
        }
    }
    
    func testExecuteTextMessageWithReflectingConnectionStateDisconnected() throws {
        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedText = "Test 123"

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .disconnected,
            deviceID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!,
            deviceGroupPathKey: BytesUtility.generateRandomBytes(length: 32)!
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupPathKey: serverConnectorMock.deviceGroupPathKey,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            ),
            messageProcessor: MessageProcessorMock()
        )

        var textMessage: TextMessage!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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
                    sender: contact
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
    }
}
