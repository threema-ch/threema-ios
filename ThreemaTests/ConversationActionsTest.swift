import XCTest
@testable import Threema
@testable import ThreemaFramework

final class ConversationActionsTest: XCTestCase {
    
    // MARK: - Setup

    private var testDatabase: TestDatabase!
    private var businessInjectorMock: BusinessInjectorMock!
    private var backgroundBusinessInjectorMock: BusinessInjectorMock!
    private var notificationManagerMock: NotificationManagerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()

        businessInjectorMock = BusinessInjectorMock(
            conversationStore: ConversationStore(
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupManager: GroupManagerMock(),
                entityManager: testDatabase.entityManager,
                taskManager: nil
            ),
            entityManager: testDatabase.entityManager
        )

        backgroundBusinessInjectorMock = BusinessInjectorMock(
            conversationStore: ConversationStore(
                userSettings: UserSettingsMock(),
                pushSettingManager: PushSettingManagerMock(),
                groupManager: GroupManagerMock(),
                entityManager: testDatabase.backgroundEntityManager,
                taskManager: nil
            ),
            entityManager: testDatabase.backgroundEntityManager
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
        
        testDatabase.preparer.save {
            contact = testDatabase.preparer.createContact(
                publicKey: Data([1]),
                identity: "ECHOECHO"
            )

            conversation = testDatabase.preparer.createConversation(
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
