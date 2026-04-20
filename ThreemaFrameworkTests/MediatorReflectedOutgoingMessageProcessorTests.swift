import SwiftProtobuf
import ThreemaEssentials

import ThreemaProtocols
import XCTest

@testable import ThreemaFramework

final class MediatorReflectedOutgoingMessageProcessorTests: XCTestCase {
    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var frameworkInjectorMock: BusinessInjectorMock!
    private var messageStoreMock: MessageStoreMock!

    private var processor: MediatorReflectedOutgoingMessageProcessor!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer
    }

    func testProcessAudioMessageThrowsMessageDeprecated() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxAudioMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessGroupAudioMessageThrowsMessageDeprecated() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = GroupAudioMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.groupID = BytesUtility.generateGroupID()
        expectedAbstractMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessImageMessageThrowsMessageDeprecated() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxImageMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessGroupImageMessageThrowsMessageDeprecated() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = GroupImageMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.groupID = BytesUtility.generateGroupID()
        expectedAbstractMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessVideoMessageThrowsMessageDeprecated() async throws {
        // Initialize test data and mocks
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxVideoMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessGroupVideoMessageThrowsMessageDeprecated() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = GroupVideoMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.groupID = BytesUtility.generateGroupID()
        expectedAbstractMessage.groupCreator = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessTextMessageThrowsContactNotFound() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor
                .process(outgoingMessage: expectedEnvelope.outgoingMessage, abstractMessage: expectedAbstractMessage)
        )
    }

    func testProcessTextMessage() throws {
        // Initialize test data and mocks
        dbPreparer.save {
            dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "ECHOECHO"
            )
        }
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "ECHOECHO"
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        let expec = expectation(description: "process outgoing message")
        var error: Error?
        try processor.process(
            outgoingMessage: expectedEnvelope.outgoingMessage,
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
            expectedAbstractMessage.toIdentity,
            messageStoreMock.saveTextMessageCalls.first?.conversationIdentity
        )
    }

    func testProcessGroupTextMessageThrowsGroupNotFound() throws {
        let (frameworkInjectorMock, messageStoreMock) = setUpMocks(group: nil)

        let expectedAbstractMessage = GroupTextMessage()
        expectedAbstractMessage.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        expectedAbstractMessage.groupCreator = "MEMBER01"
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "MEMBER02"
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
            frameworkInjector: frameworkInjectorMock,
            messageStore: messageStoreMock,
            messageProcessorDelegate: MessageProcessorDelegateMock(),
            reflectedAt: Date(),
            maxBytesToDecrypt: 0,
            timeoutDownloadThumbnail: 0
        )

        XCTAssertThrowsError(
            try processor.process(
                outgoingMessage: expectedEnvelope.outgoingMessage,
                abstractMessage: expectedAbstractMessage
            )
        )
    }

    func testProcessGroupTextMessage() async throws {
        // Initialize test data and mocks
        let groupID = BytesUtility.generateGroupID()
        var group: Group!
        dbPreparer.save {
            let groupCreator = dbPreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
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
        expectedAbstractMessage.fromIdentity = frameworkInjectorMock.myIdentityStore.identity
        expectedAbstractMessage.toIdentity = "MEMBER02"
        expectedAbstractMessage.text = "Test text message"
        expectedAbstractMessage.nonce = BytesUtility.generateMessageNonce()
        let expectedEnvelope = try getEnvelopeForOutgoingMessage(abstractMessage: expectedAbstractMessage)

        let processor = MediatorReflectedOutgoingMessageProcessor(
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
            outgoingMessage: expectedEnvelope.outgoingMessage,
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

    private func getEnvelopeForOutgoingMessage(abstractMessage: AbstractMessage) throws -> D2d_Envelope {
        let mediatorMessageProtocol = MediatorMessageProtocol(deviceGroupKeys: MockMultiDevice.deviceGroupKeys)
        var envelope = try mediatorMessageProtocol.getEnvelopeForOutgoingMessage(
            type: Int32(abstractMessage.type()),
            body: abstractMessage.body(),
            messageID: abstractMessage.messageID.littleEndian(),
            receiverIdentity: abstractMessage.toIdentity,
            createdAt: abstractMessage.date,
            nonce: abstractMessage.nonce,
            deviceID: MockMultiDevice.deviceID.paddedLittleEndian()
        )

        if let abstractGroupMessage = abstractMessage as? AbstractGroupMessage {
            var groupIdentity = Common_GroupIdentity()
            groupIdentity.groupID = try abstractGroupMessage.groupID.littleEndian()
            groupIdentity.creatorIdentity = abstractGroupMessage.groupCreator

            envelope.outgoingMessage.conversation.group = groupIdentity
        }
        else {
            envelope.outgoingMessage.conversation.contact = abstractMessage.toIdentity
        }

        return envelope
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
                    messageSender: MessageSenderMock(),
                    entityManager: entityManager
                )
            )
        }
        else {
            frameworkInjectorMock = BusinessInjectorMock(entityManager: testDatabase.entityManager)
        }

        return (frameworkInjectorMock, MessageStoreMock())
    }
}
