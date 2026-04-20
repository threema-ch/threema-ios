import SwiftProtobuf
import ThreemaEssentials

import ThreemaProtocols
import XCTest

@testable import ThreemaFramework

final class MediatorReflectedIncomingMessageProcessorTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var frameworkInjectorMock: BusinessInjectorMock!
    private var messageStoreMock: MessageStoreMock!

    override func setUp() {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)

        super.setUp()
    }

    func testProcessTextMessageThrowsContactNotFound() async throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForIncomingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedIncomingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(incomingMessage: expectedEnvelope.incomingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessTextMessage() async throws {
        // Initialize test data and mocks
        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "ECHOECHO"
            )
        }
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = "ECHOECHO"
        expectedAbstractMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForIncomingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedIncomingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        let expec = expectation(description: "process incoming message")
        var error: Error?
        try processor.process(
            incomingMessage: expectedEnvelope.incomingMessage,
            abstractMessage: expectedAbstractMessage
        )
        .ensure {
            expec.fulfill()
        }
        .catch { err in
            error = err
        }

        wait(for: [expec], timeout: 1)

        XCTAssertNil(error)
        XCTAssertEqual(1, messageStoreMock.saveTextMessageCalls.count)
        XCTAssertEqual(
            expectedAbstractMessage.messageID,
            messageStoreMock.saveTextMessageCalls.first?.textMessage.messageID
        )
        XCTAssertEqual(expectedAbstractMessage.text, messageStoreMock.saveTextMessageCalls.first?.textMessage.text)
        XCTAssertEqual(
            expectedAbstractMessage.fromIdentity,
            messageStoreMock.saveTextMessageCalls.first?.conversationIdentity
        )
    }

    func testProcessGroupTextMessageThrowsGroupNotFound() async throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = GroupTextMessage()
        expectedAbstractMessage.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        expectedAbstractMessage.groupCreator = "MEMBER01"
        expectedAbstractMessage.fromIdentity = "MEMBER02"
        expectedAbstractMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForIncomingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedIncomingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor.process(
                incomingMessage: expectedEnvelope.incomingMessage,
                abstractMessage: expectedAbstractMessage
            )
        )
    }

    func testProcessGroupTextMessageThrowsContactNotFound() async throws {
        // Initialize test data and mocks
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        var group: Group!
        dbPreparer.save {
            let groupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "MEMBER01"
            )
            let conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = groupID
                    conversation.contact = groupCreator
                }
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: "MEMBER01"
            )

            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }
        let (
            frameworkInjectorMock,
            messageStoreMock
        ) = setUpMocks(group: group)

        let expectedAbstractMessage = GroupTextMessage()
        expectedAbstractMessage.groupID = groupID
        expectedAbstractMessage.groupCreator = "MEMBER01"
        expectedAbstractMessage.fromIdentity = "MEMBER02"
        expectedAbstractMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForIncomingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedIncomingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor.process(
                incomingMessage: expectedEnvelope.incomingMessage,
                abstractMessage: expectedAbstractMessage
            )
        )
    }

    func testProcessGroupTextMessage() async throws {
        // Initialize test data and mocks
        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        var group: Group!
        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "MEMBER02"
            )
            let groupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "MEMBER01"
            )
            let conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.groupID = groupID
                    conversation.contact = groupCreator
                }
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: "MEMBER01"
            )

            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }
        let (
            frameworkInjectorMock,
            messageStoreMock
        ) = setUpMocks(group: group)

        let expectedAbstractMessage = GroupTextMessage()
        expectedAbstractMessage.groupID = groupID
        expectedAbstractMessage.groupCreator = "MEMBER01"
        expectedAbstractMessage.fromIdentity = "MEMBER02"
        expectedAbstractMessage.toIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForIncomingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedIncomingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        let expec = expectation(description: "process incoming message")
        var error: Error?
        try processor.process(
            incomingMessage: expectedEnvelope.incomingMessage,
            abstractMessage: expectedAbstractMessage
        )
        .ensure {
            expec.fulfill()
        }
        .catch { err in
            error = err
        }

        wait(for: [expec], timeout: 1)

        XCTAssertNil(error)
        XCTAssertEqual(0, messageStoreMock.saveTextMessageCalls.count)
        XCTAssertEqual(1, messageStoreMock.saveGroupTextMessageCalls.count)
        XCTAssertEqual(
            expectedAbstractMessage.messageID,
            messageStoreMock.saveGroupTextMessageCalls.first?.groupTextMessage.messageID
        )
        XCTAssertEqual(
            expectedAbstractMessage.text,
            messageStoreMock.saveGroupTextMessageCalls.first?.groupTextMessage.text
        )
        XCTAssertEqual(
            expectedAbstractMessage.fromIdentity,
            messageStoreMock.saveGroupTextMessageCalls.first?.senderIdentity
        )
    }

    private func getEnvelopeForIncomingMessage(abstractMessage: AbstractMessage) throws -> D2d_Envelope {
        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockMultiDevice.deviceGroupKeys)
        return try mediatorMessageProtocol.getEnvelopeForIncomingMessage(
            type: Int32(abstractMessage.type()),
            body: abstractMessage.body(),
            messageID: abstractMessage.messageID.littleEndian(),
            senderIdentity: abstractMessage.fromIdentity,
            createdAt: abstractMessage.date,
            nonce: abstractMessage.nonce
        )
    }

    private func setUpMocks(group: Group?)
        -> (frameworkInjectorMock: BusinessInjectorMock, messageStoreMock: MessageStoreMock) {

        if let group {
            let entityManager = testDatabase.backgroundEntityManager
            let groupManagerMock = GroupManagerMock()
            groupManagerMock.getGroupReturns.append(group)

            frameworkInjectorMock = BusinessInjectorMock(
                entityManager: entityManager,
                groupManager: groupManagerMock,
                unreadMessages: UnreadMessages(
                    entityManager: entityManager,
                    taskManager: TaskManagerMock()
                )
            )
        }
        else {
            frameworkInjectorMock = BusinessInjectorMock(entityManager: testDatabase.backgroundEntityManager)
        }

        return (frameworkInjectorMock, MessageStoreMock())
    }
}
