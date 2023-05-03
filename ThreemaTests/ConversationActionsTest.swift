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
    private var businessInjectorMock: BusinessInjectorMock!
    private var notificationManagerMock: NotificationManagerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        let databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)

        let entityManager = EntityManager(databaseContext: databaseMainCnx)

        businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseMainCnx),
            conversationStore: ConversationStore(entityManager: entityManager),
            entityManager: entityManager
        )

        notificationManagerMock = NotificationManagerMock()
        actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManager: notificationManagerMock
        )
    }
    
    private func createConversation(
        marked: Bool,
        unreadMessageCount: Int,
        category: ConversationCategory,
        visibility: ConversationVisibility
    ) -> Conversation {
        var contact: ContactEntity!
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

    // MARK: Archiving
    
    func testArchiveConversationUnarchived() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 19,
            category: .default,
            visibility: .default
        )
        
        actions.archive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
    }
    
    func testArchiveConversationArchived() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 10,
            category: .default,
            visibility: .archived
        )
        
        actions.archive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
        XCTAssertTrue(loadedConversation.marked.boolValue, "Conversation should be pinned.")
        XCTAssertEqual(loadedConversation.unreadMessageCount, 10, "Conversation should not be marked unread.")
    }
   
    func testUnarchiveConversationUnarchived() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )
        
        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .default, "Conversation should be unarchived.")
        XCTAssertTrue(loadedConversation.marked.boolValue, "Conversation should be pinned.")
    }
    
    func testUnarchiveConversationArchived() throws {
        let conversation = createConversation(
            marked: true,
            unreadMessageCount: 0,
            category: .default,
            visibility: .archived
        )
        
        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .default, "Conversation should be unarchived.")
        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
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

        wait(for: [expect], timeout: 3)

        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
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
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.unreadMessageCount, -1, "Conversation should be marked unread.")
    }
}
