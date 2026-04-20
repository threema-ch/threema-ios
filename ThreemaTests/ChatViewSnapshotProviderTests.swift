import Combine
import Foundation
import ThreemaEssentials
import XCTest
@testable import Threema
@testable import ThreemaFramework

final class ChatViewSnapshotProviderTests: XCTestCase {
    private var testDatabase: TestDatabase!

    private var internalInitialSetupCompleted = false
    
    override func setUp() {
        super.setUp()
        
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        testDatabase = TestDatabase()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBasicSetup() {
        let entityManager = testDatabase.entityManager

        let conversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        ).conversation
        
        createMessage(in: conversation, entityManager: entityManager)
        
        XCTAssertEqual(MessageFetcher(for: conversation, with: entityManager).count(), 1)
        
        let messageProvider = MessageProvider(
            for: conversation,
            around: nil,
            entityManager: entityManager,
            backgroundEntityManager: entityManager,
            context: testDatabase.context.current
        )
        
        let snapshotProvider = ChatViewSnapshotProvider(
            conversation: conversation,
            entityManager: entityManager,
            messageProvider: messageProvider,
            unreadMessagesSnapshot: UnreadMessagesStateManager(
                conversation: conversation,
                businessInjector: BusinessInjectorMock(entityManager: entityManager),
                notificationManager: NotificationManagerMock(),
                unreadMessagesStateManagerDelegate: UnreadMessagesStateManagerDelegateMock()
            ),
            delegate: self,
            userSettings: UserSettingsMock()
        )
        
        let expectation = expectation(description: "Single Snapshot")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        
        var cancellables = Set<AnyCancellable>()
        
        snapshotProvider.$snapshotInfo
            .receive(on: DispatchQueue.global())
            .sink { snapshot in
                guard let diffableDataSourceSnapshot = snapshot?.snapshot else {
                    return
                }
            
                XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)

                XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 1)
            
                expectation.fulfill()
            }.store(in: &cancellables)
        
        guard MessageFetcher(for: conversation, with: entityManager).lastDisplayMessage() != nil else {
            fatalError()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testBasicPublish() {
        let entityManager = testDatabase.entityManager

        let conversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        ).conversation
        
        createMessage(in: conversation, entityManager: entityManager)
        
        XCTAssertEqual(MessageFetcher(for: conversation, with: entityManager).count(), 1)
        
        let messageProvider = MessageProvider(
            for: conversation,
            around: nil,
            entityManager: entityManager,
            backgroundEntityManager: entityManager,
            context: testDatabase.context.current
        )
        
        let snapshotProvider = ChatViewSnapshotProvider(
            conversation: conversation,
            entityManager: entityManager,
            messageProvider: messageProvider,
            unreadMessagesSnapshot: UnreadMessagesStateManager(
                conversation: conversation,
                businessInjector: BusinessInjectorMock(entityManager: entityManager),
                notificationManager: NotificationManagerMock(),
                unreadMessagesStateManagerDelegate: UnreadMessagesStateManagerDelegateMock()
            ),
            delegate: self,
            userSettings: UserSettingsMock()
        )
        
        var cancellables = Set<AnyCancellable>()
        
        typealias Check = (
            check: (ChatViewSnapshotProvider.ChatViewDiffableDataSourceSnapshot) -> Void,
            postcheck: () -> Void
        )
        
        let checks: [Check] = [
            (
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 1)
                },
                {
                    DispatchQueue.global().async {
                        self.createMessage(in: conversation, entityManager: entityManager)
                    }
                }
            ),
            (
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            2
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 2)
                },
                { }
            ),
        ]
        
        let expectation = expectation(description: "Single Snapshot")
        expectation.expectedFulfillmentCount = checks.count
        expectation.assertForOverFulfill = true
        
        var i = 0
        snapshotProvider.$snapshotInfo
            .receive(on: DispatchQueue.global())
            .sink { snapshot in
                guard let diffableDataSourceSnapshot = snapshot?.snapshot else {
                    return
                }
            
                checks[i].check(diffableDataSourceSnapshot)
            
                checks[i].postcheck()
            
                i += 1
            
                expectation.fulfill()
            }.store(in: &cancellables)
        
        waitForExpectations(timeout: 10)
    }
        
    func testBasicAddUnreadMessageLine() {
        basicUnreadMessageLine()
    }
    
    func basicUnreadMessageLine() {
        let entityManager = testDatabase.entityManager

        let conversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        ).conversation
        
        createMessage(in: conversation, entityManager: entityManager)
        
        XCTAssertEqual(MessageFetcher(for: conversation, with: entityManager).count(), 1)
        
        let messageProvider = MessageProvider(
            for: conversation,
            around: nil,
            entityManager: entityManager,
            backgroundEntityManager: entityManager,
            context: testDatabase.context.current
        )
        
        let typingIndicatorInformationProvider = ChatViewTypingIndicatorInformationProviderMock()
        let userSettingsMock = UserSettingsMock()
        
        let snapshotProvider = ChatViewSnapshotProvider(
            conversation: conversation,
            entityManager: entityManager,
            messageProvider: messageProvider,
            unreadMessagesSnapshot: UnreadMessagesStateManager(
                conversation: conversation,
                businessInjector: BusinessInjectorMock(entityManager: entityManager),
                notificationManager: NotificationManagerMock(),
                unreadMessagesStateManagerDelegate: UnreadMessagesStateManagerDelegateMock()
            ),
            typingIndicatorInformationProvider: typingIndicatorInformationProvider,
            delegate: self,
            userSettings: userSettingsMock
        )
        
        var cancellables = Set<AnyCancellable>()
        
        typealias Check = (
            check: (ChatViewSnapshotProvider.ChatViewDiffableDataSourceSnapshot) -> Void,
            postcheck: () -> Void
        )
        
        let checks: [Check] = [
            (
                // Check 0
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 1)
                },
                {
                    DispatchQueue.global().async {
                        self.createMessage(in: conversation, entityManager: entityManager)
                    }
                }
            ),
            (
                // Check 1
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            2
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 2)
                },
                {
                    self.internalInitialSetupCompleted = true
                    typingIndicatorInformationProvider.currentlyTyping = true
                }
            ),
            (
                // Check 2
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            2
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 3)
                    
                    XCTAssert(diffableDataSourceSnapshot.itemIdentifiers.contains(.typingIndicator))
                    
                    XCTAssertEqual(
                        diffableDataSourceSnapshot.itemIdentifiers.last,
                        .typingIndicator
                    )
                },
                { }
            ),
        ]
        
        let expectation = expectation(description: "Single Snapshot")
        expectation.expectedFulfillmentCount = checks.count
        expectation.assertForOverFulfill = true
        
        var i = 0
        snapshotProvider.$snapshotInfo
            .receive(on: DispatchQueue.global())
            .sink { snapshot in
                guard let diffableDataSourceSnapshot = snapshot?.snapshot else {
                    return
                }
            
                checks[i].check(diffableDataSourceSnapshot)
            
                checks[i].postcheck()
            
                print("Executed check \(i)")
                
                i += 1
            
                expectation.fulfill()
            }.store(in: &cancellables)
        
        waitForExpectations(timeout: 10)
    }
    
    // TODO: (IOS-3875) Timeout
    func testUnreadMessageLineStillLastAfterNewMessageSent() {
        let entityManager = testDatabase.entityManager

        let conversation = createContactAndConversation(
            entityManager: entityManager,
            identity: "ECHOECHO"
        ).conversation
        
        createMessage(in: conversation, entityManager: entityManager)
        
        XCTAssertEqual(MessageFetcher(for: conversation, with: entityManager).count(), 1)
        
        let messageProvider = MessageProvider(
            for: conversation,
            around: nil,
            entityManager: entityManager,
            backgroundEntityManager: entityManager,
            context: testDatabase.context.current
        )
        
        let typingIndicatorInformationProvider = ChatViewTypingIndicatorInformationProviderMock()
        let userSettingsMock = UserSettingsMock()
        
        let snapshotProvider = ChatViewSnapshotProvider(
            conversation: conversation,
            entityManager: entityManager,
            messageProvider: messageProvider,
            unreadMessagesSnapshot: UnreadMessagesStateManager(
                conversation: conversation,
                businessInjector: BusinessInjectorMock(entityManager: entityManager),
                notificationManager: NotificationManagerMock(),
                unreadMessagesStateManagerDelegate: UnreadMessagesStateManagerDelegateMock()
            ),
            typingIndicatorInformationProvider: typingIndicatorInformationProvider,
            delegate: self,
            userSettings: userSettingsMock
        )
        
        var cancellables = Set<AnyCancellable>()
        
        typealias Check = (
            check: (ChatViewSnapshotProvider.ChatViewDiffableDataSourceSnapshot) -> Void,
            postcheck: () -> Void
        )
        
        let checks: [Check] = [
            (
                // Check 0
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 1)
                },
                {
                    DispatchQueue.global().async {
                        self.createMessage(in: conversation, entityManager: entityManager)
                    }
                }
            ),
            (
                // Check 1
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            2
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 2)
                },
                {
                    entityManager.performAndWaitSave {
                        conversation.typing = true
                        self.internalInitialSetupCompleted = true
                        typingIndicatorInformationProvider.currentlyTyping = true
                    }
                }
            ),
            (
                // Check 2
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                   
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            2
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 3)
                    
                    XCTAssert(diffableDataSourceSnapshot.itemIdentifiers.contains(.typingIndicator))
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.last, .typingIndicator)
                },
                {
                    DispatchQueue.global().async {
                        self.createMessage(in: conversation, entityManager: entityManager)
                    }
                }
            ),
            (
                // Check 3
                { diffableDataSourceSnapshot in
                    // Correct number of reloads
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            3
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    // Correct number of items
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 4)
                    
                    // Correct State for Unread Message line
                    XCTAssert(diffableDataSourceSnapshot.itemIdentifiers.contains(.typingIndicator))
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.last, .typingIndicator)
                },
                {
                    entityManager.performAndWaitSave {
                        typingIndicatorInformationProvider.currentlyTyping = false
                        conversation.typing = false
                    }
                }
            ),
            (
                // Check 4
                { diffableDataSourceSnapshot in
                    // Correct number of reloads
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    
                    if #available(iOS 18.0, *) {
                        // Starting with iOS 18 updating `lastMessage` on `Conversation` leads to the previous last
                        // message to be marked as reloaded (even tough there is no reverse relationship) and after our
                        // processing to a reconfigured item and neighboring items. This actually fixes some neighboring
                        // update issues
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            3
                        )
                    }
                    else {
                        XCTAssertEqual(
                            diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count,
                            0
                        )
                    }

                    // Correct number of items
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 3)
                    
                    // Correct State for Unread Message line
                    XCTAssertFalse(diffableDataSourceSnapshot.itemIdentifiers.contains(.typingIndicator))
                },
                { }
            ),
        ]
        
        let expectation = expectation(description: "Single Snapshot")
        expectation.expectedFulfillmentCount = checks.count
        expectation.assertForOverFulfill = true
        
        var i = 0
        snapshotProvider.$snapshotInfo
            .receive(on: DispatchQueue.global())
            .sink { snapshot in
                guard let diffableDataSourceSnapshot = snapshot?.snapshot else {
                    return
                }
            
                checks[i].check(diffableDataSourceSnapshot)
            
                checks[i].postcheck()
            
                print("Executed check \(i)")
                
                i += 1
            
                expectation.fulfill()
            }.store(in: &cancellables)
        
        // TODO: (IOS-3875) Timeout
        waitForExpectations(timeout: 100)
    }
    
    private func createMessage(in conversation: ConversationEntity, entityManager: EntityManager) {
        _ = entityManager.performAndWaitSave {
            entityManager.entityCreator.textMessageEntity(text: "Hello World", in: conversation, setLastUpdate: true)
        }
    }
    
    private func createContactAndConversation(entityManager: EntityManager, identity: String)
        -> (contact: ContactEntity, conversation: ConversationEntity) {
        var contact: ContactEntity!
        
        entityManager.performAndWaitSave {
            contact = entityManager.entityCreator.contactEntity(
                identity: identity,
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                sortOrderFirstName: true
            )
            contact.contactVerificationLevel = .unverified
            contact.publicNickname = identity
            contact.isHidden = false
            contact.workContact = 0
        }
        
        let conversation = entityManager.conversation(
            forContact: contact,
            createIfNotExisting: true
        )!
            
        assert(contact.identity == identity)
        
        return (contact, conversation)
    }
}

// MARK: - ChatViewSnapshotProviderDelegate

extension ChatViewSnapshotProviderTests: ChatViewSnapshotProviderDelegate {
    var initialSetupCompleted: Bool {
        internalInitialSetupCompleted
    }
    
    var unreadMessagesInfo: (totalUnreadMessagesCount: Int, newestUnreadMessage: NSManagedObjectID?)? {
        nil
    }
    
    var nextSnapshotShouldShowUnreadMessageLine: Bool? {
        false
    }
    
    var previousUnreadMessage: NSManagedObjectID? {
        nil
    }
    
    var deletedMessagesObjectIDs: Set<NSManagedObjectID> {
        Set()
    }
}
