//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class TaskQueueTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!
    private var databasePreparer: DatabasePreparer!
    private var ddLoggerMock: DDLoggerMock!
    private var frameworkInjectorMock: FrameworkInjectorProtocol!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        databasePreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)

        frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx)
        )
    }
    
    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }
    
    func testInterrupt() {
        let msg = ContactDeletePhotoMessage()
        msg.messageID = MockData.generateMessageID()

        let task = TaskDefinitionSendAbstractMessage(message: msg, isPersistent: false)

        let tq = TaskQueue(
            queueType: .outgoing,
            supportedTypes: [TaskDefinitionSendAbstractMessage.self],
            frameworkInjector: frameworkInjectorMock
        )

        try? tq.enqueue(task: task, completionHandler: nil)
        XCTAssertEqual(.pending, task.state)

        tq.interrupt()
        XCTAssertEqual(.pending, task.state, "Test interrupt on pending item")

        tq.list.first?.taskDefinition.state = .executing
        XCTAssertEqual(.executing, task.state, "Set state to executing for testing reason")

        tq.interrupt()
        XCTAssertEqual(.interrupted, task.state, "Test interrupt on executing item")
    }

    func testSpoolServerConnectorDisconnected() {
        let tq = TaskQueue(
            queueType: .outgoing,
            supportedTypes: [TaskDefinitionSendAbstractMessage.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        tq.spool()

        DDLog.flushLog()
        XCTAssertTrue(ddLoggerMock.exists(message: "Task queue spool interrupt, because not logged in to server"))
    }

    func testSpoolTaskDefinitionSendAbstractMessage() {
        let expectedReceiverIdentity = "ECHOECHO"

        databasePreparer.save {
            let contactEntity = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedReceiverIdentity,
                verificationLevel: 0
            )
            databasePreparer.createConversation(contactEntity: contactEntity)
        }

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let myIdentityStoreMock = MyIdentityStoreMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            myIdentityStore: myIdentityStoreMock,
            serverConnector: serverConnectorMock
        )

        let tq = TaskQueue(
            queueType: .outgoing,
            supportedTypes: [TaskDefinitionSendAbstractMessage.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        let message = TypingIndicatorMessage()
        message.fromIdentity = myIdentityStoreMock.identity
        message.toIdentity = expectedReceiverIdentity
        message.typing = true

        let expec = expectation(description: "spool")

        let task = TaskDefinitionSendAbstractMessage(message: message, isPersistent: false)
        try? tq.enqueue(task: task) { _, error in
            XCTAssertNil(error)
            DDLog.flushLog()
            expec.fulfill()
        }
        
        tq.spool()

        waitForExpectations(timeout: 6) { error in
            XCTAssertNil(error)
            XCTAssertEqual(serverConnectorMock.sendMessageCalls.count, 1)
            XCTAssertTrue(
                self.ddLoggerMock
                    .exists(
                        message: "<TaskDefinitionSendAbstractMessage (type: typingIndicator; id: \(message.messageID.hexString))> done"
                    )
            )
        }
    }

    func testSpoolTaskDefinitionReceiveMessageProcessingFailedWithRetry() {
        let expectedReceiver = "ECHOECHO"
        let expectedError = NSError(domain: "Test domain", code: 1, userInfo: nil)

        databasePreparer.createContact(
            publicKey: MockData.generatePublicKey(),
            identity: expectedReceiver,
            verificationLevel: 0
        )

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let messageProcessorMock = MessageProcessorMock()
        messageProcessorMock.error = expectedError
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock
        )

        // 2 tests with: retry / processIncomingMessageCalls / completedProcessingMessageCalls / retryCount
        for test in [[false, 1, 0, 0] as [Any], [true, 2, 0, 1]] {
            // Reset mocks first
            ddLoggerMock.logMessages.removeAll()
            messageProcessorMock.processIncomingBoxedMessageCalls.removeAll()
            serverConnectorMock.completedProcessingMessageCalls.removeAll()

            let tq = TaskQueue(
                queueType: .incoming,
                supportedTypes: [TaskDefinitionReceiveMessage.self],
                frameworkInjector: frameworkInjectorMock,
                renewFrameworkInjector: false
            )

            let message = BoxedMessage()
            message.messageID = MockData.generateMessageID()
            message.fromIdentity = "TESTER01"
            message.toIdentity = expectedReceiver

            let expec = expectation(description: "spool")

            let task = TaskDefinitionReceiveMessage(
                message: message,
                receivedAfterInitialQueueSend: true,
                maxBytesToDecrypt: 0,
                timeoutDownloadThumbnail: 0
            )
            task.retry = test[0] as! Bool

            try? tq.enqueue(task: task) { _, error in
                XCTAssertNotNil(error)
                DDLog.flushLog()
                expec.fulfill()
            }
            
            tq.spool()

            waitForExpectations(timeout: 6) { error in
                XCTAssertNil(error)
                XCTAssertEqual(tq.list.count, 0, "Task must be removed from incoming queue, if it failed")
                XCTAssertEqual(messageProcessorMock.processIncomingBoxedMessageCalls.count, test[1] as! Int)
                XCTAssertEqual(serverConnectorMock.completedProcessingMessageCalls.count, test[2] as! Int)
                XCTAssertEqual(task.retryCount, test[3] as! Int)
                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: \(message.messageID.hexString))> failed Error Domain=\(expectedError.domain) Code=\(expectedError.code) \"(null)\""
                        )
                )
                if task.retry {
                    XCTAssertTrue(
                        self.ddLoggerMock
                            .exists(
                                message: "Retry of <TaskDefinitionReceiveMessage (type: BoxedMessage; id: \(message.messageID.hexString))> after execution failing"
                            )
                    )
                }
                else {
                    XCTAssertFalse(
                        self.ddLoggerMock
                            .exists(
                                message: "Retry of <TaskDefinitionReceiveMessage (type: BoxedMessage; id: \(message.messageID.hexString))> after execution failing"
                            )
                    )
                }
            }
        }
    }
    
    func testSpoolExecuteNextTaskExponentialBackoff() throws {

        let maxSpoolingDelayAttempts = 3
        var spoolingDelayAttempts = 0

        let expectedReflectID = MockData.generateReflectID()
        let expectedEnvelop = D2d_Envelope()

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            guard spoolingDelayAttempts >= maxSpoolingDelayAttempts else {
                spoolingDelayAttempts += 1

                return ThreemaError.threemaError(
                    "Not logged in",
                    withCode: ThreemaProtocolError.notLoggedIn.rawValue
                ) as? NSError
            }

            return nil
        }

        let mediatorMessageProtocolMock = MediatorMessageProtocolMock(
            deviceGroupKeys: serverConnectorMock.deviceGroupKeys!,
            returnValues: [
                try MediatorMessageProtocolMock.ReflectData(
                    id: expectedReflectID,
                    message: expectedEnvelop.serializedData()
                ),
            ]
        )

        let mediatorReflectedProcessorMock = MediatorReflectedProcessorMock()
        mediatorReflectedProcessorMock.error = ThreemaError.threemaError(
            "Not logged in",
            withCode: ThreemaProtocolError.notLoggedIn.rawValue
        ) as? NSError

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            mediatorReflectedProcessor: mediatorReflectedProcessorMock
        )

        let tq = TaskQueue(
            queueType: .incoming,
            supportedTypes: [TaskDefinitionReceiveReflectedMessage.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        let expect = expectation(description: "spool")

        let task = TaskDefinitionReceiveReflectedMessage(
            reflectID: expectedReflectID,
            reflectedEnvelope: expectedEnvelop,
            reflectedAt: Date(),
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        try? tq.enqueue(task: task) { _, error in
            XCTAssertNil(error)
            DDLog.flushLog()
            expect.fulfill()
        }

        tq.spool()

        wait(for: [expect], timeout: 6)

        XCTAssertTrue(ddLoggerMock.exists(message: "Waiting 0.5 seconds before execute next task"))
        XCTAssertTrue(ddLoggerMock.exists(message: "Waiting 1.0 seconds before execute next task"))
        XCTAssertTrue(ddLoggerMock.exists(message: "Waiting 2.0 seconds before execute next task"))
    }

    func testSpoolTaskDefinitionSendAbstractMessageReflectFailedWithRetry() {
        let expectedReceiver = "ECHOECHO"

        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            serverConnector: serverConnectorMock
        )

        // 2 tests with: retry / sendMessageCalls / retryCount
        for test in [[false, 0, 0] as [Any], [true, 0, 1]] {
            // Reset mocks first
            ddLoggerMock.logMessages.removeAll()
            serverConnectorMock.sendMessageCalls.removeAll()

            let tq = TaskQueue(
                queueType: .outgoing,
                supportedTypes: [TaskDefinitionSendAbstractMessage.self],
                frameworkInjector: frameworkInjectorMock,
                renewFrameworkInjector: false
            )

            let message = ContactDeletePhotoMessage()
            message.fromIdentity = "TESTER01"
            message.toIdentity = expectedReceiver

            let expec = expectation(description: "spool")

            let task = TaskDefinitionSendAbstractMessage(message: message, isPersistent: false)
            task.retry = test[0] as! Bool

            try? tq.enqueue(task: task) { _, error in
                XCTAssertNotNil(error)
                DDLog.flushLog()
                expec.fulfill()
            }
            
            tq.spool()

            waitForExpectations(timeout: 6) { error in
                XCTAssertNil(error)
                XCTAssertEqual(tq.list.count, 1, "Task must not removed from outgoing queue, if it failed")
                XCTAssertEqual(serverConnectorMock.sendMessageCalls.count, test[1] as! Int)
                XCTAssertEqual(task.retryCount, test[2] as! Int)
                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "<TaskDefinitionSendAbstractMessage (type: contactDeleteProfilePicture; id: \(message.messageID.hexString))> failed sendMessageFailed(message: \"Contact not found for identity Optional(\\\"\(expectedReceiver)\\\") ((type: contactDeleteProfilePicture; id: \(message.messageID.hexString)))\")"
                        )
                )
                if task.retry {
                    XCTAssertTrue(
                        self.ddLoggerMock
                            .exists(
                                message: "Retry of <TaskDefinitionSendAbstractMessage (type: contactDeleteProfilePicture; id: \(message.messageID.hexString))> after execution failing"
                            )
                    )
                }
                else {
                    XCTAssertFalse(
                        self.ddLoggerMock
                            .exists(
                                message: "Retry of <TaskDefinitionSendAbstractMessage> after execution failing"
                            )
                    )
                }
            }
        }
    }
    
    func testSpoolMultiDeviceNotActivated() {
        let serverConnectorMock = ServerConnectorMock(connectionState: .loggedIn)
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            serverConnector: serverConnectorMock
        )

        let tq = TaskQueue(
            queueType: .outgoing,
            supportedTypes: [TaskDefinitionDeleteContactSync.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        let expec = expectation(description: "spool")

        let task = TaskDefinitionDeleteContactSync(contacts: ["ECHOECHO"])

        try? tq.enqueue(task: task) { _, error in
            XCTAssertNotNil(error)
            expec.fulfill()
        }

        tq.spool()

        waitForExpectations(timeout: 6) { error in
            XCTAssertNil(error)
            XCTAssertEqual(tq.list.count, 1)
            XCTAssertEqual(task.retryCount, 1)
            XCTAssertTrue(
                self.ddLoggerMock
                    .exists(
                        message: "<TaskDefinitionDeleteContactSync> failed \(TaskExecutionError.multiDeviceNotRegistered)"
                    )
            )
        }
    }

    func testSpoolTaskDefinitionDeleteContactSyncReflectFailedWithRetry() {
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            ThreemaError.threemaError("Not logged in", withCode: ThreemaProtocolError.notLoggedIn.rawValue) as? NSError
        }
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock
        )

        // 2 tests with: retry / reflectMessageCalls / retryCount
        for test in [[false, 1, 0] as [Any], [true, 2, 1]] {
            // Reset mocks first
            ddLoggerMock.logMessages.removeAll()
            serverConnectorMock.reflectMessageCalls.removeAll()

            let tq = TaskQueue(
                queueType: .outgoing,
                supportedTypes: [TaskDefinitionDeleteContactSync.self],
                frameworkInjector: frameworkInjectorMock,
                renewFrameworkInjector: false
            )

            let expec = expectation(description: "spool")

            let task = TaskDefinitionDeleteContactSync(contacts: ["ECHOECHO"])
            task.retry = test[0] as! Bool

            try? tq.enqueue(task: task) { _, error in
                XCTAssertNotNil(error)
                DDLog.flushLog()
                expec.fulfill()
            }
            
            tq.spool()

            waitForExpectations(timeout: 10) { error in
                XCTAssertNil(error)
                XCTAssertEqual(tq.list.count, 1)
                XCTAssertEqual(serverConnectorMock.reflectMessageCalls.count, test[1] as! Int)
                XCTAssertEqual(task.retryCount, test[2] as! Int)

                self.ddLoggerMock.logMessages.forEach { m in
                    print(m.message)
                }

                XCTAssertTrue(
                    self.ddLoggerMock
                        .exists(
                            message: "<TaskDefinitionDeleteContactSync> failed reflectMessageFailed(message: Optional(\"message type: lock / Error Domain=ThreemaErrorDomain Code=675 \\\"Not logged in\\\" UserInfo={NSLocalizedDescription=Not logged in}\"))"
                        )
                )
                if task.retry {
                    XCTAssertTrue(
                        self.ddLoggerMock
                            .exists(message: "Retry of <TaskDefinitionDeleteContactSync> after execution failing")
                    )
                }
                else {
                    XCTAssertFalse(
                        self.ddLoggerMock
                            .exists(message: "Retry of task <TaskDefinitionDeleteContactSync> after execution failing")
                    )
                }
            }
        }
    }

    func testSpoolChatServerMessageWithErrors() throws {
        let tests: [(
            expectedMessageProcessorErrors: [Error],
            expectedSendMessage: Bool,
            expectedLogMessages: [String],
            expectedAck: Bool,
            expectedTaskDequeued: Bool
        )] = [
            (
                [Error](),
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                true,
                true
            ),
            (
                [
                    TaskExecutionError.wrongTaskDefinitionType,
                ],
                false,
                ["<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> failed %@"],
                false,
                true
            ),
            (
                [
                    ThreemaProtocolError.badMessage,
                    ThreemaProtocolError.blockUnknownContact,
                    ThreemaProtocolError.messageAlreadyProcessed,
                    ThreemaProtocolError.messageBlobDecryptionFailed,
                    ThreemaProtocolError.messageNonceReuse,
                    ThreemaProtocolError.unknownMessageType,
                    ThreemaError.threemaError(
                        "Message already processed",
                        withCode: ThreemaProtocolError.messageAlreadyProcessed.rawValue
                    ),
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> discard incoming message: %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                true,
                true
            ),
            (
                [
                    ThreemaProtocolError.pendingGroupMessage,
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                false,
                true
            ),
            (
                [
                    MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage,
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                false,
                true
            ),
            (
                [
                    TaskExecutionError.conversationNotFound(for: TaskDefinition(isPersistent: false)),
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> failed: %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                false,
                true
            ),
            (
                [
                    TaskExecutionError.createAbstractMessageFailed,
                    TaskExecutionError.messageReceiverBlockedOrUnknown,
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> outgoing message failed: %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                false,
                true
            ),
            (
                [
                    TaskExecutionTransactionError.shouldSkip,
                ],
                true,
                [
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> skipped: %@",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> done",
                    "<TaskDefinitionReceiveMessage (type: BoxedMessage; id: %@)> dequeue",
                ],
                false,
                true
            ),
        ]

        for test in tests {
            if test.expectedMessageProcessorErrors.isEmpty {
                spoolChatServerMessageWithError(
                    nil,
                    test.expectedSendMessage,
                    test.expectedLogMessages,
                    test.expectedAck,
                    test.expectedTaskDequeued
                )
            }
            else {
                test.expectedMessageProcessorErrors.forEach { expectedMessageProcessorError in
                    spoolChatServerMessageWithError(
                        expectedMessageProcessorError,
                        test.expectedSendMessage,
                        test.expectedLogMessages,
                        test.expectedAck,
                        test.expectedTaskDequeued
                    )
                }
            }
        }
    }

    func spoolChatServerMessageWithError(
        _ expectedMessageProcessorError: Error?,
        _ expectedSendMessage: Bool,
        _ expectedLogMessages: [String],
        _ expectedAck: Bool,
        _ expectedTaskDequeue: Bool
    ) {
        let incomingBoxedMessage = BoxedMessage()
        incomingBoxedMessage.messageID = MockData.generateMessageID()
        incomingBoxedMessage.fromIdentity = MyIdentityStoreMock().identity
        incomingBoxedMessage.toIdentity = "ECHECHO"
        incomingBoxedMessage.nonce = MockData.generateMessageNonce()

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        serverConnectorMock.sendMessageClosure = { _ in
            expectedSendMessage
        }
        let nonceGuardMock = NonceGuardMock()
        let messageProcessorMock = MessageProcessorMock()
        messageProcessorMock.error = expectedMessageProcessorError

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            messageProcessor: messageProcessorMock,
            nonceGuard: nonceGuardMock
        )

        // Reset mocks first
        ddLoggerMock.logMessages.removeAll()
        serverConnectorMock.reflectMessageCalls.removeAll()

        let taskQueue = TaskQueue(
            queueType: .incoming,
            supportedTypes: [TaskDefinitionReceiveMessage.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        let expect = expectation(description: "spool")

        let task = TaskDefinitionReceiveMessage(
            message: incomingBoxedMessage,
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        try? taskQueue.enqueue(task: task) { _, error in
            if expectedSendMessage {
                XCTAssertNil(error)
            }
            DDLog.flushLog()
            expect.fulfill()
        }

        taskQueue.spool()

        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
            XCTAssertEqual(taskQueue.list.count, expectedTaskDequeue ? 0 : 1)
            XCTAssertEqual(
                nonceGuardMock.processedCalls.count,
                expectedMessageProcessorError != nil && expectedAck ? 1 : 0
            )
            XCTAssertEqual(serverConnectorMock.completedProcessingMessageCalls.count, expectedAck ? 1 : 0)
            XCTAssertEqual(serverConnectorMock.reflectMessageCalls.count, 0)

            self.ddLoggerMock.logMessages.forEach { msg in
                print(msg.message)
            }

            expectedLogMessages.forEach { expectedLogMessage in
                if let expectedMessageProcessorError {
                    print(String(
                        format: expectedLogMessage,
                        incomingBoxedMessage.messageID.hexString,
                        "\(expectedMessageProcessorError)"
                    ))

                    XCTAssertTrue(
                        self.ddLoggerMock
                            .starts(with: String(
                                format: expectedLogMessage,
                                incomingBoxedMessage.messageID.hexString,
                                "\(expectedMessageProcessorError)"
                            ))
                    )
                }
                else {
                    print(String(
                        format: expectedLogMessage,
                        incomingBoxedMessage.messageID.hexString
                    ))

                    XCTAssertTrue(
                        self.ddLoggerMock
                            .starts(with: String(
                                format: expectedLogMessage,
                                incomingBoxedMessage.messageID.hexString
                            ))
                    )
                }
            }
        }
    }

    func testSpoolMediatorMessageWithErrors() throws {
        let tests: [(
            expectedTestIndex: Int,
            expectedMediatorReflectedProcessorErrors: [Error],
            expectedServerConnectorError: Error?,
            expectedLogMessages: [String],
            expectedAck: Bool,
            expectedNonceProcessed: Bool,
            expectedTaskDequeued: Bool
        )] = [
            (
                0,
                [Error](),
                nil,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> dequeue",
                ],
                true,
                false, // In this case message nonce already stored
                true
            ),
            (
                1,
                [Error](),
                ThreemaError.threemaError(
                    "Not logged in",
                    withCode: ThreemaProtocolError.notLoggedIn.rawValue
                ) as? NSError,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed Error Domain=ThreemaErrorDomain Code=675 \"Not logged in\" UserInfo={NSLocalizedDescription=Not logged in}",
                    "Waiting 0.5 seconds before execute next task",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed",
                ],
                true,
                false, // In this case message nonce already stored
                true
            ),
            (
                2,
                [
                    TaskExecutionError.wrongTaskDefinitionType,
                ],
                nil,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> dequeue",
                ],
                true,
                true,
                true
            ),
            (
                3,
                [
                    ThreemaProtocolError.badMessage,
                    ThreemaProtocolError.blockUnknownContact,
                    ThreemaProtocolError.messageAlreadyProcessed,
                    ThreemaProtocolError.messageBlobDecryptionFailed,
                    ThreemaProtocolError.messageNonceReuse,
                    ThreemaProtocolError.unknownMessageType,
                    ThreemaError.threemaError(
                        "Message already processed",
                        withCode: ThreemaProtocolError.messageAlreadyProcessed.rawValue
                    ),
                ],
                nil,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> dequeue",
                ],
                true,
                true,
                true
            ),
            (
                4,
                [
                    ThreemaProtocolError.badMessage,
                    ThreemaProtocolError.blockUnknownContact,
                    ThreemaProtocolError.messageAlreadyProcessed,
                    ThreemaProtocolError.messageBlobDecryptionFailed,
                    ThreemaProtocolError.messageNonceReuse,
                    ThreemaProtocolError.unknownMessageType,
                    ThreemaError.threemaError(
                        "Message already processed",
                        withCode: ThreemaProtocolError.messageAlreadyProcessed.rawValue
                    ),
                ],
                ThreemaError.threemaError(
                    "Not logged in",
                    withCode: ThreemaProtocolError.notLoggedIn.rawValue
                ) as? NSError,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed Error Domain=ThreemaErrorDomain Code=675 \"Not logged in\" UserInfo={NSLocalizedDescription=Not logged in}",
                    "Waiting 0.5 seconds before execute next task",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed",
                ],
                true,
                true,
                true
            ),
            (
                5,
                [
                    MediatorReflectedProcessorError.conversationNotFound(message: ""),
                ],
                nil,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                ],
                true,
                true,
                true
            ),
            (
                6,
                [
                    MediatorReflectedProcessorError.conversationNotFound(message: ""),
                ],
                ThreemaError.threemaError(
                    "Not logged in",
                    withCode: ThreemaProtocolError.notLoggedIn.rawValue
                ) as? NSError,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed Error Domain=ThreemaErrorDomain Code=675 \"Not logged in\" UserInfo={NSLocalizedDescription=Not logged in}",
                    "Waiting 0.5 seconds before execute next task",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> failed",
                ],
                true,
                true,
                true
            ),
            (
                7,
                [
                    MediatorReflectedProcessorError.conversationNotFound(message: ""),
                ],
                ThreemaError.threemaError(
                    "Not connected to mediator",
                    withCode: ThreemaProtocolError.notConnectedToMediator.rawValue
                ) as? NSError,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> discard reflected message: %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> sending server ack of incoming reflected message failed: Error Domain=ThreemaErrorDomain Code=676 \"Not connected to mediator\" UserInfo={NSLocalizedDescription=Not connected to mediator}",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                ],
                true,
                true,
                true
            ),
            (
                8,
                [
                    MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage,
                ],
                nil,
                [
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> %@",
                    "<TaskDefinitionReceiveReflectedMessage (type: text; id: %@)> done",
                ],
                false,
                false,
                true
            ),
        ]

        for test in tests {
            if test.expectedMediatorReflectedProcessorErrors.isEmpty {
                try spoolMediatorMessageWithError(
                    test.expectedTestIndex,
                    nil,
                    test.expectedServerConnectorError,
                    test.expectedLogMessages,
                    test.expectedAck,
                    test.expectedNonceProcessed,
                    test.expectedTaskDequeued
                )
            }
            else {
                for expectedMediatorReflectedProcessorError in test.expectedMediatorReflectedProcessorErrors {
                    try spoolMediatorMessageWithError(
                        test.expectedTestIndex,
                        expectedMediatorReflectedProcessorError,
                        test.expectedServerConnectorError,
                        test.expectedLogMessages,
                        test.expectedAck,
                        test.expectedNonceProcessed,
                        test.expectedTaskDequeued
                    )
                }
            }
        }
    }

    func spoolMediatorMessageWithError(
        _ expectedTestIndex: Int,
        _ expectedMediatorReflectedProcessorError: Error?,
        _ expectedServerConnectorError: Error?,
        _ expectedLogMessages: [String],
        _ expectedAck: Bool,
        _ expectedNonceProcessed: Bool,
        _ expectedTaskDequeued: Bool
    ) throws {
        let assertTestMessage = "Test index \(expectedTestIndex)"
        print("\(assertTestMessage) start")

        var incomingMessage = D2d_IncomingMessage()
        incomingMessage.messageID = try MockData.generateMessageID().littleEndian()
        incomingMessage.nonce = MockData.generateMessageNonce()
        incomingMessage.type = .text
        var incomingEnvelop = D2d_Envelope()
        incomingEnvelop.incomingMessage = incomingMessage

        let reflectID = MockData.generateReflectID()
        let deviceGroupKeys = MockData.deviceGroupKeys
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: deviceGroupKeys
        )

        let maxSpoolingDelayAttempts = 1
        var spoolingDelayAttempts = 0

        serverConnectorMock.reflectMessageClosure = { _ in
            if let error = expectedServerConnectorError as? NSError,
               error.code == ThreemaProtocolError.notLoggedIn.rawValue {
                guard spoolingDelayAttempts >= maxSpoolingDelayAttempts else {
                    spoolingDelayAttempts += 1

                    return expectedServerConnectorError as? NSError
                }
                return nil
            }

            return expectedServerConnectorError as? NSError
        }

        let mediatorMessageProtocolMock = MediatorMessageProtocolMock(
            deviceGroupKeys: deviceGroupKeys,
            returnValues: [
                MediatorMessageProtocolMock
                    .ReflectData(id: reflectID, message: BytesUtility.generateRandomBytes(length: 24)!),
            ]
        )
        let mediatorReflectedProcessorMock = MediatorReflectedProcessorMock()
        mediatorReflectedProcessorMock.error = expectedMediatorReflectedProcessorError

        let nonceGuardMock = NonceGuardMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: mediatorMessageProtocolMock,
            mediatorReflectedProcessor: mediatorReflectedProcessorMock,
            nonceGuard: nonceGuardMock
        )

        // Reset mocks first
        ddLoggerMock.logMessages.removeAll()
        serverConnectorMock.reflectMessageCalls.removeAll()

        let taskQueue = TaskQueue(
            queueType: .incoming,
            supportedTypes: [TaskDefinitionReceiveReflectedMessage.self],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        let expect = expectation(description: "spool")
        expect.assertForOverFulfill = expectedServerConnectorError == nil // Because of retry after error

        let task = TaskDefinitionReceiveReflectedMessage(
            reflectID: reflectID,
            reflectedEnvelope: incomingEnvelop,
            reflectedAt: Date(),
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        try? taskQueue.enqueue(task: task) { _, error in
            if expectedServerConnectorError == nil {
                XCTAssertNil(error)
            }
            DDLog.flushLog()
            expect.fulfill()
        }

        taskQueue.spool()

        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, assertTestMessage)
            XCTAssertEqual(taskQueue.list.count, expectedTaskDequeued ? 0 : 1, assertTestMessage)
            XCTAssertEqual(nonceGuardMock.processedCalls.count, expectedNonceProcessed ? 1 : 0, assertTestMessage)
            XCTAssertEqual(serverConnectorMock.completedProcessingMessageCalls.count, 0, assertTestMessage)
            if expectedAck {
                XCTAssertTrue(!serverConnectorMock.reflectMessageCalls.isEmpty, assertTestMessage)
            }
            else {
                XCTAssertTrue(serverConnectorMock.reflectMessageCalls.isEmpty, assertTestMessage)
            }

            self.ddLoggerMock.logMessages.forEach { msg in
                print(msg.message)
            }

            expectedLogMessages.forEach { expectedLogMessage in
                if let expectedMediatorReflectedProcessorError {
                    print(String(
                        format: expectedLogMessage,
                        incomingMessage.messageID.littleEndianData.hexString,
                        "\(expectedMediatorReflectedProcessorError)"
                    ))

                    XCTAssertTrue(
                        self.ddLoggerMock
                            .starts(with: String(
                                format: expectedLogMessage,
                                incomingMessage.messageID.littleEndianData.hexString,
                                "\(expectedMediatorReflectedProcessorError)"
                            )),
                        assertTestMessage
                    )
                }
                else {
                    print(String(
                        format: expectedLogMessage,
                        incomingMessage.messageID.littleEndianData.hexString
                    ))

                    XCTAssertTrue(
                        self.ddLoggerMock
                            .starts(with: String(
                                format: expectedLogMessage,
                                incomingMessage.messageID.littleEndianData.hexString
                            )),
                        assertTestMessage
                    )
                }
            }
        }

        print("\(assertTestMessage) end")
    }

    func testEncodeDecodeWithAllTaskTypes() throws {
        let expectedContactEntity = databasePreparer.save {
            let expectedContactEntity = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                conversation.contact = expectedContactEntity
            }

            return expectedContactEntity
        }

        let (_, groupEntity, conversation) = try databasePreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "ADMIN007",
            members: ["MEMBER01", "MEMBER02", "MEMBER03"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER02", "MEMBER03"]

        let tq = TaskQueue(
            queueType: .outgoing,
            supportedTypes: [
                TaskDefinitionGroupDissolve.self,
                TaskDefinitionSendAbstractMessage.self,
                TaskDefinitionSendBallotVoteMessage.self,
                TaskDefinitionSendBaseMessage.self,
                TaskDefinitionSendDeliveryReceiptsMessage.self,
                TaskDefinitionSendLocationMessage.self,
                TaskDefinitionSendGroupCreateMessage.self,
                TaskDefinitionSendGroupDeletePhotoMessage.self,
                TaskDefinitionSendGroupLeaveMessage.self,
                TaskDefinitionSendGroupRenameMessage.self,
                TaskDefinitionSendGroupSetPhotoMessage.self,
                TaskDefinitionSendGroupDeliveryReceiptsMessage.self,
                TaskDefinitionDeleteContactSync.self,
                TaskDefinitionProfileSync.self,
                TaskDefinitionUpdateContactSync.self,
                TaskDefinitionSettingsSync.self,
                TaskDefinitionReceiveMessage.self,
                TaskDefinitionReceiveReflectedMessage.self,
            ],
            frameworkInjector: frameworkInjectorMock,
            renewFrameworkInjector: false
        )

        // Add TaskDefinitionGroupDissolve
        let expectedGroupDissolveToMember = "MEMBER07"

        let taskGroupDissolve = TaskDefinitionGroupDissolve(group: expectedGroup)
        taskGroupDissolve.toMembers = [expectedGroupDissolveToMember]
        try! tq.enqueue(task: taskGroupDissolve, completionHandler: nil)

        // Add TaskDefinitionSendAbstractMessage
        let expectedAbstractMessageID = MockData.generateMessageID()
        let expectedAbstractBallotCreator = "CONTACT1"
        let expectedAbstractBallotID = MockData.generateBallotID()
        let expectedAbstractBallotJSONChoiceData = Data(repeating: 0x12, count: 10)

        let expectedAbstractMessage = BoxBallotVoteMessage()
        expectedAbstractMessage.messageID = expectedAbstractMessageID
        expectedAbstractMessage.ballotCreator = expectedAbstractBallotCreator
        expectedAbstractMessage.ballotID = expectedAbstractBallotID
        expectedAbstractMessage.jsonChoiceData = expectedAbstractBallotJSONChoiceData
        expectedAbstractMessage.toIdentity = "ECHOECHO"

        let taskAbstract = TaskDefinitionSendAbstractMessage(message: expectedAbstractMessage)
        try! tq.enqueue(task: taskAbstract, completionHandler: nil)

        // Add TaskDefinitionSendBallotVoteMessage
        let expectedBallotVoteBallotID = MockData.generateBallotID()

        let taskBallotVote = TaskDefinitionSendBallotVoteMessage(
            ballotID: expectedBallotVoteBallotID,
            receiverIdentity: expectedContactEntity.identity,
            group: nil,
            sendContactProfilePicture: false
        )
        try! tq.enqueue(task: taskBallotVote, completionHandler: nil)

        // Add TaskDefinitionSendBaseMessage
        let expectedBaseMessageGroupName = "Test group name"
        let expectedBaseMessageIsNoteGroup = false
        let expectedBaseMessageID = MockData.generateMessageID()

        let taskBase = TaskDefinitionSendBaseMessage(
            messageID: expectedBaseMessageID,
            group: expectedGroup,
            receivers: expectedGroup.members.map(\.identity),
            sendContactProfilePicture: false
        )
        taskBase.groupName = expectedBaseMessageGroupName
        taskBase.isNoteGroup = expectedBaseMessageIsNoteGroup
        try! tq.enqueue(task: taskBase, completionHandler: nil)

        // Add TaskDefinitionSendGroupDeliveryReceiptMessage
        let expectedReceiptFromIdentity = "CONTACT1"
        let expectedReceiptToIdentity = "CONTACT2"
        let expectedReceiptType: ReceiptType = .read
        let expectedReceiptMessageIDs = [
            MockData.generateMessageID(),
            MockData.generateMessageID(),
        ]
        let expectedReceiptReadDates = [
            Date(),
            Date(),
        ]

        let taskDeliveryReceipt = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: expectedReceiptFromIdentity,
            toIdentity: expectedReceiptToIdentity,
            receiptType: expectedReceiptType,
            receiptMessageIDs: expectedReceiptMessageIDs,
            receiptReadDates: expectedReceiptReadDates,
            excludeFromSending: [Data]()
        )

        try! tq.enqueue(task: taskDeliveryReceipt, completionHandler: nil)

        // Add TaskDefinitionSendLocationMessage
        let expectedLocationMessageID = MockData.generateMessageID()
        let expectedLocationPoiAddress = "poi address"

        let taskLocation = TaskDefinitionSendLocationMessage(
            poiAddress: expectedLocationPoiAddress,
            messageID: expectedLocationMessageID,
            receiverIdentity: expectedContactEntity.identity,
            group: nil,
            sendContactProfilePicture: false
        )
        try! tq.enqueue(task: taskLocation, completionHandler: nil)

        // Add TaskDefinitionSendGroupCreateMessage
        let expectedGroupCreateMessageMembers = ["TESTER01", "TESTER03"]

        let taskGroupCreateMessage = TaskDefinitionSendGroupCreateMessage(
            group: expectedGroup,
            to: expectedGroupCreateMessageMembers,
            members: Set(expectedGroupCreateMessageMembers),
            sendContactProfilePicture: false
        )

        try! tq.enqueue(task: taskGroupCreateMessage, completionHandler: nil)

        // Add TaskDefinitionSendGroupLeaveMessage
        let taskGroupLeaveMessage = TaskDefinitionSendGroupLeaveMessage(sendContactProfilePicture: false)
        taskGroupLeaveMessage.fromMember = expectedFromMember
        taskGroupLeaveMessage.toMembers = expectedToMembers
        try! tq.enqueue(task: taskGroupLeaveMessage, completionHandler: nil)

        // Add TaskDefinitionSendGroupRenameMessage
        let expectedGroupRenameName = "group name 123!!!"

        let taskGroupRenameMessage = TaskDefinitionSendGroupRenameMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            newName: expectedGroupRenameName,
            sendContactProfilePicture: false
        )

        try! tq.enqueue(task: taskGroupRenameMessage, completionHandler: nil)
        
        // Add TaskDefinitionSendGroupSetPhotoMessage
        let expectedGroupSetPhotoSize: UInt32 = 10
        let expectedGroupSetPhotoBlobID = MockData.generateBlobID()
        let expectedGroupSetPhotoEncryptionKey = MockData.generateBlobEncryptionKey()
        
        let taskGroupSetPhoto = TaskDefinitionSendGroupSetPhotoMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            size: expectedGroupSetPhotoSize,
            blobID: expectedGroupSetPhotoBlobID,
            encryptionKey: expectedGroupSetPhotoEncryptionKey,
            sendContactProfilePicture: false
        )
        
        try! tq.enqueue(task: taskGroupSetPhoto, completionHandler: nil)
        
        // Add TaskDefinitionSendGroupDeletePhotoMessage
        let taskGroupDeletePhoto = TaskDefinitionSendGroupDeletePhotoMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            sendContactProfilePicture: false
        )

        try! tq.enqueue(task: taskGroupDeletePhoto, completionHandler: nil)
        
        // Add TaskDefinitionSendGroupDeliveryReceiptMessage
        let expectedGroupReceiptType: ReceiptType = .ack
        let expectedGroupReceiptMessageIDs = [
            MockData.generateMessageID(),
            MockData.generateMessageID(),
        ]
        
        let taskGroupDeliveryReceipt = TaskDefinitionSendGroupDeliveryReceiptsMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            receiptType: expectedGroupReceiptType,
            receiptMessageIDs: expectedGroupReceiptMessageIDs,
            receiptReadDates: [Date]()
        )
        
        try! tq.enqueue(task: taskGroupDeliveryReceipt, completionHandler: nil)

        // Add TaskDefintionDeleteContactSync
        let deleteableContacts = ["ECHOECHO"]
        let taskDeleteContactSync = TaskDefinitionDeleteContactSync(contacts: deleteableContacts)
        try! tq.enqueue(task: taskDeleteContactSync, completionHandler: nil)
        
        // Add TaskDefinitionProfileSync
        var syncUserProfile = Sync_UserProfile()
        syncUserProfile.profilePicture.updated = Common_Image()
        syncUserProfile.nickname = "Test Case"
        var contacts = Common_Identities()
        contacts.identities = ["ECHOECHO", "*SUPPORT"]
        syncUserProfile.profilePictureShareWith.policy = .allowList(contacts)
        var linkPhoneNumber = Sync_UserProfile.IdentityLinks.IdentityLink()
        linkPhoneNumber.phoneNumber = "+41 000 00 00"
        syncUserProfile.identityLinks.links.append(linkPhoneNumber)
        var linkEmail = Sync_UserProfile.IdentityLinks.IdentityLink()
        linkEmail.email = "test@test.test"
        syncUserProfile.identityLinks.links.append(linkEmail)

        let profileImage = BytesUtility.generateRandomBytes(length: 512)!

        let taskProfileSync = TaskDefinitionProfileSync(
            syncUserProfile: syncUserProfile,
            profileImage: profileImage,
            linkMobileNoPending: false,
            linkEmailPending: false
        )
        try! tq.enqueue(task: taskProfileSync, completionHandler: nil)

        // Add TaskDefinitionUpdateContactSync
        var syncContact1 = Sync_Contact()
        syncContact1.identity = "ECHOECHO"
        let contact1 = DeltaSyncContact(syncContact: syncContact1, syncAction: .update)

        var syncContact2 = Sync_Contact()
        syncContact2.identity = "ECHOECHO"
        var contact2 = DeltaSyncContact(syncContact: syncContact1, syncAction: .update)
        contact2.image = Data([1])

        let updateableContacts = [contact1, contact2, contact1]

        let taskUpdateContactSync = TaskDefinitionUpdateContactSync(deltaSyncContacts: updateableContacts)
        try! tq.enqueue(task: taskUpdateContactSync, completionHandler: nil)

        // Add TaskDefinitionSettingsSync
        var syncSettings = Sync_Settings()
        syncSettings.contactSyncPolicy = .sync
        syncSettings.readReceiptPolicy = .sendReadReceipt
        syncSettings.unknownContactPolicy = .blockUnknown
        syncSettings.typingIndicatorPolicy = .sendTypingIndicator
        syncSettings.o2OCallPolicy = .allowO2OCall
        syncSettings.o2OCallConnectionPolicy = .requireRelayedConnection
        syncSettings.blockedIdentities.identities = ["ECHOECHO"]
        syncSettings.excludeFromSyncIdentities.identities = ["ECHOECHO"]

        let taskSettingsSync = TaskDefinitionSettingsSync(syncSettings: syncSettings)
        try! tq.enqueue(task: taskSettingsSync, completionHandler: nil)
        
        // Add TaskDefinitionReceiveMessage
        let taskReceiveMessage = TaskDefinitionReceiveMessage(
            message: BoxedMessage(),
            receivedAfterInitialQueueSend: true,
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )
        try! tq.enqueue(task: taskReceiveMessage, completionHandler: nil)

        // Add TaskDefinitionReceiveReflectedMessage
        let expectedReflectedAt = Date()
        let taskReceiveReflectedMessage = TaskDefinitionReceiveReflectedMessage(
            reflectID: MockData.generateReflectID(),
            reflectedEnvelope: D2d_Envelope(),
            reflectedAt: expectedReflectedAt,
            receivedAfterInitialQueueSend: false,
            maxBytesToDecrypt: 20,
            timeoutDownloadThumbnail: 30
        )
        try! tq.enqueue(task: taskReceiveReflectedMessage, completionHandler: nil)
        
        let expectedItemCount = 18
        guard tq.list.count == expectedItemCount else {
            XCTFail("TaskList has wrong number of items. Expected \(expectedItemCount) but was \(tq.list.count)")
            return
        }

        // Check none-persistent tasks
        if let task = tq.list[13].taskDefinition as? TaskDefinitionProfileSync {
            XCTAssertEqual(TaskExecutionState.pending, task.state)
            XCTAssertEqual(task.scope, .userProfileSync)
            XCTAssertEqual(task.profileImage, profileImage)
            XCTAssertEqual(task.syncUserProfile.nickname, syncUserProfile.nickname)
            XCTAssertEqual(task.syncUserProfile.profilePictureShareWith.policy, .allowList(contacts))
            XCTAssertEqual(task.syncUserProfile.identityLinks.links, syncUserProfile.identityLinks.links)
            XCTAssertEqual(task.linkMobileNoPending, false)
            XCTAssertEqual(task.linkEmailPending, false)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[15].taskDefinition as? TaskDefinitionSettingsSync {
            XCTAssertEqual(TaskExecutionState.pending, task.state)
            XCTAssertEqual(task.scope, .settingsSync)
            XCTAssertEqual(task.syncSettings.contactSyncPolicy, .sync)
            XCTAssertEqual(task.syncSettings.readReceiptPolicy, .sendReadReceipt)
            XCTAssertEqual(task.syncSettings.unknownContactPolicy, .blockUnknown)
            XCTAssertEqual(task.syncSettings.typingIndicatorPolicy, .sendTypingIndicator)
            XCTAssertEqual(task.syncSettings.o2OCallPolicy, .allowO2OCall)
            XCTAssertEqual(task.syncSettings.o2OCallConnectionPolicy, .requireRelayedConnection)
            XCTAssertEqual(task.syncSettings.blockedIdentities.identities, ["ECHOECHO"])
            XCTAssertEqual(task.syncSettings.excludeFromSyncIdentities.identities, ["ECHOECHO"])
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[16].taskDefinition as? TaskDefinitionReceiveMessage {
            XCTAssertEqual(TaskExecutionState.pending, task.state)
            XCTAssertNotNil(task.message)
            XCTAssertEqual(task.receivedAfterInitialQueueSend, true)
            XCTAssertEqual(task.maxBytesToDecrypt, 0)
            XCTAssertEqual(task.timeoutDownloadThumbnail, 0)
            XCTAssertFalse(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[17].taskDefinition as? TaskDefinitionReceiveReflectedMessage {
            XCTAssertEqual(TaskExecutionState.pending, task.state)
            XCTAssertNotNil(task.reflectedEnvelope)
            XCTAssertEqual(task.receivedAfterInitialQueueSend, false)
            XCTAssertEqual(task.reflectedAt, expectedReflectedAt)
            XCTAssertEqual(task.maxBytesToDecrypt, 20)
            XCTAssertEqual(task.timeoutDownloadThumbnail, 30)
            XCTAssertFalse(task.retry)
        }
        else {
            XCTFail()
        }

        // Encode queue
        guard let data = tq.encode() else {
            XCTFail("Could not encode queue")
            return
        }
        
        // Remove all items
        tq.removeAll()

        // Decode queue
        tq.decode(data)

        // Check persistent tasks
        let expectedItemCountAfterDecode = 14
        guard tq.list.count == expectedItemCountAfterDecode else {
            XCTFail(
                "TaskList has wrong number of items. Expected \(expectedItemCountAfterDecode) but was \(tq.list.count)"
            )
            return
        }

        if let task = tq.list[0].taskDefinition as? TaskDefinitionGroupDissolve {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(1, task.toMembers.count)
            XCTAssertTrue(task.toMembers.contains(expectedGroupDissolveToMember))
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[1].taskDefinition as? TaskDefinitionSendAbstractMessage {
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertTrue(expectedAbstractMessageID.elementsEqual(task.message.messageID))
            XCTAssertEqual(expectedAbstractBallotCreator, (task.message as! BoxBallotVoteMessage).ballotCreator)
            XCTAssertEqual(expectedAbstractBallotID, (task.message as! BoxBallotVoteMessage).ballotID)
            XCTAssertEqual(expectedAbstractBallotJSONChoiceData, (task.message as! BoxBallotVoteMessage).jsonChoiceData)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[2].taskDefinition as? TaskDefinitionSendBallotVoteMessage {
            XCTAssertEqual(expectedContactEntity.identity, task.receiverIdentity)
            XCTAssertNil(task.groupID)
            XCTAssertNil(task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertTrue(expectedBallotVoteBallotID.elementsEqual(task.ballotID))
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[3].taskDefinition as? TaskDefinitionSendBaseMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedBaseMessageGroupName, task.groupName)
            XCTAssertEqual(Set(expectedGroup.members.map(\.identity.string)), try XCTUnwrap(task.receivingGroupMembers))
            XCTAssertEqual(expectedBaseMessageIsNoteGroup, task.isNoteGroup)
            XCTAssertTrue(expectedBaseMessageID.elementsEqual(task.messageID))
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[4].taskDefinition as? TaskDefinitionSendDeliveryReceiptsMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertNil(task.groupID)
            XCTAssertNil(task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedReceiptFromIdentity, task.fromIdentity)
            XCTAssertEqual(expectedReceiptToIdentity, task.toIdentity)
            XCTAssertEqual(expectedReceiptType, task.receiptType)
            XCTAssertEqual(expectedReceiptMessageIDs, task.receiptMessageIDs)
            XCTAssertEqual(expectedReceiptReadDates, task.receiptReadDates)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[5].taskDefinition as? TaskDefinitionSendLocationMessage {
            XCTAssertEqual(expectedContactEntity.identity, task.receiverIdentity)
            XCTAssertNil(task.groupID)
            XCTAssertNil(task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertTrue(expectedLocationMessageID.elementsEqual(task.messageID))
            XCTAssertEqual(expectedLocationPoiAddress, task.poiAddress)
            XCTAssertNil(task.groupID)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[6].taskDefinition as? TaskDefinitionSendGroupCreateMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(Set(expectedGroupCreateMessageMembers), task.members)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[7].taskDefinition as? TaskDefinitionSendGroupLeaveMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertNil(task.groupID)
            XCTAssertNil(task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedFromMember, task.fromMember)
            XCTAssertEqual(expectedToMembers, task.toMembers)
            XCTAssertEqual(0, task.hiddenContacts.count)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[8].taskDefinition as? TaskDefinitionSendGroupRenameMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedFromMember, task.fromMember)
            XCTAssertEqual(expectedToMembers, task.toMembers)
            XCTAssertEqual(expectedGroupRenameName, task.name)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[9].taskDefinition as? TaskDefinitionSendGroupSetPhotoMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedFromMember, task.fromMember)
            XCTAssertEqual(expectedToMembers, task.toMembers)
            XCTAssertEqual(expectedGroupSetPhotoSize, task.size)
            XCTAssertTrue(expectedGroupSetPhotoBlobID.elementsEqual(taskGroupSetPhoto.blobID))
            XCTAssertTrue(expectedGroupSetPhotoEncryptionKey.elementsEqual(taskGroupSetPhoto.encryptionKey))
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }
        
        if let task = tq.list[10].taskDefinition as? TaskDefinitionSendGroupDeletePhotoMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedFromMember, task.fromMember)
            XCTAssertEqual(expectedToMembers, task.toMembers)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }
        
        if let task = tq.list[11].taskDefinition as? TaskDefinitionSendGroupDeliveryReceiptsMessage {
            XCTAssertNil(task.receiverIdentity)
            XCTAssertEqual(expectedGroup.groupID, task.groupID)
            XCTAssertEqual(expectedGroup.groupCreatorIdentity, task.groupCreatorIdentity)
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(expectedFromMember, task.fromMember)
            XCTAssertEqual(expectedToMembers, task.toMembers)
            XCTAssertEqual(expectedGroupReceiptType, task.receiptType)
            XCTAssertEqual(expectedGroupReceiptMessageIDs, task.receiptMessageIDs)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[12].taskDefinition as? TaskDefinitionDeleteContactSync {
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(task.scope, .contactSync)
            XCTAssertEqual(task.contacts, deleteableContacts)
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }

        if let task = tq.list[13].taskDefinition as? TaskDefinitionUpdateContactSync {
            XCTAssertEqual(.interrupted, task.state)
            XCTAssertEqual(task.scope, .contactSync)
            XCTAssertEqual(task.deltaSyncContacts.count, updateableContacts.count)
            XCTAssertEqual(
                task.deltaSyncContacts[0].syncContact.identity,
                updateableContacts[0].syncContact.identity
            )
            XCTAssertEqual(
                task.deltaSyncContacts[0].image,
                updateableContacts[0].image
            )
            XCTAssertEqual(
                task.deltaSyncContacts[1].syncContact.identity,
                updateableContacts[1].syncContact.identity
            )
            XCTAssertEqual(
                task.deltaSyncContacts[1].image,
                updateableContacts[1].image
            )
            XCTAssertEqual(
                task.deltaSyncContacts[2].syncContact.identity,
                updateableContacts[2].syncContact.identity
            )
            XCTAssertEqual(
                task.deltaSyncContacts[2].image,
                updateableContacts[2].image
            )
            XCTAssertTrue(task.retry)
        }
        else {
            XCTFail()
        }
    }
}
