import CoreData
import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class ConversationStoreTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var entityManager: EntityManager!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")

        testDatabase = TestDatabase()
        entityManager = testDatabase.entityManager

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
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
            entityManager.entityFetcher.conversationEntities()
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
        category: ConversationEntity.Category,
        visibility: ConversationEntity.Visibility,
        for identity: String = "ECHOECHO"
    ) -> ConversationEntity {
        var conversation: ConversationEntity!

        let databasePreparer = testDatabase.preparer
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: BytesUtility.generatePublicKey(),
                identity: identity
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
