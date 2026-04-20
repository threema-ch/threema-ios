import ThreemaEssentials
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

final class EntityManagerExtensionTests: XCTestCase {

    private var testDatabase: TestDatabase!

    private var ddLoggerMock: DDLoggerMock!

    override func setUp() {
        testDatabase = TestDatabase()

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDown() {
        DDLog.remove(ddLoggerMock)
    }

    func testGetOrCreateContactIfNotExists() throws {
        let expectedIdentity = "ECHOECHO"
        let expectedPublicKey = BytesUtility.generatePublicKey()

        var contactEntity: ContactEntity?

        let expect = expectation(description: "Get or create contact")

        DispatchQueue.global().async {
            contactEntity = try? self.testDatabase.backgroundEntityManager.getOrCreateContact(
                identity: expectedIdentity,
                publicKey: expectedPublicKey,
                sortOrderFirstName: true
            )

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)

        XCTAssertNotNil(contactEntity)
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "Looking for the contact entity \(expectedIdentity) on main DB context")
        )
        XCTAssertFalse(
            ddLoggerMock
                .exists(message: "Creating new contact with identity \(expectedIdentity) already exists")
        )
    }

    func testGetOrCreateContactIfExistsInMainDBContext() async throws {
        let expectedIdentity = "ECHOECHO"
        let expectedPublicKey = BytesUtility.generatePublicKey()

        // Delayed insert of the contact within main context.
        // The goal is that the contact is not present in the private but in the main DB context!
        DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(180_000)) {
            self.testDatabase.preparer.save {
                self.testDatabase.preparer.createContact(publicKey: expectedPublicKey, identity: expectedIdentity)
            }
        }

        var contactEntity: ContactEntity?

        let expect = expectation(description: "Get or create contact")

        DispatchQueue.global().async {
            contactEntity = try? self.testDatabase.backgroundEntityManager.getOrCreateContact(
                identity: expectedIdentity,
                publicKey: expectedPublicKey,
                sortOrderFirstName: true
            )

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)

        XCTAssertNotNil(contactEntity)
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "Looking for the contact entity \(expectedIdentity) on main DB context")
        )

        XCTExpectFailure("That test can fail because of timing problem, see delayed insert", options: .nonStrict()) {
            XCTAssertTrue(
                ddLoggerMock
                    .exists(message: "Apply contact entity \(expectedIdentity) to current DB context")
            )
            XCTAssertTrue(
                ddLoggerMock
                    .exists(message: "Creating new contact with identity \(expectedIdentity) already exists")
            )
        }
    }

    func testGetOrCreateMessageIfNotExists() throws {
        let expectedIdentity = "ECHOECHO"

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = expectedIdentity
        expectedAbstractMessage.toIdentity = expectedIdentity
        expectedAbstractMessage.text = "Bla"

        let preparer = testDatabase.backgroundPreparer
        let (senderContactEntity, conversationEntity) = preparer.save {
            let contactEntity = preparer.createContact(identity: expectedIdentity)
            let conversationEntity = preparer.createConversation(contactEntity: contactEntity)
            return (contactEntity, conversationEntity)
        }

        var textMessageEntity: TextMessageEntity?

        let expect = expectation(description: "Get or create message")

        DispatchQueue.global().async {
            textMessageEntity = try? self.testDatabase.backgroundEntityManager.getOrCreateMessage(
                for: expectedAbstractMessage,
                sender: senderContactEntity,
                conversation: conversationEntity,
                thumbnail: nil,
                myIdentity: MyIdentityStoreMock().identity
            ) as? TextMessageEntity

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)

        XCTAssertNotNil(textMessageEntity)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "Looking for the message \(expectedAbstractMessage.messageID.hexString) on main DB context"
                )
        )
    }

    func testGetOrCreateMessageIfExistsInMainDBContext() async throws {
        let expectedIdentity = "ECHOECHO"

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.fromIdentity = expectedIdentity
        expectedAbstractMessage.toIdentity = expectedIdentity
        expectedAbstractMessage.text = "Bla"

        testDatabase.backgroundPreparer.save {
            let contactEntity = testDatabase.backgroundPreparer.createContact(identity: expectedIdentity)
            testDatabase.backgroundPreparer.createConversation(contactEntity: contactEntity)
        }

        // Delayed insert of the message within main context.
        // The goal is that the message is not present in the private but in the main DB context!
        DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(11_968_000)) {
            self.testDatabase.preparer.save {
                let conversationEntity = self.testDatabase.entityManager.entityFetcher
                    .conversationEntity(for: expectedIdentity) as! ConversationEntity
                let contactEntity = self.testDatabase.entityManager.entityFetcher.contactEntity(for: expectedIdentity)

                self.testDatabase.preparer.createTextMessage(
                    conversation: conversationEntity,
                    delivered: false,
                    id: expectedAbstractMessage.messageID,
                    isOwn: false,
                    sender: contactEntity,
                    remoteSentDate: nil
                )
            }
        }

        var textMessageEntity: TextMessageEntity?

        let expect = expectation(description: "Get or create message")

        DispatchQueue.global().async {
            do {
                let conversationEntity = self.testDatabase.backgroundEntityManager.entityFetcher
                    .conversationEntity(for: expectedIdentity) as! ConversationEntity
                let contactEntity = self.testDatabase.backgroundEntityManager.entityFetcher
                    .contactEntity(for: expectedIdentity)

                textMessageEntity = try self.testDatabase.backgroundEntityManager.getOrCreateMessage(
                    for: expectedAbstractMessage,
                    sender: contactEntity,
                    conversation: conversationEntity,
                    thumbnail: nil,
                    myIdentity: MyIdentityStoreMock().identity
                ) as? TextMessageEntity
            }
            catch {
                XCTFail(error.localizedDescription)
            }

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)

        XCTAssertNotNil(textMessageEntity)
        XCTAssertTrue(
            ddLoggerMock
                .exists(
                    message: "Looking for the message \(expectedAbstractMessage.messageID.hexString) on main DB context"
                )
        )

        XCTExpectFailure("That test can fail because of timing problem, see delayed insert", options: .nonStrict()) {
            XCTAssertTrue(
                ddLoggerMock
                    .exists(
                        message: "Apply message \(expectedAbstractMessage.messageID.hexString) to current DB context"
                    )
            )
        }
    }

    func testExistingConversationSenderReceiverAndGetOrCreateMessageIfExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = BytesUtility.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"
        abstractMessage.toIdentity = MyIdentityStoreMock().identity

        var sender: ContactEntity?
        var conversation: ConversationEntity!
        var message: BaseMessageEntity?

        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            let publicKey2 = BytesUtility.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2
            )

            conversation = databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = sender
                }

            message = databasePreparer.createTextMessage(
                conversation: conversation!,
                text: "test 123",
                date: Date(),
                delivered: false,
                id: abstractMessage.messageID,
                isOwn: false,
                read: false,
                sent: true,
                userack: false,
                sender: sender,
                remoteSentDate: nil
            )
        }

        let expec = expectation(description: "Expec")

        var resultMessage: BaseMessageEntity?

        DispatchQueue.global().async {
            let entityManager = self.testDatabase.backgroundEntityManager
            let result = entityManager.existingConversationSenderReceiver(
                for: abstractMessage,
                myIdentity: MyIdentityStoreMock().identity
            )

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = try? entityManager.getOrCreateMessage(
                for: abstractMessage,
                sender: sender,
                conversation: result.conversation!,
                thumbnail: nil,
                myIdentity: MyIdentityStoreMock().identity
            )

            expec.fulfill()
        }

        wait(for: [expec], timeout: 6)

        XCTAssertNotNil(resultMessage)
        XCTAssertEqual(resultMessage?.objectID, message?.objectID)
        XCTAssertEqual((resultMessage as? TextMessageEntity)?.text, "test 123")
    }

    func testExistingConversationSenderReceiverAndGetOrCreateMessageIfNotExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = BytesUtility.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"
        abstractMessage.toIdentity = MyIdentityStoreMock().identity
        abstractMessage.flags = NSNumber(integerLiteral: 0)

        var sender: ContactEntity?
        var conversation: ConversationEntity!

        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            let publicKey2 = BytesUtility.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2
            )

            conversation = databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = sender
                }
        }

        let expec = expectation(description: "Expec")

        var resultMessage: BaseMessageEntity?

        DispatchQueue.global().async {
            let entityManager = self.testDatabase.backgroundEntityManager
            let result = entityManager.existingConversationSenderReceiver(
                for: abstractMessage,
                myIdentity: MyIdentityStoreMock().identity
            )

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = try? entityManager.getOrCreateMessage(
                for: abstractMessage,
                sender: sender,
                conversation: result.conversation!,
                thumbnail: nil,
                myIdentity: MyIdentityStoreMock().identity
            )

            expec.fulfill()
        }

        wait(for: [expec], timeout: 6)

        XCTAssertNotNil(resultMessage)
    }

    func testNotExistingConversationSenderReceiverAndGetOrCreateMessageIfNotExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = BytesUtility.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"
        abstractMessage.toIdentity = MyIdentityStoreMock().identity

        var sender: ContactEntity!

        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            let publicKey2 = BytesUtility.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2
            )
        }

        let expec = expectation(description: "Expec")

        var result: (conversation: ConversationEntity?, sender: ContactEntity?, receiver: ContactEntity?)

        DispatchQueue.global().async {
            let entityManager = self.testDatabase.backgroundEntityManager
            result = entityManager.existingConversationSenderReceiver(
                for: abstractMessage,
                myIdentity: MyIdentityStoreMock().identity
            )

            expec.fulfill()
        }

        wait(for: [expec], timeout: 6)

        XCTAssertEqual(result.sender?.identity, sender?.identity)
        XCTAssertNil(result.conversation)
    }

    func testDeleteMessage() throws {
        let testCases = [
            (sender: "ECHOECHO", isThrowingError: false),
            (sender: "SENDER01", isThrowingError: true),
        ]

        for testCase in testCases {
            let expectedMessageID = BytesUtility.generateMessageID()

            // Prepare test data

            let databasePreparer = testDatabase.preparer
            let conversation = databasePreparer.save {
                let contactEntity = databasePreparer.createContact(identity: "ECHOECHO")
                let conversation = databasePreparer.createConversation(contactEntity: contactEntity)

                databasePreparer.createTextMessage(
                    conversation: conversation,
                    id: expectedMessageID,
                    isOwn: false,
                    sender: contactEntity,
                    remoteSentDate: Date()
                )

                return conversation
            }

            let deleteMessage = DeleteMessage()
            deleteMessage.fromIdentity = testCase.sender
            let e2eDeleteMessage = try CspE2e_DeleteMessage.with { message in
                message.messageID = try expectedMessageID.littleEndian()
            }
            try deleteMessage.fromRawProtoBufMessage(rawProtobufMessage: e2eDeleteMessage.serializedData() as NSData)

            // Test Delete Message

            let entityManager = testDatabase.entityManager

            var deletedMessage: BaseMessageEntity? = nil

            if testCase.isThrowingError {
                XCTAssertThrowsError(
                    deletedMessage = try entityManager.deleteMessage(
                        for: deleteMessage,
                        conversation: conversation,
                        myIdentity: MyIdentityStoreMock().identity
                    )
                ) { error in
                    XCTAssertEqual(error as? ThreemaProtocolError, .messageSenderMismatch)
                }
                XCTAssertNil(deletedMessage)
            }
            else {
                XCTAssertNoThrow(
                    deletedMessage = try entityManager.deleteMessage(
                        for: deleteMessage,
                        conversation: conversation,
                        myIdentity: MyIdentityStoreMock().identity
                    )
                )
                XCTAssertNotNil(deletedMessage?.deletedAt)
            }
        }
    }

    func testEditMessage() throws {
        let testCases = [
            (sender: "ECHOECHO", isThrowingError: false),
            (sender: "SENDER01", isThrowingError: true),
        ]

        for testCase in testCases {
            let expectedMessageID = BytesUtility.generateMessageID()
            let expectedText = "Test 123"

            // Prepare test data

            let databasePreparer = testDatabase.preparer
            let conversation = databasePreparer.save {
                let contactEntity = databasePreparer.createContact(identity: "ECHOECHO")
                let conversation = databasePreparer.createConversation(contactEntity: contactEntity)

                databasePreparer.createTextMessage(
                    conversation: conversation,
                    text: "Test 1",
                    id: expectedMessageID,
                    isOwn: false,
                    sender: contactEntity,
                    remoteSentDate: Date()
                )

                return conversation
            }

            let editMessage = EditMessage()
            editMessage.fromIdentity = testCase.sender
            let e2eEditMessage = try CspE2e_EditMessage.with { message in
                message.messageID = try expectedMessageID.littleEndian()
                message.text = expectedText
            }
            try editMessage.fromRawProtoBufMessage(rawProtobufMessage: e2eEditMessage.serializedData() as NSData)

            // Test Edit Message

            let entityManager = testDatabase.entityManager

            var editedMessage: TextMessageEntity? = nil

            if testCase.isThrowingError {
                XCTAssertThrowsError(
                    editedMessage = try entityManager.editMessage(
                        for: editMessage,
                        conversation: conversation,
                        myIdentity: MyIdentityStoreMock().identity
                    ) as? TextMessageEntity
                ) { error in
                    XCTAssertEqual(error as? ThreemaProtocolError, .messageSenderMismatch)
                }
                XCTAssertNil(editedMessage)
            }
            else {
                XCTAssertNoThrow(
                    editedMessage = try entityManager.editMessage(
                        for: editMessage,
                        conversation: conversation,
                        myIdentity: MyIdentityStoreMock().identity
                    ) as? TextMessageEntity
                )
                XCTAssertNotNil(editedMessage?.lastEditedAt)
                XCTAssertEqual(editedMessage?.text, expectedText)
            }
        }
    }
}
