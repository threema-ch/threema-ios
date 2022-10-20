//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import CoreData
import DiffableDataSources
import OSLog
import PromiseKit
import UIKit

// Used to instrument new ChatView (TODO: Remove before release)
private class PointsOfInterestSignpost: NSObject {
    static let log = OSLog(subsystem: "ch.threema.iapp.newChatView", category: .pointsOfInterest)
}

/// Variables to try different message loading configurations
///
/// This can probably be removed before the public release
private protocol Configuration {
    // MARK: Optimizations configuration
    
    var limitEnabled: Bool { get }
    var isFixedWindowEnabled: Bool { get }
    // TODO: Maybe try an expanding window until a maximum size
        
    var windowSize: Int { get }
}

private extension MessageProvider {
    struct TestConfiguration: Configuration {
        fileprivate let limitEnabled = true
        fileprivate let isFixedWindowEnabled = false
        
        fileprivate let windowSize = 150
    }
    
    struct ProductionConfiguration: Configuration {
        fileprivate let limitEnabled = true
        fileprivate let isFixedWindowEnabled = false // Makes the scroll bar less jumpy
        
        fileprivate let windowSize = 1000 // TODO: (IOS-2014) Measure what the sweet spot might be
    }
}

/// Load messages of conversation and notify observer about changes
public final class MessageProvider: NSObject {
        
    /// A snapshot of the currently loaded messages and an indication if the previous snapshot contained the most recent messages
    public struct MessagesSnapshot {
        /// Snapshot to be used by the data source
        public let snapshot: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        /// Did the previous snapshot contain the most recent messages?
        public let previouslyNewestMessagesLoaded: Bool
    }
    
    /// Current snapshot of messages (provided by the underlying FRC)
    ///
    /// The updates will always arrive on the same queue, but it might not be the main queue.
    @Published public var currentMessages: MessagesSnapshot?
    
    // MARK: - Private properties
        
    private let fetchedResultsController: NSFetchedResultsController<BaseMessage>
    
    private var configuration = TestConfiguration()
    
    // Keep track if the previous snapshot contained the newest messages
    // This is needed by the chat view to decide if we scrolled all the way to the bottom
    private var newestMessagesLoaded = false
    private var previouslyNewestMessagesLoaded = false
    
    // TODO: (IOS-2468) Do we need to update this value more often?
    // - How about big insertions? How do we track them?
    // - Maybe we just ensure it runs on a background queue and update it on every query adjustments
    /// Number of messages updates at creation of provider and when batch deletes happen
    private var numberOfMessages: Int
    
    // If this is bigger than the available number of messages no messages will be loaded (but it won't crash)
    private var currentOffset = 0 {
        didSet {
            // This value should always be positive
            guard currentOffset >= 0 else {
                currentOffset = 0
                return
            }
        }
    }
    
    // TODO: (IOS-2014) Do we have to ensure that current window size always increases?
    // - How does this hold if we delete (all) messages?
    // - Does this help improving the problems while scrolling?
    // - Should probably be limited to `numberOfMessages` and some change
    private var currentWindowSize = 100
    
    private let conversationObjectID: NSManagedObjectID
    private let entityManager: EntityManager
    private let backgroundEntityManager: EntityManager
    
    private let messageFetcher: MessageFetcher
    
    // MARK: - Lifecycle
    
    /// Create a new messages provider
    ///
    /// This abstracts away the loading of messages from Core Data by providing an updating snapshot of the current set of messages. To load more messages below
    /// or above use the provided methods for that.
    ///
    /// - Parameters:
    ///   - conversation: Messages from this conversation will be fetched and provided
    ///   - date: Date to do initial fetch around. If `nil` newest messages will be fetched.
    ///   - entityManager: Main context to fetch data used in UI
    ///   - backgroundEntityManager: Background context to fetch meta data information on
    ///   - initialFetchCompletion: Called after initial fetch completes
    public init(
        for conversation: Conversation,
        around date: Date?,
        entityManager: EntityManager = EntityManager(),
        backgroundEntityManager: EntityManager = EntityManager(withChildContextForBackgroundProcess: true),
        initialFetchCompletion: @escaping () -> Void
    ) {
        self.conversationObjectID = conversation.objectID
        self.entityManager = entityManager
        self.backgroundEntityManager = backgroundEntityManager
        
        let localMessageFetcher = MessageFetcher(for: conversation, with: backgroundEntityManager)
        self.messageFetcher = localMessageFetcher
        
        let context = DatabaseContext.directBackgroundContext(
            withPersistentCoordinator: DatabaseManager.db().persistentStoreCoordinator
        )
        
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: localMessageFetcher.messagesFetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: #keyPath(BaseMessage.sectionDateString),
            cacheName: nil
        )
        
        // TODO: (IOS-2014)
        // - In my analysis this was not called on a background context on an iPhone 7 with iOS 13. Why?
        // - Can we improve speed if we create a derived property for it? (Maybe only possible if we drop iOS 12 support)
        self.numberOfMessages = localMessageFetcher.count()
        
        super.init()

        fetchedResultsController.delegate = self
        
        configureChangeObservation(for: context)
        
        configureInitialFetchRequest(around: date)
        fetch().done {
            initialFetchCompletion()
        }
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("Not available")
    }
    
    // MARK: - Configuration
    
    private func configureChangeObservation(for context: NSManagedObjectContext) {
        // This implementation should be streamlined in the future by using persistence history tracking (IOS-2354)
        
        // Observe all changes that go through a normal Core Data save call
        context.automaticallyMergesChangesFromParent = true

        // Custom notifications for batch actions
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batchDeletedAllMessagesInAConversation(notification:)),
            name: NSNotification.Name(kNotificationBatchDeletedAllConversationMessages),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batchDeletedOldMessages),
            name: NSNotification.Name(kNotificationBatchDeletedOldMessages),
            object: nil
        )
    }
    
    private func configureInitialFetchRequest(around date: Date?) {
        // Needed for sectioning (BaseMessage.sectionDateString)
        fetchedResultsController.fetchRequest.propertiesToFetch = BaseMessage.sectioningKeyPaths
        
        if let date = date {
            configureLoadingMessages(around: date)
        }
        else {
            configureLoadingMessagesAtBottom()
        }
    }
    
    private func configureLoadingMessages(around date: Date) {
        let numberOfMessagesAfterDate = messageFetcher.numberOfMessages(after: date)
        currentOffset = numberOfMessages - numberOfMessagesAfterDate - (configuration.windowSize / 2)
    }
    
    private func configureLoadingMessagesAtBottom() {
        if configuration.isFixedWindowEnabled {
            currentOffset = numberOfMessages - configuration.windowSize
        }
        else {
            currentOffset = numberOfMessages - currentWindowSize
        }
    }
    
    // MARK: - Initial fetch with a new configuration
    
    @discardableResult private func fetch() -> Guarantee<Void> {
        DDLogVerbose("Fetch...")
        if configuration.limitEnabled {
            limitFetchRequest()
        }
        
        return Guarantee { seal in
            // As this is probably happening on a background context we need to dispatch the fetch correctly
            fetchedResultsController.managedObjectContext.perform {
                do {
                    DDLogVerbose("Start fetch")
                    try self.fetchedResultsController.performFetch()
                    DDLogVerbose("End fetch")
                    seal(())
                }
                catch {
                    // TODO: Fail more gracefully
                    fatalError("Initial fetch of messages failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func limitFetchRequest() {
        // Set window size
        if configuration.isFixedWindowEnabled {
            if currentOffset + configuration.windowSize >= numberOfMessages {
                fetchedResultsController.fetchRequest.fetchLimit = 0
                newestMessagesLoaded = true
            }
            else {
                fetchedResultsController.fetchRequest.fetchLimit = configuration.windowSize
                newestMessagesLoaded = false
            }
        }
        else {
            if currentOffset + currentWindowSize >= numberOfMessages {
                fetchedResultsController.fetchRequest.fetchLimit = 0
                newestMessagesLoaded = true
            }
            else {
                fetchedResultsController.fetchRequest.fetchLimit = currentWindowSize
                newestMessagesLoaded = false
            }
        }
        
        // Set offset
        fetchedResultsController.fetchRequest.fetchOffset = currentOffset
    }
    
    // MARK: - Public methods
    
    // TODO: (IOS-2393) Add a reload that reset the complete FRC so the section title are update (or maybe other things)
        
    /// Load more message at the top if there are any
    ///
    /// Fetching happens asynchronously.
    ///
    /// - Returns: Guarantee that is full-filled when initial fetch of loading completes or no new fetch is needed
    public func loadMessagesAtTop() -> Guarantee<Void> {
        guard currentOffset > 0 else {
            // We're at the top
            return Guarantee()
        }
        
        if configuration.isFixedWindowEnabled {
            currentOffset = currentOffset - (2 * configuration.windowSize / 3)
        }
        else {
            currentWindowSize += configuration.windowSize
            currentOffset -= configuration.windowSize
        }
        
        return fetch()
    }

    /// Load more message at the bottom if there are any
    ///
    /// Fetching happens asynchronously.
    ///
    /// - Returns: Guarantee that is full-filled when initial fetch of loading completes or no new fetch is needed
    public func loadMessagesAtBottom() -> Guarantee<Void> {
        guard !newestMessagesLoaded else {
            return Guarantee()
        }
        
        if configuration.isFixedWindowEnabled {
            currentOffset = min(
                currentOffset + (3 * configuration.windowSize / 4),
                numberOfMessages - configuration.windowSize
            )
        }
        else {
            currentWindowSize += configuration.windowSize
        }
        
        return fetch()
    }
    
    /// Load message around `date`
    ///
    /// Fetching happens asynchronously and no fetch happens if messages around `date` are already loaded.
    ///
    /// - Parameter date: Date to load messages around
    /// - Returns: Guarantee that is full-filled when initial fetch of loading completes or no new fetch is needed
    public func loadMessages(around date: Date) -> Guarantee<Void> {
        let numberOfMessagesAfterDate = messageFetcher.numberOfMessages(after: date)
        let firstMessageAfterDateOffset = numberOfMessages - numberOfMessagesAfterDate
        
        // Don't do new fetch if messages around `date` are already loaded
        guard currentOffset > (firstMessageAfterDateOffset - (configuration.windowSize / 2)) ||
            currentOffset + currentWindowSize < firstMessageAfterDateOffset + (configuration.windowSize / 2)
        else {
            return Guarantee()
        }
        
        currentOffset = numberOfMessages - numberOfMessagesAfterDate - (configuration.windowSize / 2)
        currentWindowSize = configuration.windowSize
        
        return fetch()
    }
    
    /// Load newest messages
    /// - Returns: Guarantee that is full-filled when initial fetch of loading completes or no new fetch is needed
    public func loadNewestMessages() -> Guarantee<Void> {
        guard !newestMessagesLoaded else {
            return Guarantee()
        }
        
        configureLoadingMessagesAtBottom()
        
        return fetch()
    }
        
    /// Get `BaseMessage` for id on main queue
    /// - Parameter objectID: Object to load
    /// - Returns: `BaseMessage` if one is found
    public func message(for objectID: NSManagedObjectID) -> BaseMessage? {
        // TODO: (IOS-2014) Is there a way to optimize this by using a fetch request with batch sizes?
        guard let message = entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage else {
            DDLogVerbose("Object not found or unable to cast to BaseMessage")
            return nil
        }

        return message
    }
    
    // MARK: - Notifications
    
    @objc private func batchDeletedAllMessagesInAConversation(notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let conversationObjectIDOfMessageDeletion = userInfo[kKeyObjectID] as? NSManagedObjectID else {
            return
        }
        
        if conversationObjectIDOfMessageDeletion == conversationObjectID {
            numberOfMessages = messageFetcher.count()
            if currentOffset > numberOfMessages {
                configureLoadingMessagesAtBottom()
            }
            fetch()
        }
    }
    
    @objc private func batchDeletedOldMessages() {
        numberOfMessages = messageFetcher.count()
        if currentOffset > numberOfMessages {
            configureLoadingMessagesAtBottom()
        }
        fetch()
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension MessageProvider: NSFetchedResultsControllerDelegate {
    // As we use the diffable data source only one delegate method is needed
    public func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        DDLogVerbose("New snapshot...")
        var newSnapshot = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        
        if #available(iOS 15.0, *) {
            // Nothing needed
        }
        else {
            // Pre iOS 15 reload items are lost when the snapshot is casted:
            // > Before iOS 15, there was a bug in the implementation of how NSDiffableDataSourceSnapshot was bridged
            // > between Swift and Objective-C, which caused the internally-stored reloaded identifiers to be lost
            // > during the bridging process (which is what happens when you bridge from
            // > NSDiffableDataSourceSnapshotReference to NSDiffableDataSourceSnapshot using the as keyword). Therefore,
            // > automatic reloads have always worked when using NSFetchedResultsController and diffable data source
            // > from Objective-C, as no bridging to/from Swift would take place. And as of iOS 15, they now work as
            // > intended in Swift as well.
            // swiftformat:disable:next acronyms
            // > – https://developer.apple.com/forums/thread/692357?answerId=691483022#691483022
            //
            // As we didn't find any reliable solution to identify the updated items we reload all of them.
            //
            // TODO: (IOS-2427) Is there a more efficient way to find the items that changed?
            // This leads to a constant reload of the table view cells e.g. when downloading a blob (at least on iOS 14)
            // Maybe we should rewrite this delegate and the apply in Objective-C.
            newSnapshot.reloadItems(newSnapshot.itemIdentifiers)
        }
        
        // Publish new snapshot
        currentMessages = MessagesSnapshot(
            snapshot: newSnapshot,
            previouslyNewestMessagesLoaded: previouslyNewestMessagesLoaded
        )
        
        // The new state is the new previous state
        previouslyNewestMessagesLoaded = newestMessagesLoaded
    }
}