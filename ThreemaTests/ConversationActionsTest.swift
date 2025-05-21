//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
    
    private var dbPreparer: DatabasePreparer!
    private var businessInjectorMock: BusinessInjectorMock!
    private var backgroundBusinessInjectorMock: BusinessInjectorMock!
    private var notificationManagerMock: NotificationManagerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, dbMainCnx, dbBackgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)

        dbPreparer = DatabasePreparer(context: dbMainCnx)

        let entityManager =
            EntityManager(databaseContext: DatabaseContext(mainContext: dbMainCnx, backgroundContext: nil))
        businessInjectorMock = BusinessInjectorMock(
            conversationStore: ConversationStore(
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupManager: GroupManagerMock(),
                entityManager: entityManager,
                taskManager: nil
            ),
            entityManager: entityManager
        )

        let backgroundEntityManager =
            EntityManager(databaseContext: DatabaseContext(mainContext: dbMainCnx, backgroundContext: dbBackgroundCnx))
        backgroundBusinessInjectorMock = BusinessInjectorMock(
            conversationStore: ConversationStore(
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupManager: GroupManagerMock(),
                entityManager: backgroundEntityManager,
                taskManager: nil
            ),
            entityManager: backgroundEntityManager
        )

        notificationManagerMock = NotificationManagerMock()
    }
    
    private func createConversation(
        unreadMessageCount: Int,
        category: ConversationEntity.Category,
        visibility: ConversationEntity.Visibility
    ) -> ConversationEntity {
        var contact: ContactEntity!
        var conversation: ConversationEntity!
        
        dbPreparer.save {
            contact = dbPreparer.createContact(
                publicKey: Data([1]),
                identity: "ECHOECHO"
            )

            conversation = dbPreparer.createConversation(
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
            unreadMessageCount: 19,
            category: .default,
            visibility: .pinned
        )
        
        let actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        actions.archive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
    }
    
    func testArchiveConversationArchived() throws {
        let conversation = createConversation(
            unreadMessageCount: 10,
            category: .default,
            visibility: .archived
        )
        
        let actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        actions.archive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be archived.")
        XCTAssertEqual(loadedConversation.unreadMessageCount, 10, "Conversation should not be marked unread.")
    }
   
    func testUnarchiveConversationUnarchived() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .pinned
        )
        
        let actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertNotEqual(loadedConversation.conversationVisibility, .archived, "Conversation should be unarchived.")
        XCTAssertEqual(loadedConversation.conversationVisibility, .pinned, "Conversation should be pinned.")
    }
    
    func testUnarchiveConversationArchived() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .archived
        )
        
        let actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        actions.unarchive(conversation)
        
        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )
        
        XCTAssertEqual(loadedConversation.conversationVisibility, .default, "Conversation should be unarchived.")
        XCTAssertNotEqual(loadedConversation.conversationVisibility, .pinned, "Conversation should be unpinned.")
    }
    
    // MARK: Read
    
    func testReadConversationIsMarkedUnread() async throws {

        let conversation = createConversation(
            unreadMessageCount: -1,
            category: .default,
            visibility: .default
        )

        let actions = ConversationActions(
            businessInjector: backgroundBusinessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        await actions.read(conversation, isAppInBackground: false)

        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.unreadMessageCount, 0, "Conversation should be marked read.")
    }

    func testUnreadConversationIsMarkedRead() throws {

        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        let actions = ConversationActions(
            businessInjector: businessInjectorMock,
            notificationManagerResolve: { _ in
                self.notificationManagerMock
            }
        )

        actions.unread(conversation)

        let loadedConversation = try XCTUnwrap(
            businessInjectorMock.entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.unreadMessageCount, -1, "Conversation should be marked unread.")
    }
}
