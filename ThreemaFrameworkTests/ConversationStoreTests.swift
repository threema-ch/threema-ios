//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import CoreData
import XCTest
@testable import ThreemaFramework

final class ConversationStoreTests: XCTestCase {

    private var mainCnx: NSManagedObjectContext!
    private var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        entityManager = EntityManager(databaseContext: DatabaseContext(mainContext: mainCnx, backgroundContext: nil))
    }

    func testUnpinConversationPinned() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .pinned
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.unpin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
    }

    func testUnpinConversationUnpinned() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.unpin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertFalse(loadedConversation.marked.boolValue, "Conversation should be unpinned.")
    }

    func testPinConversationPinned() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .pinned
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.pin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationVisibility, .pinned, "Conversation should be pinned.")
    }

    func testPinConversationUnpinned() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.pin(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager
                .conversation(forContact: conversation.contact!, createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationVisibility, .pinned, "Conversation should be pinned.")
    }

    func testMakePrivateConversationPrivate() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .private,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.makePrivate(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager.conversation(forContact: XCTUnwrap(conversation.contact), createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .private, "Conversation should be private.")
    }

    func testMakePrivateConversationNotPrivate() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .private,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.makeNotPrivate(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager.conversation(forContact: XCTUnwrap(conversation.contact), createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .default, "Conversation should not be private.")
    }

    func testMakeNotPrivateConversationNotPrivate() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.makeNotPrivate(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager.conversation(forContact: XCTUnwrap(conversation.contact), createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .default, "Conversation should not be private.")
    }

    func testMakeNotPrivateConversationPrivate() throws {
        let conversation = createConversation(
            unreadMessageCount: 0,
            category: .default,
            visibility: .default
        )

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: TaskManager()
        )
        conversationStore.makePrivate(conversation)

        let loadedConversation = try XCTUnwrap(
            entityManager.conversation(forContact: XCTUnwrap(conversation.contact), createIfNotExisting: false)
        )

        XCTAssertEqual(loadedConversation.conversationCategory, .private, "Conversation should not private.")
    }

    func testUnmarkAllPrivateConversations() throws {
        createConversation(
            unreadMessageCount: 0,
            category: .private,
            visibility: .default
        )
        createConversation(
            unreadMessageCount: 0,
            category: .private,
            visibility: .default,
            for: "MEMBER01"
        )

        let taskManagerMock = TaskManagerMock()

        let conversationStore = ConversationStore(
            userSettings: UserSettingsMock(enableMultiDevice: true),
            pushSettingManager: PushSettingManagerMock(),
            groupManager: GroupManagerMock(),
            entityManager: entityManager,
            taskManager: taskManagerMock
        )

        conversationStore.unmarkAllPrivateConversations()

        let conversations = try XCTUnwrap(
            entityManager.entityFetcher.allConversations() as? [Conversation]
        )
        XCTAssertTrue(conversations.filter { $0.conversationCategory == .private }.isEmpty)
        let tasks = try XCTUnwrap(taskManagerMock.addedTasks as? [TaskDefinitionUpdateContactSync])
        XCTAssertEqual(2, tasks.count)
        XCTAssertEqual(2, tasks.filter { $0.deltaSyncContacts.contains(where: { $0.syncAction == .update }) }.count)
        XCTAssertEqual(
            1,
            tasks
                .filter {
                    $0.deltaSyncContacts
                        .contains(where: {
                            $0.syncContact.identity == "ECHOECHO" && $0.syncContact.conversationCategory == .default
                        })
                }.count
        )
        XCTAssertEqual(
            1,
            tasks
                .filter {
                    $0.deltaSyncContacts
                        .contains(where: {
                            $0.syncContact.identity == "MEMBER01" && $0.syncContact.conversationCategory == .default
                        })
                }.count
        )
    }

    @discardableResult
    private func createConversation(
        unreadMessageCount: Int,
        category: ConversationCategory,
        visibility: ConversationVisibility,
        for identity: String = "ECHOECHO"
    ) -> Conversation {
        var conversation: Conversation!

        let databasePreparer = DatabasePreparer(context: mainCnx)
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: identity,
                verificationLevel: 0
            )

            conversation = databasePreparer.createConversation(
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
}
