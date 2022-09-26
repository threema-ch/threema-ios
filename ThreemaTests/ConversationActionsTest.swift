//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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
@testable import Threema
@testable import ThreemaFramework

class ConversationActionsTest: XCTestCase {
    
    // MARK: - Setup
    
    private var mainCnx: NSManagedObjectContext!
    private var actions: ConversationActions!
    private var entityManager: EntityManager!
    private var notificationManagerMock: NotificationManagerMock!
    override func setUpWithError() throws {

        AppGroup.setGroupID("group.ch.threema")
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        let context = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        entityManager = EntityManager(databaseContext: context)
        notificationManagerMock = NotificationManagerMock()
        actions = ConversationActions(
            unreadMessages: UnreadMessagesMock(),
            entityManager: entityManager,
            notificationManager: notificationManagerMock
        )
    }
    
    private func createConversation(
        marked: Bool,
        unreadMessageCount: Int,
        category: ConversationCategory,
        visibility: ConversationVisibility
    ) -> Conversation {
        var contact: Contact!
        var conversation: Conversation!
        
        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            contact = databasePreparer.createContact(publicKey: Data([1]), identity: "ECHOECHO", verificationLevel: 0)

            conversation = databasePreparer.createConversation(
                marked: marked,
                typing: false,
                unreadMessageCount: unreadMessageCount,
                category: category,
                visibility: visibility
            ) { conversation in
                conversation.contact = contact
            }
        }
        
        return conversation
    }
    
    // MARK: - Tests

    // MARK: Pinning Conversation

    func testUnpinConversationPinned() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.unpin(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
    }
    
    func testUnpinConversationUnpinned() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.unpin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
    }
    
    func testPinConversationPinned() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.pin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertTrue(loadedConversation.marked.boolValue, "Conversation should be pinned.")
    }
    
    func testPinConversationUnpinned() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.pin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertTrue(loadedConversation.marked.boolValue, "Conversation should be pinned.")
    }

    // MARK: Archiving
    
    func testArchiveConversationUnarchived() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 19,
            category: .default,
            visibility: .default
        )
        
        actions.archive(conversation, isAppInBackground: false)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
    }
    
    func testArchiveConversationArchived() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 10,
            category: .default,
            visibility: .archived
        )
        
        actions.archive(conversation, isAppInBackground: false)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
        XCTAssertEqual(loadedConversation.unreadMessageCount, 10, "Conversation should not be marked unread.")
    }
   
    func testUnarchiveConversationUnarchived() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .default, "Conversation should be unarchived.")
    }
    
    func testUnarchiveConversationArchived() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .archived
        )
        
        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .default, "Conversation should be unarchived.")
    }
    
    // MARK: Read
    
    func testReadConversationIsMarkedUnread() throws {
        
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: -1,
            category: .default,
            visibility: .default
        )
        
        let expect = expectation(description: "Read conversation")

        actions.read(conversation, isAppInBackground: false)
            .done {
                expect.fulfill()
            }
            .catch { error in
                XCTFail(error.localizedDescription)
            }

        wait(for: [expect], timeout: 3)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.unreadMessageCount, 0, "Conversation should be marked read.")
    }

    func testUnreadConversationIsMarkedRead() throws {

        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        actions.unread(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.unreadMessageCount, -1, "Conversation should be marked unread.")
    }

    // MARK: Private

    func testMakePrivateConversationPrivate() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .private,
            visibility: .default
        )

        actions.makePrivate(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .private, "Conversation should not be private.")
    }
    
    func testMakePrivateConversationNotPrivate() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .private,
            visibility: .default
        )

        actions.makeNotPrivate(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .default, "Conversation should not be private.")
    }
    
    func testMakeNotPrivateConversationNotPrivate() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        actions.makeNotPrivate(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .default, "Conversation should not be private.")
    }
    
    func testMakeNotPrivateConversationPrivate() throws {
        let conversation = createConversation(
            marked: false,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        actions.makePrivate(conversation)
        
        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .private, "Conversation should not be private.")
    }
}
