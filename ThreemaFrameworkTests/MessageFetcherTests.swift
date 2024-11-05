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

import XCTest
@testable import ThreemaFramework

class MessageFetcherTests: XCTestCase {

    private var databasePreparer: DatabasePreparer!
    private var conversation: ConversationEntity!

    private var entityManager: EntityManager!
    private var messageFetcher: MessageFetcher!

    private let testTextMessages = [
        "Hello",
        "How are you?",
        "Lorem ipsum dolor sit amet. Quo similique eius id ipsam dignissimos ut debitis dolores sit illum fuga et providednt soluta nam aliquid aspernatur qui Quis voluptates. Ut porro nesciunt ut aperiam dolorem 33 accusamus voluptatem id eius quaerat...",
        "At ducimus illo sit vitae molestiae hxic voluptas labore At nisi voluptatibus qui eius repellat. Et assumenda aliquam non Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatumd. Ut dolore pariatur a voluptate voluptatem et similique aliquid! Et itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga.",
        "Dolor praesentium sed quia natus [ad quod impedit] ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totam?",
        "Lorem ipsum sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore mdagna aliqua.",
        "At ducimus illo sit vitae molestiae hic voluptas labore At nisi voluptatibus qui eius repellat.\nEt assumenda aliquam non Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatum. Ut dolore pariatur a voluptate voluptatem et similique aliquid!\nEt itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga. 🎉",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Lorem dipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "😊😃",
        "Lorem ipsum dolor sit damet. Quo similique eius id ipsam dignissimos ut debitis dolores sit illum fuga et provident soluta nam aliquid aspernatur qui Quis voluptates. Ut porro nesciunt ut aperiam dolorem 33 accusamus voluptatem id eius quaerat.",
        "At ducimus illo sit vitae molestiae hic voluptas labore At nisi voluptatibus qui eius repellat. Et assumenda aliquam non Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatum. Ut dolore pariatur a voluptate voluptatem et similique aliquid! Et itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga.",
        "Dolor praesentium sed quia natus ad quod impedit ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totamd?",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed d ut labore et dolore magna aliqua. Eiusmod tempor incididunt.",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore a magna aliqua.",
        "At ducimus illo sit vitae molestiae hic voluptas labore At nisi voluptatibus qui eius repellat.\nEt assumenda aliquam non Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatum. Ut dolore pardiatur a voluptate voluptatem et similique aliquid!\nEt itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga.",
        "Lorem ipsum dolor sit, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Lorem ipsum dolor sit amets, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "How are you doing?",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.",
        "At ducimus illo sit vitae Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatum. Ut dolore pariatur a voluptate voluptatem et similique aliquid!\nEt itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga.",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua!",
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "😀😃😄😁",
        "Lorem ipsum dolor fsit amet. Quo similique eius id ipsam dignissimos ut debitis dolores sit illum fuga et provident soluta nam aliquid aspernatur qui Quis voluptates. Ut porro nesciunt ut aperiam dolorem 33 accusamus voluptatem id eius quaerat.",
        "At ducimus illo esit vitae molestiae hic voluptas labore At nisi voluptatibus qui eius repellat. Et assumenda aliquam non Quis saepe non doloribus dolorum aut voluptatem dolorem in odio deleniti hic nemo voluptatum. Ut dolore pariatur a voluptate voluptatem et similique aliquid! Et itaque adipisci qui autem suscipit et perferendis galisum est iusto quia sed voluptatem fuga.",
        "Dolor praesentium sed xquia natus ad quod impedit ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totam?",
    ]
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        
        databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
            
            for testTextMessage in testTextMessages {
                databasePreparer.createTextMessage(
                    conversation: conversation,
                    text: testTextMessage,
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: true,
                    sent: true,
                    userack: false,
                    sender: nil,
                    remoteSentDate: Date()
                )
            }
        }
        
        let databaseContext = try XCTUnwrap(DatabaseContext(mainContext: mainCnx, backgroundContext: nil))
        entityManager = EntityManager(databaseContext: databaseContext)
        messageFetcher = MessageFetcher(for: conversation, with: entityManager)
    }

    func testCount() throws {
        XCTAssertEqual(messageFetcher.count(), testTextMessages.count)
    }

    func testMessagesAtOffset() throws {
        let offset = 10
        let count = 10
        
        let messages = messageFetcher.messages(at: offset, count: 10)
        
        XCTAssertEqual(messages.count, count)
        
        for (index, message) in messages.enumerated() {
            let textMessage = try XCTUnwrap(message as? TextMessageEntity)
            
            XCTAssertEqual(textMessage.text, testTextMessages[offset + index])
        }
    }
    
    func testMessagesAtOffsetWithEmptyConversation() {
        var emptyConversation: ConversationEntity!
        databasePreparer.save {
            emptyConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
        
        let emptyConversationMessageFetcher = MessageFetcher(for: emptyConversation, with: entityManager)
        
        let noMessages = emptyConversationMessageFetcher.messages(at: 10, count: 40)
        
        XCTAssertEqual(noMessages.count, 0)
    }
    
    func testMessagesAtOffsetDescending() throws {
        let offset = 15
        let count = 10
        
        messageFetcher.orderAscending = false
        let messages = messageFetcher.messages(at: offset, count: count)
        
        XCTAssertEqual(messages.count, count)
        
        let expectedTextMessages: [String] = testTextMessages.reversed()
        
        for (index, message) in messages.enumerated() {
            let textMessage = try XCTUnwrap(message as? TextMessageEntity)
            
            XCTAssertEqual(textMessage.text, expectedTextMessages[offset + index])
        }
    }

    func testUnreadMessages() throws {
        let unreadTextMessages = [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 👋🏼",
            "😀😃😄😁",
            "Lorem ipsum dolor sit amet. Quo similique eius id ipsam dignissimos ut debitis dolores sit illum fuga et provident soluta qui Quis voluptates. Ut porro nesciunt ut aperiam dolorem 33 accusamus voluptatem id eius quaerat. More...",
        ]
        
        for message in unreadTextMessages {
            databasePreparer.createTextMessage(
                conversation: conversation,
                text: message,
                date: Date(),
                delivered: true,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: true,
                userack: false,
                sender: nil,
                remoteSentDate: Date()
            )
        }
        
        let unreadMessages = try XCTUnwrap(messageFetcher.unreadMessages())
        
        XCTAssertEqual(unreadMessages.count, unreadTextMessages.count)
        
        // Unread messages are always sorted descending, thus we need to reverse the inserted messages
        let expectedUnreadMessages: [String] = unreadTextMessages.reversed()
        for (index, message) in unreadMessages.enumerated() {
            let textMessage = try XCTUnwrap(message as? TextMessageEntity)
            
            XCTAssertEqual(textMessage.text, expectedUnreadMessages[index])
        }
    }
    
    func testRejectedGroupMessages() throws {
        let rejectedTextMessages = [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 👋🏼",
            "😀😃😄😁",
            "Lorem ipsum dolor sit amet. Quo similique eius id ipsam dignissimos ut debitis dolores sit illum fuga et provident soluta qui Quis voluptates. Ut porro nesciunt ut aperiam dolorem 33 accusamus voluptatem id eius quaerat. More...",
        ]
        let testContactIdentity = "CONTACT1"
        
        let contact = databasePreparer.createContact(identity: testContactIdentity)
            
        for message in rejectedTextMessages {
            let textMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: message,
                date: Date(),
                delivered: true,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: true,
                userack: false,
                sender: nil,
                remoteSentDate: Date()
            )
            textMessage.addRejectedBy(contact)
        }
        
        let rejectedMessages = messageFetcher.rejectedGroupMessages()
        
        XCTAssertEqual(rejectedMessages.count, rejectedTextMessages.count)
    }
    
    // MARK: Last display message

    func testLastDisplayMessageIsTextMessage() throws {
        let result = try XCTUnwrap(messageFetcher.lastDisplayMessage() as? TextMessageEntity)

        XCTAssertEqual(
            "Dolor praesentium sed xquia natus ad quod impedit ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totam?",
            result.text
        )
    }

    func testLastDisplayMessageIsSystemMessageFsDebugMessage() throws {
        databasePreparer.save {
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageFsDisabledOutgoing)
            databasePreparer.createSystemMessage(conversation: conversation, type: kFsDebugMessage)
        }

        let result = try XCTUnwrap(messageFetcher.lastDisplayMessage() as? TextMessageEntity)

        XCTAssertEqual(
            "Dolor praesentium sed xquia natus ad quod impedit ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totam?",
            result.text
        )
    }

    func testLastDisplayMessageCheckIsSystemMessageGroupCreatorLeft() throws {
        databasePreparer.save {
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageFsDisabledOutgoing)
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageGroupCreatorLeft)
        }

        let result = try XCTUnwrap(messageFetcher.lastDisplayMessage() as? SystemMessageEntity)

        XCTAssertEqual(kSystemMessageGroupCreatorLeft, result.type.intValue)
    }
    
    // MARK: Last message
    
    func testLastMessageIsTextMessage() throws {
        let result = try XCTUnwrap(messageFetcher.lastMessage() as? TextMessageEntity)
    
        XCTAssertEqual(
            "Dolor praesentium sed xquia natus ad quod impedit ex quibusdam temporibus. Qui blanditiis rerum et sapiente praesentium ut corporis totam?",
            result.text
        )
    }
    
    func testLastMessageIsSystemMessageFsDebugMessage() throws {
        databasePreparer.save {
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageFsDisabledOutgoing)
            databasePreparer.createSystemMessage(conversation: conversation, type: kFsDebugMessage)
        }
    
        let result = try XCTUnwrap(messageFetcher.lastMessage() as? SystemMessageEntity)
    
        XCTAssertEqual(kFsDebugMessage, result.type.intValue)
    }
    
    func testLastMessageCheckIsSystemMessageGroupCreatorLeft() throws {
        databasePreparer.save {
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageFsDisabledOutgoing)
            databasePreparer.createSystemMessage(conversation: conversation, type: kSystemMessageGroupCreatorLeft)
        }
    
        let result = try XCTUnwrap(messageFetcher.lastMessage() as? SystemMessageEntity)
    
        XCTAssertEqual(kSystemMessageGroupCreatorLeft, result.type.intValue)
    }
}
