import PromiseKit
import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class TaskExecutionTests: XCTestCase {
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    private var userSettingsMock: UserSettingsMock!
    private var serverConnectorMock: ServerConnectorMock!
    private var myIdentityStoreMock: MyIdentityStoreMock!
    private var frameworkInjectorMock: BusinessInjectorMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
        
        userSettingsMock = UserSettingsMock()
        serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        myIdentityStoreMock = MyIdentityStoreMock()
        frameworkInjectorMock = BusinessInjectorMock(
            contactStore: ContactStoreMock(callOnCompletion: true),
            entityManager: testDatabase.backgroundEntityManager,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock
        )
    }
    
    func testSendMessageWith0FeatureMask() throws {
        let expectedToIdentity1 = "TESTER01"

        dbPreparer.save {
            let contactEntity1 = dbPreparer.createContact(identity: expectedToIdentity1, featureMask: 0)
            dbPreparer.createConversation(contactEntity: contactEntity1)
        }

        let cnx = TaskContext()
        let msg1 = ContactRequestPhotoMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1

        let task = TaskDefinitionSendAbstractMessage(message: msg1, type: .volatile)
        task.nonces = [expectedToIdentity1: BytesUtility.generateMessageNonce()]

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            backgroundFrameworkInjector: frameworkInjectorMock
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
        XCTAssertTrue(task.messageAlreadySentTo.map(\.key).contains(expectedToIdentity1))
    }

    func testSendMessageAlreadySent() throws {
        let expectedToIdentity1 = "TESTER01"
        let expectedToIdentity2 = "TESTER02"

        dbPreparer.save {
            let contactEntity1 = dbPreparer.createContact(identity: expectedToIdentity1)
            dbPreparer.createConversation(contactEntity: contactEntity1)

            let contactEntity2 = dbPreparer.createContact(identity: expectedToIdentity2)
            dbPreparer.createConversation(contactEntity: contactEntity2)
        }

        let cnx = TaskContext()
        let msg1 = ContactDeletePhotoMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1

        let msg2 = ContactDeletePhotoMessage()
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = expectedToIdentity2

        let task = TaskDefinitionSendAbstractMessage(message: msg1, type: .volatile)
        task.nonces = [
            expectedToIdentity1: BytesUtility.generateMessageNonce(),
            expectedToIdentity2: BytesUtility.generateMessageNonce(),
        ]
        task.messageAlreadySentTo[expectedToIdentity1] = task.nonces[expectedToIdentity1]

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            backgroundFrameworkInjector: frameworkInjectorMock
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
        XCTAssertTrue(task.messageAlreadySentTo.map(\.key).contains(expectedToIdentity1))
        XCTAssertTrue(task.messageAlreadySentTo.map(\.key).contains(expectedToIdentity2))
    }

    func testSendMessageInvalidGroupContact() throws {
        let expectedToIdentity1 = "TESTER01"
        let expectedToIdentity2 = "TESTER02"

        let groupID = BytesUtility.generateGroupID()

        dbPreparer.save {
            dbPreparer.createContact(identity: expectedToIdentity1)
            let contactEntity = dbPreparer.createContact(identity: expectedToIdentity2)
            contactEntity.contactState = .invalid

            dbPreparer.createConversation(groupID: groupID)
        }

        let cnx = TaskContext()
        let msg1 = GroupDeletePhotoMessage()
        msg1.groupID = groupID
        msg1.groupCreator = myIdentityStoreMock.identity
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1

        let msg2 = GroupDeletePhotoMessage()
        msg2.groupID = groupID
        msg2.groupCreator = myIdentityStoreMock.identity
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = expectedToIdentity2

        let task = TaskDefinitionSendAbstractMessage(message: msg1, type: .volatile)
        task.nonces = [
            expectedToIdentity1: BytesUtility.generateMessageNonce(),
            expectedToIdentity2: BytesUtility.generateMessageNonce(),
        ]

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            backgroundFrameworkInjector: frameworkInjectorMock
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
        XCTAssertTrue(task.messageAlreadySentTo.map(\.key).contains(expectedToIdentity1))
    }

    func testSendMessageContactNotFound() throws {
        let expectedToIdentity1 = "TESTER01"

        dbPreparer.save {
            let contactEntity1 = dbPreparer.createContact(identity: expectedToIdentity1)
            dbPreparer.createConversation(contactEntity: contactEntity1)
        }

        let cnx = TaskContext()
        let msg1 = ContactRequestPhotoMessage()
        msg1.fromIdentity = myIdentityStoreMock.identity
        msg1.toIdentity = expectedToIdentity1

        let msg2 = ContactRequestPhotoMessage()
        msg2.fromIdentity = myIdentityStoreMock.identity
        msg2.toIdentity = "TESTER02"

        let task = TaskDefinitionSendAbstractMessage(message: msg1, type: .volatile)
        task.nonces = [expectedToIdentity1: BytesUtility.generateMessageNonce()]

        let taskExecution = TaskExecution(
            taskContext: cnx,
            taskDefinition: task,
            backgroundFrameworkInjector: frameworkInjectorMock
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
            XCTAssertTrue(task.messageAlreadySentTo.map(\.key).contains(expectedToIdentity1))
        }
    }
}
