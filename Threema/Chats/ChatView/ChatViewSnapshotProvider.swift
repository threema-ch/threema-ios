//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

protocol ChatViewSnapshotProviderDelegate: AnyObject {
    var initialSetupCompleted: Bool { get }
}

final class ChatViewSnapshotProvider {
    // MARK: - Typealias
    
    typealias ChatViewDiffableDataSourceSnapshot = NSDiffableDataSourceSnapshot<String, ChatViewDataSource.CellType>
    typealias CellType = ChatViewDataSource.CellType
    
    private typealias Config = ChatViewConfiguration.DataSource
    
    // MARK: - Nested Types
    
    struct SnapshotInfo {
        let snapshot: ChatViewDiffableDataSourceSnapshot
        let shouldAnimate: Bool
        let mustWaitForApply: Bool
        let snapshotChanged: NSManagedObjectID?
        let previouslyNewestMessagesLoaded: Bool
    }
    
    // MARK: - Properties
    
    @Published var snapshotInfo: SnapshotInfo? {
        willSet {
            previousSnapshotInfo = newValue
        }
    }
    
    // MARK: - Private Properties
    
    /// See `snapshot` above
    private var previousSnapshotInfo: SnapshotInfo?
    
    private let entityManager: EntityManager
    private let messageProvider: MessageProvider
    private let conversation: Conversation
    
    private var refreshAndWaitOnce = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private weak var delegate: ChatViewSnapshotProviderDelegate?
    
    private let unreadMessagesSnapshot: UnreadMessagesStateManager
    
    /// Everything accessing current snapshots via `previousSnapshotInfo` or publishing snapshots via `snapshot`
    /// must run on this queue to avoid concurrency issues.
    private let snapshotProviderQueue = DispatchQueue(
        label: "snapshotProviderQueue",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    
    private lazy var chatViewTypingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProvider? =
        ChatViewTypingIndicatorInformationProvider(
            conversation: conversation,
            entityManager: entityManager
        )
    
    // MARK: - Lifecycle
    
    init(
        conversation: Conversation,
        entityManager: EntityManager,
        messageProvider: MessageProvider,
        unreadMessagesSnapshot: UnreadMessagesStateManager,
        delegate: ChatViewSnapshotProviderDelegate
    ) {
        self.conversation = conversation
        self.entityManager = entityManager
        self.messageProvider = messageProvider
        self.delegate = delegate
        self.unreadMessagesSnapshot = unreadMessagesSnapshot
        
        loadInitialMessagesAndObserveChanges()
        
        addObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration Functions
    
    private func loadInitialMessagesAndObserveChanges() {
        let typingIndicatorThrottle = ChatViewConfiguration.DataSource.typingIndicatorThrottle
        
        chatViewTypingIndicatorInformationProvider?.$currentlyTyping
            .receive(on: snapshotProviderQueue)
            .throttle(
                for: RunLoop.SchedulerTimeType.Stride(typingIndicatorThrottle),
                scheduler: RunLoop.main,
                latest: true
            )
            .sink { [weak self] isTyping in
                guard let self = self else {
                    return
                }
                
                guard let delegate = self.delegate, delegate.initialSetupCompleted else {
                    return
                }
                
                self.updateTypingIndicator(add: isTyping)
            }
            .store(in: &cancellables)
        
        unreadMessagesSnapshot.$unreadMessagesState
            .throttle(
                for: .milliseconds(Config.unreadMessagesSnapshotStateThrottleInMs),
                scheduler: snapshotProviderQueue,
                latest: true
            )
            .receive(on: snapshotProviderQueue)
            .sink { [weak self] unreadMessagesState in
                guard let delegate = self?.delegate, delegate.initialSetupCompleted else {
                    return
                }
                
                if let unreadMessagesState = unreadMessagesState, unreadMessagesState.numberOfUnreadMessages <= 0 {
                    self?.removeUnreadMessageLine()
                }
                else {
                    self?.messageProvider.refetch()
                }
            }
            .store(in: &cancellables)
        
        // Do not apply delay here to profit from better batching downstream in DataSource
        messageProvider.$currentMessages
            .receive(on: snapshotProviderQueue)
            .sink { [weak self] messages in
                guard let self = self else {
                    return
                }
                
                guard let messages = messages else {
                    return
                }
                
                self.prepareAndPublishSnapshot(messages: messages)
            }
            .store(in: &cancellables)
    }
    
    private func addObservers() {
        // Reload the chat on significant time changes (e.g. new day) to update section headers
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: self,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.messageProvider.refetch()
        }
    }
    
    private func prepareAndPublishSnapshot(messages: MessageProvider.MessagesSnapshot) {
        DDLogNotice("prepareAndPublishSnapshot async")
        snapshotProviderQueue.async { [weak self] in
            DDLogNotice("prepareAndPublishSnapshot start")
            guard let strongSelf = self else {
                return
            }
            
            let convertedSnapshot = strongSelf.convertSnapshot(snapshot: messages.snapshot)
            strongSelf.publish(
                convertedSnapshot,
                previouslyNewestMessagesLoaded: messages.previouslyNewestMessagesLoaded
            )
            DDLogNotice("prepareAndPublishSnapshot end")
        }
    }
    
    private func publish(_ snapshot: ChatViewDiffableDataSourceSnapshot, previouslyNewestMessagesLoaded: Bool = false) {
        snapshotProviderQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let shouldAnimate = ChatViewSnapshotProvider.shouldAnimate(
                currSnap: strongSelf.previousSnapshotInfo?.snapshot,
                nextSnap: snapshot,
                previousSnapshotInfo: strongSelf.previousSnapshotInfo
            )
            let mustWaitForApply = true
            let snapshotChanged = ChatViewSnapshotProvider.checkSnapshotChanged(
                previousSnapshot: strongSelf.previousSnapshotInfo,
                nextSnap: snapshot
            )
            
            let newSnapshotInfo = SnapshotInfo(
                snapshot: snapshot,
                shouldAnimate: shouldAnimate,
                mustWaitForApply: mustWaitForApply,
                snapshotChanged: snapshotChanged,
                previouslyNewestMessagesLoaded: previouslyNewestMessagesLoaded
            )
            
            strongSelf.snapshotInfo = newSnapshotInfo
        }
    }
    
    private func convertSnapshot(snapshot: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>)
        -> ChatViewDiffableDataSourceSnapshot {
        let startTime = CACurrentMediaTime()
        defer {
            let endTime = CACurrentMediaTime()
            DDLogVerbose("ChatView: \(#function) duration \(endTime - startTime) s")
        }
        
        var newSnapshot = ChatViewDiffableDataSourceSnapshot()
        
        let flippedTableView = UserSettings.shared().flippedTableView
        let sectionIdentifiers = !flippedTableView ? snapshot.sectionIdentifiers : snapshot.sectionIdentifiers
            .reversed()
        newSnapshot.appendSections(sectionIdentifiers)
        
        for sectionIdentifier in sectionIdentifiers {
            let itemIdentifiers = !flippedTableView ? snapshot.itemIdentifiers(inSection: sectionIdentifier) : snapshot
                .itemIdentifiers(inSection: sectionIdentifier).reversed()
            for objectID in itemIdentifiers {
                if let unreadMessagesState = unreadMessagesSnapshot.unreadMessagesState,
                   objectID == unreadMessagesState.oldestConsecutiveUnreadMessage {
                    if !UserSettings.shared().flippedTableView {
                        newSnapshot.appendItems(
                            [CellType.unreadLine(state: unreadMessagesState)],
                            toSection: sectionIdentifier
                        )
                    }
                }
                
                newSnapshot.appendItems([CellType.message(objectID: objectID)], toSection: sectionIdentifier)
            }
        }
        
        if let unreadMessagesState = unreadMessagesSnapshot.unreadMessagesState,
           let objectID = unreadMessagesState.oldestConsecutiveUnreadMessage {
            if UserSettings.shared().flippedTableView {
                newSnapshot.insertItems(
                    [CellType.unreadLine(state: unreadMessagesState)],
                    afterItem: CellType.message(objectID: objectID)
                )
            }
        }
        
        // Handle Typing Indicator
        /// If we receive a new message from our contact, we receive the new message and immediately *after* the typing indicator is removed.
        /// This will result in a weird animation because we scroll up to show both the new message and the typing indicator only to immediately remove the typing indicator.
        /// To avoid this we check if the last cell type in the current snapshot is the typing indicator. If this is true and the last cell containing an actual message
        /// in the current and next snapshot contain the same message, then we have not added a new message and continue to show the typing indicator.
        /// (Note that the cell immediately before the typing indicator always contains a message if it contains more than one item.)
        /// With this check in place we may still incorrectly remove the typing indicator when sending a message ourselves while our contact is still typing. We thus
        /// additionally check if the last cell was the typing indicator and  the last message in the new snapshot is ours, then we continue to show the typing indicator
        if let previousSnapshotInfo = previousSnapshotInfo, let delegate = delegate {
            let currentSnapshot = previousSnapshotInfo.snapshot
            let currentIdentifierCount = currentSnapshot.itemIdentifiers.count
            let isTypingDuringInitialSetup = isCurrentlyTyping(conversation: conversation) &&
                !delegate.initialSetupCompleted
            let lastMessageIsOurs: Bool
            let lastMessageFromContactIsUnchanged = currentSnapshot.itemIdentifiers.last == .typingIndicator
                && currentIdentifierCount > 1
                && currentSnapshot.itemIdentifiers[currentIdentifierCount - 2] == newSnapshot.itemIdentifiers.last
            
            if let lastItem = snapshot.itemIdentifiers.last,
               messageIsOwn(messageID: lastItem),
               currentSnapshot.itemIdentifiers.last == .typingIndicator {
                lastMessageIsOurs = true
            }
            else {
                lastMessageIsOurs = false
            }
            
            if (lastMessageIsOurs || lastMessageFromContactIsUnchanged) || isTypingDuringInitialSetup {
                insertTypingIndicatorIntoSnapshot(snapshot: &newSnapshot)
            }
        }
        
        // This is needed to update the name and avatar of group messages when deleting selected messages
        if let prev = previousSnapshotInfo?.snapshot, prev.numberOfItems > newSnapshot.numberOfItems {
            let previousContainsUnreadLine = prev.itemIdentifiers.contains { cellType in
                if case .unreadLine(state: _) = cellType {
                    return true
                }
                return false
            }
            
            let nextContainsUnreadLine = newSnapshot.itemIdentifiers.contains { cellType in
                if case .unreadLine(state: _) = cellType {
                    return true
                }
                return false
            }
            
            let noLongerUnreadLine = previousContainsUnreadLine &&
                !nextContainsUnreadLine &&
                prev.numberOfItems - newSnapshot.numberOfItems == 1
            
            let noLongerTyping = prev.itemIdentifiers.contains(.typingIndicator) && !newSnapshot
                .itemIdentifiers.contains(.typingIndicator) && prev.numberOfItems - newSnapshot
                .numberOfItems == 1
            if !noLongerTyping, !noLongerUnreadLine {
                newSnapshot.reconfigureItems(newSnapshot.itemIdentifiers)
            }
        }
        
        if #available(iOS 15.0, *) {
            for objectID in snapshot.reloadedItemIdentifiers {
                newSnapshot.reloadItems([CellType.message(objectID: objectID)])
            }
            for objectID in snapshot.reconfiguredItemIdentifiers {
                newSnapshot.reconfigureItems([CellType.message(objectID: objectID)])
            }
        }
        else {
            // Fallback on earlier versions
            newSnapshot.reloadItems(newSnapshot.itemIdentifiers)
        }
        
        return newSnapshot
    }
    
    // MARK: - Snapshot Update Helper Functions
    
    /// Gets the current snapshot , removes the unread message line if it is displayed and immediately applies the new snapshot
    func removeUnreadMessageLine() {
        snapshotProviderQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            var newSnapshot = strongSelf.previousSnapshotInfo?.snapshot ?? ChatViewDiffableDataSourceSnapshot()
            
            guard let unreadMessageLine = newSnapshot.itemIdentifiers.first(where: { cellType in
                if case CellType.unreadLine(state: _) = cellType {
                    return true
                }
                return false
            }) else {
                return
            }
            
            newSnapshot.deleteItems([unreadMessageLine])
            
            strongSelf.snapshotInfo = SnapshotInfo(
                snapshot: newSnapshot,
                shouldAnimate: true,
                mustWaitForApply: true,
                snapshotChanged: nil,
                previouslyNewestMessagesLoaded: strongSelf.previousSnapshotInfo?
                    .previouslyNewestMessagesLoaded ?? false
            )
        }
    }
    
    private func updateTypingIndicator(add: Bool) {
        snapshotProviderQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var newSnapshot = strongSelf.previousSnapshotInfo?.snapshot ?? ChatViewDiffableDataSourceSnapshot()
            
            if add {
                strongSelf.insertTypingIndicatorIntoSnapshot(snapshot: &newSnapshot)
            }
            else {
                newSnapshot.deleteItems([.typingIndicator])
            }
            
            strongSelf.snapshotInfo = SnapshotInfo(
                snapshot: newSnapshot,
                shouldAnimate: true,
                mustWaitForApply: true,
                snapshotChanged: nil,
                previouslyNewestMessagesLoaded: strongSelf.previousSnapshotInfo?
                    .previouslyNewestMessagesLoaded ?? false
            )
        }
    }
    
    /// Inserts the typing indicator in the last position of the snapshot
    /// - Parameter snapshot: Snapshot in which the typing indicator should be inserted
    private func insertTypingIndicatorIntoSnapshot(snapshot: inout NSDiffableDataSourceSnapshot<String, CellType>) {
        let sectionIdentifier: String
        if UserSettings.shared().flippedTableView {
            sectionIdentifier = snapshot.sectionIdentifiers.first ?? DateFormatter
                .relativeMediumDate(for: Date())
        }
        else {
            sectionIdentifier = snapshot.sectionIdentifiers.last ?? DateFormatter
                .relativeMediumDate(for: Date())
        }
        
        if snapshot.numberOfSections == 0 {
            snapshot.appendSections([sectionIdentifier])
        }
        
        if UserSettings.shared().flippedTableView,
           let firstItem = snapshot.itemIdentifiers(inSection: sectionIdentifier).first {
            snapshot.insertItems([.typingIndicator], beforeItem: firstItem)
        }
        else {
            snapshot.appendItems([.typingIndicator], toSection: sectionIdentifier)
        }
    }
    
    // MARK: Helper Functions for Database Objects
    
    private func isCurrentlyTyping(conversation: Conversation) -> Bool {
        var isTyping = false
        entityManager.performBlockAndWait {
            if let message = self.entityManager.entityFetcher
                .existingObject(with: conversation.objectID) as? Conversation {
                isTyping = message.typing.boolValue
            }
        }
        return isTyping
    }
    
    private func messageIsOwn(messageID: NSManagedObjectID) -> Bool {
        var isOwn = false
        entityManager.performBlockAndWait {
            if let message = self.entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessage {
                isOwn = message.isOwnMessage
            }
        }
        return isOwn
    }
    
    // MARK: - Snapshot Property Detection Helper Functions
    
    /// *Approximately* determines whether the next snapshot should animate or not to avoid flickering cells when animating the application of snapshots that only reload cells
    /// Approximately means that flickering may still occur if a cell updates it state in the same snapshot as another one is added.
    /// This should currently not happen as we save often and a new snapshot should be applied after every safe. If these assumptions change we have to be more careful when determining the animation property.
    /// Ideally however we would determine this when creating snapshots and perhaps split a snapshot into animateable and non-animateable subsnapshots.
    /// - Parameters:
    ///   - currSnap: The last snap applied on the dataSource
    ///   - nextSnap: The next snap that will be applied on the dataSource
    /// - Returns: Indicating whether the next snapshotApply should animate or not
    private static func shouldAnimate(
        currSnap: ChatViewDiffableDataSourceSnapshot?,
        nextSnap: ChatViewDiffableDataSourceSnapshot,
        previousSnapshotInfo: SnapshotInfo?
    ) -> Bool {
        /// Do not animate before first snaphot has been applied
        guard previousSnapshotInfo != nil else {
            return false
        }
        
        /// Do not animate before first snaphot has been applied
        /// This is in practice equivalent to the statement above
        guard let currSnap = currSnap else {
            return false
        }
        
        guard currSnap.numberOfItems == nextSnap.numberOfItems else {
            return true
        }
        
        guard currSnap.itemIdentifiers.last == nextSnap.itemIdentifiers.last else {
            return true
        }
        
        return false
    }
    
    /// Approximates a changed snapshot by checking whether the last item identifier has changed
    /// - Parameters:
    ///   - previousSnapshot: Snapshot A
    ///   - nextSnap: Snapshot B
    /// - Returns: The last item identifier of snapshots A and B if they have identical last item identifiers and nil otherwise
    private static func checkSnapshotChanged(
        previousSnapshot: SnapshotInfo?,
        nextSnap: ChatViewDiffableDataSourceSnapshot
    ) -> NSManagedObjectID? {
        if UserSettings.shared().flippedTableView {
            guard case let .message(curr) = previousSnapshot?.snapshot.itemIdentifiers.first,
                  case let .message(next) = nextSnap.itemIdentifiers.first, next == curr else {
                return nil
            }
            return next
        }
        else {
            guard case let .message(curr) = previousSnapshot?.snapshot.itemIdentifiers.last,
                  case let .message(next) = nextSnap.itemIdentifiers.last, next == curr else {
                return nil
            }
            return next
        }
    }
}

extension ChatViewSnapshotProvider {
    /// Batches two snapshots together retaining all relevant information.
    /// The items from `snapshotB` will be used and merged with the reconfigured / reloaded item identifiers from the previous `snapshotA`.
    /// - Parameters:
    ///   - snapshotA: Older snapshot
    ///   - snapshotB: Newer snapshot
    /// - Returns: Combined snapshot
    static func batchSnapshotsTogether(_ snapshotA: SnapshotInfo, _ snapshotB: SnapshotInfo) -> SnapshotInfo {
        let startTime = CACurrentMediaTime()
        defer {
            let endTime = CACurrentMediaTime()
            DDLogVerbose("Combined Snapshots in \(endTime - startTime) s")
        }
        var newSnapshot = NSDiffableDataSourceSnapshot<String, CellType>()
        
        newSnapshot = snapshotB.snapshot
        newSnapshot
            .reconfigureItems(
                snapshotA.snapshot.reconfiguredItemIdentifiers
                    .filter { newSnapshot.itemIdentifiers.contains($0) }
            )
        newSnapshot
            .reloadSections(
                snapshotA.snapshot.reloadedSectionIdentifiers
                    .filter { newSnapshot.sectionIdentifiers.contains($0) }
            )
        newSnapshot
            .reloadItems(
                snapshotA.snapshot.reloadedItemIdentifiers
                    .filter { newSnapshot.reloadedItemIdentifiers.contains($0) }
            )
        
        let aCount = snapshotA.snapshot.reconfiguredItemIdentifiers.count
        let bCount = snapshotB.snapshot.reconfiguredItemIdentifiers.count
        let nCount = newSnapshot.reconfiguredItemIdentifiers.count
        
        DDLogVerbose("Combined Snapshots from \(aCount) and \(bCount) to \(nCount) didChange \(nCount != bCount)")
        
        let shouldAnimate = snapshotA.shouldAnimate || ChatViewSnapshotProvider.shouldAnimate(
            currSnap: snapshotA.snapshot,
            nextSnap: snapshotB.snapshot,
            previousSnapshotInfo: snapshotA
        )
        
        let mustWaitForApply = true
        
        let snapshotChanged = ChatViewSnapshotProvider.checkSnapshotChanged(
            previousSnapshot: snapshotA,
            nextSnap: snapshotB.snapshot
        ) ?? snapshotA.snapshotChanged
        
        let newSnapshotInfo = SnapshotInfo(
            snapshot: newSnapshot,
            shouldAnimate: shouldAnimate,
            mustWaitForApply: mustWaitForApply,
            snapshotChanged: snapshotChanged,
            previouslyNewestMessagesLoaded: snapshotA.previouslyNewestMessagesLoaded
        )
        
        return newSnapshotInfo
    }
}
