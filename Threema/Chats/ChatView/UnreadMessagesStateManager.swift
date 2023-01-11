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

import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaFramework

/// Manages the unread message state for a conversation in an instance of `ChatViewController`
final class UnreadMessagesStateManager {
    private typealias Config = ChatViewConfiguration.UnreadMessageLine

    // MARK: - Nested Types

    struct UnreadMessagesState: Hashable {
        /// The message above which an unread message line should be shown
        /// Nothing will be shown if it is nil
        var oldestConsecutiveUnreadMessage: NSManagedObjectID?
        /// The number of unread messages the current conversations
        var numberOfUnreadMessages = 0
    }
    
    // MARK: - Internal Published Properties

    /// The current unread message state
    @Published var unreadMessagesState: UnreadMessagesState? {
        didSet {
            if let unreadMessagesState = unreadMessagesState {
                DDLogVerbose("New unread message count \(unreadMessagesState.numberOfUnreadMessages)")
            }
        }
    }
    
    /// True if the user is at the bottom of the `tableView` in ChatViewController
    @Published var userIsAtBottomOfTableView = true {
        didSet {
            if userIsAtBottomOfTableView, !oldValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Config.timeBeforeDisappear)) {
                    self.resetState()
                }
            }
        }
    }
    
    // MARK: - Private Properties

    private let entityManager: EntityManager
    private let messageFetcher: MessageFetcher
    private let conversation: Conversation
    private let notificationManager: NotificationManagerProtocol
    
    private lazy var unreadMessages = UnreadMessages(entityManager: entityManager)
    
    private var firstRoundCompleted = false
    
    private var currentUnreadDBState: (unreadMessages: [BaseMessage], newestUnreadMessage: BaseMessage?) {
        var unreadMessages = [BaseMessage]()
        var newestUnreadMessage: BaseMessage?
        
        entityManager.performBlockAndWait {
            let count = self.unreadMessages.count(for: self.conversation)
            if count > 0 {
                unreadMessages = self.messageFetcher.unreadMessages(limit: count)
                newestUnreadMessage = unreadMessages.last
            }
        }
        
        return (unreadMessages, newestUnreadMessage)
    }
    
    private let updateQueue = DispatchQueue(
        label: "ch.threema.chatView.unreadMessagesSnapshotQueue",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    
    // MARK: - Lifecycle

    init(
        conversation: Conversation,
        entityManager: EntityManager,
        notificationManager: NotificationManagerProtocol = NotificationManager()
    ) {
        self.messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        self.entityManager = entityManager
        self.conversation = conversation
        self.notificationManager = notificationManager
        
        let dbState = currentUnreadDBState
        self.unreadMessagesState = UnreadMessagesState(
            oldestConsecutiveUnreadMessage: dbState.1?.objectID,
            numberOfUnreadMessages: dbState.0.count
        )
    }
    
    // MARK: - Configuration Functions

    /// Synchronously resets the unread message state to the current state in the DB
    func synchronousReconfiguration() {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            DDLogNotice("Duration of \(#function) \(endTime - startTime) s")
        }
        
        if Thread.isMainThread {
            if ChatViewConfiguration.strictMode {
                fatalError("Don't call this on the main thread or you will deadlock")
            }
            else {
                resetState()
                return
            }
        }
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        _ = tick(willStayAtBottomOfView: false, isSetup: true).ensure {
            dispatchGroup.leave()
        }
        
        if dispatchGroup.wait(timeout: .now() + .seconds(5)) == .timedOut {
            fatalError("Assume we are deadlocked, exit.")
        }
    }
    
    // MARK: - Update Functions

    /// Updates the unread message state by adding the newly received messages to the state or keeping the state at zero
    /// - Parameter willStayAtBottomOfView: whether to _keep_ the unread messages state at no unread messages
    /// - Parameter isSetup: Is true on first run
    /// - Returns: Fulfills if the messages have been marked as read or the mark as read has failed
    @discardableResult
    func tick(willStayAtBottomOfView: Bool, isSetup: Bool = false) -> Promise<Void> {
        Promise { seal in
            updateQueue.async { [self] in
                let (unreadMessages, newestUnreadMessage) = self.currentUnreadDBState
                
                if !unreadMessages.isEmpty, newestUnreadMessage == nil {
                    fatalError("Illegal unread message state")
                }
                if let firstUnreadMessage = unreadMessages.last, let newestUnreadMessage = newestUnreadMessage,
                   firstUnreadMessage.objectID != newestUnreadMessage.objectID {
                    fatalError("Illegal unread message state")
                }
                
                let previousCount: Int
                let oldestConsecutiveUnreadMessage: NSManagedObjectID?
                
                if let unreadMessagesState = unreadMessagesState, unreadMessagesState.numberOfUnreadMessages > 0 {
                    previousCount = unreadMessagesState.numberOfUnreadMessages
                    oldestConsecutiveUnreadMessage = unreadMessagesState.oldestConsecutiveUnreadMessage
                }
                else {
                    previousCount = 0
                    oldestConsecutiveUnreadMessage = newestUnreadMessage?.objectID
                }
                
                let newState: UnreadMessagesState
                
                if willStayAtBottomOfView,
                   let unreadMessagesState = unreadMessagesState,
                   unreadMessagesState.numberOfUnreadMessages == 0,
                   unreadMessagesState.oldestConsecutiveUnreadMessage == nil {
                    
                    newState = UnreadMessagesState(
                        oldestConsecutiveUnreadMessage: nil,
                        numberOfUnreadMessages: 0
                    )
                }
                else if firstRoundCompleted {
                    // Regular case
                    DDLogVerbose(
                        "Setting unread count to \(previousCount) + \(unreadMessages.count) = \(previousCount + unreadMessages.count)"
                    )
                    newState = UnreadMessagesState(
                        oldestConsecutiveUnreadMessage: oldestConsecutiveUnreadMessage,
                        numberOfUnreadMessages: previousCount + unreadMessages.count
                    )
                }
                else {
                    // The state is initialized with the current unread count when opening the chat
                    // without marking any messages as read for performance reasons.
                    // Thus we don't add the unread messages in the first iteration.
                    newState = UnreadMessagesState(
                        oldestConsecutiveUnreadMessage: oldestConsecutiveUnreadMessage,
                        numberOfUnreadMessages: unreadMessages.count
                    )
                    firstRoundCompleted = true
                }
                
                markAsReadAndWait(unreadMessages)
                
                maybeUpdate(to: newState)
                
                seal.fulfill_()
            }
        }
    }
    
    /// Resets state to no unread messages
    func resetState() {
        DDLogVerbose("\(#function)")
        updateQueue.async { [self] in
            let newState = UnreadMessagesState(
                oldestConsecutiveUnreadMessage: nil,
                numberOfUnreadMessages: 0
            )
            
            maybeUpdate(to: newState)
        }
    }
    
    // MARK: - Private Helper Functions

    private func markAsReadAndWait(_ unreadMessages: [BaseMessage]) {
        if Thread.isMainThread {
            if ChatViewConfiguration.strictMode {
                fatalError("Don't call this on the main thread or you will deadlock")
            }
            else {
                resetState()
                return
            }
        }
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        _ = ConversationActions(
            unreadMessages: UnreadMessages(entityManager: entityManager),
            entityManager: entityManager,
            notificationManager: notificationManager
        )
        .read(conversation.objectID, messages: unreadMessages)
        .done {
            DDLogVerbose("Marked \(unreadMessages.count) messages as read")
        }
        .ensure {
            dispatchGroup.leave()
        }
        .catch { err in
            let msg = "Could not mark messages as read due to an error \(err)"
            DDLogError(msg)
                
            fatalError(msg)
        }
        dispatchGroup.wait()
    }
    
    @discardableResult
    private func maybeUpdate(to newState: UnreadMessagesState) -> Bool {
        if unreadMessagesState?.numberOfUnreadMessages != newState.numberOfUnreadMessages {
            unreadMessagesState = newState
            return true
        }
        return false
    }
}
