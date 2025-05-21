//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

final class EntityManagerTests: XCTestCase {

    private var mainCnx: NSManagedObjectContext!
    private var childCnx: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let dbContext = DatabasePersistentContext.devNullContext(withChildContextForBackgroundProcess: true)
        mainCnx = dbContext.mainContext
        childCnx = dbContext.childContext
    }

    func testExistingConversationSenderReceiverAndGetOrCreateMessageIfExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = MockData.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"

        var sender: ContactEntity?
        var conversation: ConversationEntity!
        var message: BaseMessageEntity?

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey2 = MockData.generatePublicKey()
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
            let entityManager =
                EntityManager(databaseContext: DatabaseContext(
                    mainContext: self.mainCnx,
                    backgroundContext: self.childCnx
                ))
            let result = entityManager.existingConversationSenderReceiver(for: abstractMessage)

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = try? entityManager.getOrCreateMessage(
                for: abstractMessage,
                sender: sender,
                conversation: result.conversation!,
                thumbnail: nil
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
        abstractMessage.messageID = MockData.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"

        var sender: ContactEntity?
        var conversation: ConversationEntity!

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey2 = MockData.generatePublicKey()
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
            let entityManager =
                EntityManager(databaseContext: DatabaseContext(
                    mainContext: self.mainCnx,
                    backgroundContext: self.childCnx
                ))
            let result = entityManager.existingConversationSenderReceiver(for: abstractMessage)

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = try? entityManager.getOrCreateMessage(
                for: abstractMessage,
                sender: sender,
                conversation: result.conversation!,
                thumbnail: nil
            )

            expec.fulfill()
        }

        wait(for: [expec], timeout: 6)

        XCTAssertNotNil(resultMessage)
    }

    func testNotExistingConversationSenderReceiverAndGetOrCreateMessageIfNotExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = MockData.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"

        var sender: ContactEntity!

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey2 = MockData.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2
            )
        }

        let expec = expectation(description: "Expec")

        var result: (conversation: ConversationEntity?, sender: ContactEntity?, receiver: ContactEntity?)

        DispatchQueue.global().async {
            let entityManager =
                EntityManager(databaseContext: DatabaseContext(
                    mainContext: self.mainCnx,
                    backgroundContext: self.childCnx
                ))
            result = entityManager.existingConversationSenderReceiver(for: abstractMessage)

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
            let expectedMessageID = MockData.generateMessageID()

            // Prepare test data

            let databasePreparer = DatabasePreparer(context: mainCnx)
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

            let entityManager = EntityManager(
                databaseContext: DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: nil
                ),
                myIdentityStore: MyIdentityStoreMock()
            )

            var deletedMessage: BaseMessageEntity? = nil

            if testCase.isThrowingError {
                XCTAssertThrowsError(
                    deletedMessage = try entityManager.deleteMessage(for: deleteMessage, conversation: conversation)
                ) { error in
                    XCTAssertEqual(error as? ThreemaProtocolError, .messageSenderMismatch)
                }
                XCTAssertNil(deletedMessage)
            }
            else {
                XCTAssertNoThrow(
                    deletedMessage = try entityManager.deleteMessage(for: deleteMessage, conversation: conversation)
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
            let expectedMessageID = MockData.generateMessageID()
            let expectedText = "Test 123"

            // Prepare test data

            let databasePreparer = DatabasePreparer(context: mainCnx)
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

            let entityManager = EntityManager(
                databaseContext: DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: nil
                ),
                myIdentityStore: MyIdentityStoreMock()
            )

            var editedMessage: TextMessageEntity? = nil

            if testCase.isThrowingError {
                XCTAssertThrowsError(
                    editedMessage = try entityManager.editMessage(
                        for: editMessage,
                        conversation: conversation
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
                        conversation: conversation
                    ) as? TextMessageEntity
                )
                XCTAssertNotNil(editedMessage?.lastEditedAt)
                XCTAssertEqual(editedMessage?.text, expectedText)
            }
        }
    }
}
