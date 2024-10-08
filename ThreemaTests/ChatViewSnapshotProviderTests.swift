//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import Combine
import Foundation
import XCTest
@testable import Threema

class ChatViewSnapshotProviderTests: XCTestCase {
    var objCnx: TMAManagedObjectContext!
    
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!
    
    private var internalInitialSetupCompleted = false
    
    override func setUp() {
        super.setUp()
        
        (_, objCnx, _) = DatabasePersistentContext.devNullContext()

        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBasicSetup() {
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        _ = EntityManager(databaseContext: databaseBackgroundCnx)
        
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
            context: databaseMainCnx.current
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
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        _ = EntityManager(databaseContext: databaseBackgroundCnx)
        
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
            context: databaseMainCnx.current
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
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)

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
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        _ = EntityManager(databaseContext: databaseBackgroundCnx)
        
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
            context: databaseMainCnx.current
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
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
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
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
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
        let entityManager = EntityManager(databaseContext: databaseMainCnx)
        _ = EntityManager(databaseContext: databaseBackgroundCnx)
        
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
            context: databaseMainCnx.current
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
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 2)
                },
                {
                    entityManager.performSyncBlockAndSafe {
                        conversation.typing = NSNumber(booleanLiteral: true)
                        self.internalInitialSetupCompleted = true
                        typingIndicatorInformationProvider.currentlyTyping = true
                    }
                }
            ),
            (
                // Check 2
                { diffableDataSourceSnapshot in
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
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
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
                    // Correct number of items
                    XCTAssertEqual(diffableDataSourceSnapshot.numberOfSections, 1)
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.count, 4)
                    
                    // Correct State for Unread Message line
                    XCTAssert(diffableDataSourceSnapshot.itemIdentifiers.contains(.typingIndicator))
                    
                    XCTAssertEqual(diffableDataSourceSnapshot.itemIdentifiers.last, .typingIndicator)
                },
                {
                    entityManager.performSyncBlockAndSafe {
                        typingIndicatorInformationProvider.currentlyTyping = false
                        conversation.typing = NSNumber(booleanLiteral: false)
                    }
                }
            ),
            (
                // Check 4
                { diffableDataSourceSnapshot in
                    // Correct number of reloads
                    XCTAssertEqual(diffableDataSourceSnapshot.reloadedItemIdentifiers.count, 0)
                    XCTAssertEqual(diffableDataSourceSnapshot.reconfiguredItemIdentifiers.count, 0)
                    
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
    
    private func createMessage(in conversation: Conversation, entityManager: EntityManager) {
        entityManager.performSyncBlockAndSafe {
            let textMessage = entityManager.entityCreator.textMessage(for: conversation, setLastUpdate: true)!
            textMessage.text = "Hello World"
        }
    }
    
    private func createContactAndConversation(entityManager: EntityManager, identity: String)
        -> (contact: ContactEntity, conversation: Conversation) {
        var contact: ContactEntity!
        
        entityManager.performSyncBlockAndSafe {
            contact = entityManager.entityCreator.contact()!
            contact.identity = identity
            contact.verificationLevel = 0
            contact.publicNickname = identity
            contact.isContactHidden = false
            contact.workContact = 0
            contact.publicKey = BytesUtility.generateRandomBytes(length: Int(32))!
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
