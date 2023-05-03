//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
        var conversation: Conversation!
        var message: BaseMessage?

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey2 = MockData.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2,
                verificationLevel: 0
            )

            conversation = databasePreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
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

        var resultMessage: BaseMessage?

        DispatchQueue.global().async {
            let entityManager =
                EntityManager(databaseContext: DatabaseContext(
                    mainContext: self.mainCnx,
                    backgroundContext: self.childCnx
                ))
            let result = entityManager.existingConversationSenderReceiver(for: abstractMessage)

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = entityManager.getOrCreateMessage(
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
        XCTAssertEqual((resultMessage as? TextMessage)?.text, "test 123")
    }

    func testExistingConversationSenderReceiverAndGetOrCreateMessageIfNotExists() {
        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = MockData.generateMessageID()
        abstractMessage.fromIdentity = "ECHOECHO"
        abstractMessage.text = "test"

        var sender: ContactEntity?
        var conversation: Conversation!

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let publicKey2 = MockData.generatePublicKey()
            let identity2 = "ECHOECHO"
            sender = databasePreparer.createContact(
                publicKey: publicKey2,
                identity: identity2,
                verificationLevel: 0
            )

            conversation = databasePreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = sender
                }
        }

        let expec = expectation(description: "Expec")

        var resultMessage: BaseMessage?

        DispatchQueue.global().async {
            let entityManager =
                EntityManager(databaseContext: DatabaseContext(
                    mainContext: self.mainCnx,
                    backgroundContext: self.childCnx
                ))
            let result = entityManager.existingConversationSenderReceiver(for: abstractMessage)

            XCTAssertEqual(result.sender?.identity, "ECHOECHO")
            XCTAssertEqual(result.conversation?.objectID, conversation?.objectID)

            resultMessage = entityManager.getOrCreateMessage(
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
                identity: identity2,
                verificationLevel: 0
            )
        }

        let expec = expectation(description: "Expec")

        var result: (conversation: Conversation?, sender: ContactEntity?, receiver: ContactEntity?)

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
}
