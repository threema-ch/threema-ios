//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
    /// Object IDs of all deleted messages since the creation of this delegate
    var deletedMessagesObjectIDs: Set<NSManagedObjectID> { get }
}

final class ChatViewSnapshotProvider {
    // MARK: - Typealias
    
    typealias ChatViewDiffableDataSourceSnapshot = NSDiffableDataSourceSnapshot<String, ChatViewDataSource.CellType>
    typealias CellType = ChatViewDataSource.CellType
    
    private typealias Config = ChatViewConfiguration.DataSource
    
    // MARK: - Nested Types
    
    struct SnapshotInfo {
        let snapshot: ChatViewDiffableDataSourceSnapshot
        // Changing this has various implications on the whole snapshot apply and UITableView state after applying the
        // snapshot
        // if you change this, make sure to test extensively and check the comment in `ChatViewDataSource` line 448
        let rowAnimation: UITableView.RowAnimation
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
    
    private var chatViewTypingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProviderProtocol?
        
    // MARK: - Lifecycle
    
    init(
        conversation: Conversation,
        entityManager: EntityManager,
        messageProvider: MessageProvider,
        unreadMessagesSnapshot: UnreadMessagesStateManager,
        typingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProviderProtocol? = nil,
        delegate: ChatViewSnapshotProviderDelegate,
        userSettings: UserSettingsProtocol
    ) {
        self.conversation = conversation
        self.entityManager = entityManager
        self.messageProvider = messageProvider
        self.delegate = delegate
        self.unreadMessagesSnapshot = unreadMessagesSnapshot
        
        if let typingIndicatorInformationProvider {
            self.chatViewTypingIndicatorInformationProvider = typingIndicatorInformationProvider
        }
        else {
            self.chatViewTypingIndicatorInformationProvider = ChatViewTypingIndicatorInformationProvider(
                conversation: conversation,
                entityManager: entityManager
            )
        }
        
        loadInitialMessagesAndObserveChanges()
        
        addObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration Functions
    
    private func loadInitialMessagesAndObserveChanges() {
        let typingIndicatorThrottle = ChatViewConfiguration.DataSource.typingIndicatorThrottle
        
        chatViewTypingIndicatorInformationProvider?.currentlyTypingPublisher
            .receive(on: snapshotProviderQueue)
            .throttle(
                for: RunLoop.SchedulerTimeType.Stride(typingIndicatorThrottle),
                scheduler: RunLoop.main,
                latest: true
            )
            .sink { [weak self] isTyping in
                guard let self else {
                    return
                }
                
                guard let delegate, delegate.initialSetupCompleted else {
                    return
                }
                
                updateTypingIndicator(add: isTyping)
            }
            .store(in: &cancellables)
        
        unreadMessagesSnapshot.$unreadMessagesState
            .throttle(
                for: .milliseconds(Config.unreadMessagesSnapshotStateThrottleInMs),
                scheduler: snapshotProviderQueue,
                latest: false
            )
            .receive(on: snapshotProviderQueue)
            .sink { [weak self] unreadMessagesState in
                guard let delegate = self?.delegate, delegate.initialSetupCompleted else {
                    return
                }
                
                if let unreadMessagesState, unreadMessagesState.numberOfUnreadMessages <= 0 {
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
                guard let self else {
                    return
                }
                
                guard let messages else {
                    return
                }
                
                prepareAndPublishSnapshot(messages: messages)
            }
            .store(in: &cancellables)
    }
    
    private func addObservers() {
        // Reload the chat on significant time changes (e.g. new day) to update section headers
        // Use a selector, otherwise it will n
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )
    }
    
    /// Reload the chat to update section headers
    @objc private func dayChanged() {
        messageProvider.refetch()
    }
    
    private func prepareAndPublishSnapshot(messages: MessageProvider.MessagesSnapshot) {
        DDLogVerbose("prepareAndPublishSnapshot async")
        snapshotProviderQueue.async { [weak self] in
            DDLogVerbose("prepareAndPublishSnapshot start")
            guard let strongSelf = self else {
                return
            }
            
            let convertedSnapshot = strongSelf.convertSnapshot(snapshot: messages.snapshot)
            strongSelf.publish(
                convertedSnapshot,
                previouslyNewestMessagesLoaded: messages.previouslyNewestMessagesLoaded
            )
            DDLogVerbose("prepareAndPublishSnapshot end")
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
            // If you change this, you should first read the fun observation on `shouldAnimate` in ChatViewDataSource
            // line 448
            let defaultAnimation: UITableView.RowAnimation = .fade
            
            let newSnapshotInfo = SnapshotInfo(
                snapshot: snapshot,
                rowAnimation: shouldAnimate ? defaultAnimation : .none,
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
        
        let sectionIdentifiers = snapshot.sectionIdentifiers
        newSnapshot.appendSections(sectionIdentifiers)
        
        for sectionIdentifier in sectionIdentifiers {
            let itemIdentifiers = snapshot.itemIdentifiers(inSection: sectionIdentifier)
            for objectID in itemIdentifiers {
                // Don't add deleted messages to converted snapshot
                guard let delegate, !delegate.deletedMessagesObjectIDs.contains(objectID) else {
                    continue
                }
                
                if let unreadMessagesState = unreadMessagesSnapshot.unreadMessagesState,
                   objectID == unreadMessagesState.oldestConsecutiveUnreadMessage {
                    newSnapshot.appendItems(
                        [CellType.unreadLine(state: unreadMessagesState)],
                        toSection: sectionIdentifier
                    )
                }
                
                newSnapshot.appendItems([CellType.message(objectID: objectID)], toSection: sectionIdentifier)
            }
            
            // Remove empty sections that might exist after filtering deleted messages
            if newSnapshot.itemIdentifiers(inSection: sectionIdentifier).isEmpty {
                newSnapshot.deleteSections([sectionIdentifier])
            }
        }
        
        if let unreadMessagesState = unreadMessagesSnapshot.unreadMessagesState,
           let objectID = unreadMessagesState.oldestConsecutiveUnreadMessage,
           newSnapshot.itemIdentifiers.contains(CellType.message(objectID: objectID)) { }
        else {
            DDLogVerbose("\(#function) Don't add unread message line")
        }
        
        // Handle Typing Indicator
        /// If we receive a new message from our contact, we receive the new message and immediately *after* the typing
        /// indicator is removed.
        /// This will result in a weird animation because we scroll up to show both the new message and the typing
        /// indicator only to immediately remove the typing indicator.
        /// To avoid this we check if the last cell type in the current snapshot is the typing indicator. If this is
        /// true and the last cell containing an actual message in the current and next snapshot contain the same
        /// message, then we have not added a new message and continue to show the typing indicator.
        /// (Note that the cell immediately before the typing indicator always contains a message if it contains more
        /// than one item.)
        /// With this check in place we may still incorrectly remove the typing indicator when sending a message
        /// ourselves while our contact is still typing. We thus additionally check if the last cell was the typing
        /// indicator and  the last message in the new snapshot is ours, then we continue to show the typing indicator
        if let delegate {
            let isTypingDuringInitialSetup = isCurrentlyTyping(conversation: conversation) &&
                !delegate.initialSetupCompleted
            let lastMessageIsOurs: Bool
            let lastMessageFromContactIsUnchanged: Bool
            
            if let previousSnapshotInfo {
                let currentSnapshot = previousSnapshotInfo.snapshot
                let currentIdentifierCount = currentSnapshot.itemIdentifiers.count
                
                let currentSnapshotLastMessage = currentSnapshot.itemIdentifiers.last
                let newSnapshotLastMessage = newSnapshot.itemIdentifiers.last
                
                // Has our contact sent a new message?
                let regularPrePreviousMessage = currentSnapshot.numberOfItems == 0 ? nil : currentSnapshot
                    .itemIdentifiers[max(0, currentIdentifierCount - 2)]
                let prePreviousMessage = regularPrePreviousMessage
                
                // Did we previously show the typing indicator and this is just some snapshot that isn't adding any more
                // items?
                let regularPreviousMessage = currentSnapshot.numberOfItems == 0 ? nil : currentSnapshot
                    .itemIdentifiers[max(0, currentIdentifierCount - 1)]
                let previousMessage = regularPreviousMessage
                
                lastMessageFromContactIsUnchanged = currentSnapshotLastMessage == .typingIndicator
                    && currentIdentifierCount > 1
                    && prePreviousMessage != nil
                    && (prePreviousMessage == newSnapshotLastMessage || previousMessage == newSnapshotLastMessage)
                
                if let lastItem = snapshot.itemIdentifiers.last,
                   messageIsOwn(messageID: lastItem),
                   currentSnapshotLastMessage == .typingIndicator {
                    lastMessageIsOurs = true
                }
                else {
                    lastMessageIsOurs = false
                }
            }
            else {
                lastMessageIsOurs = false
                lastMessageFromContactIsUnchanged = false
            }
            
            if (lastMessageIsOurs || lastMessageFromContactIsUnchanged) || isTypingDuringInitialSetup {
                DDLogVerbose("Insert typing indicator")
                insertTypingIndicatorIntoSnapshot(snapshot: &newSnapshot)
            }
        }
        
        // This is needed to update the name and profile picture of group messages when deleting selected messages
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
        
        for objectID in snapshot.reloadedItemIdentifiers {
            // These items shouldn't be reloaded and are most likely not in the converted snapshot
            guard let delegate, !delegate.deletedMessagesObjectIDs.contains(objectID) else {
                continue
            }
            
            newSnapshot.reloadItems([CellType.message(objectID: objectID)])
        }
        for objectID in snapshot.reconfiguredItemIdentifiers {
            // These items shouldn't be reconfigured and are most likely not in the converted snapshot
            guard let delegate, !delegate.deletedMessagesObjectIDs.contains(objectID) else {
                continue
            }
            
            newSnapshot.reconfigureItems([CellType.message(objectID: objectID)])
        }
        
        return newSnapshot
    }
    
    // MARK: - Snapshot Update Helper Functions
    
    /// Gets the current snapshot , removes the unread message line if it is displayed and immediately applies the new
    /// snapshot
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
                rowAnimation: .fade,
                mustWaitForApply: true,
                snapshotChanged: nil,
                previouslyNewestMessagesLoaded: strongSelf.previousSnapshotInfo?
                    .previouslyNewestMessagesLoaded ?? false
            )
        }
    }
    
    /// Call this method when you need to apply changes of messages that are not automatically detected by the fetched
    /// results controller. This will reconfigure the object if it was in a previous snapshot.
    /// - Parameter objectID: `NSManagedObjectID` of the message to be reconfigured
    func applyAdditionalSnapshotForMessage(with objectID: NSManagedObjectID) {
        snapshotProviderQueue.async { [weak self] in
            guard let strongSelf = self, let previousSnapshotInfo = strongSelf.previousSnapshotInfo else {
                return
            }
            
            var previousSnapshot = previousSnapshotInfo.snapshot
            
            guard previousSnapshot.itemIdentifiers.contains(.message(objectID: objectID)) else {
                return
            }
            
            previousSnapshot.reconfigureItems([.message(objectID: objectID)])
            
            strongSelf.snapshotInfo = SnapshotInfo(
                snapshot: previousSnapshot,
                rowAnimation: .none,
                mustWaitForApply: true,
                snapshotChanged: nil,
                previouslyNewestMessagesLoaded: previousSnapshotInfo.previouslyNewestMessagesLoaded
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
                if newSnapshot.indexOfItem(.typingIndicator) != nil {
                    newSnapshot.deleteItems([.typingIndicator])
                }
            }
            
            strongSelf.snapshotInfo = SnapshotInfo(
                snapshot: newSnapshot,
                rowAnimation: .fade,
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
        let sectionIdentifier: String = snapshot.sectionIdentifiers.last ?? DateFormatter
            .relativeMediumDate(for: Date())
        
        if snapshot.numberOfSections == 0 {
            snapshot.appendSections([sectionIdentifier])
        }
        
        if let lastItem = snapshot.itemIdentifiers(inSection: sectionIdentifier).last {
            guard lastItem != .typingIndicator else {
                DDLogVerbose("Do not insert typing indicator because it is already at the correct position")
                return
            }
            
            appendOrMove(itemIdentifier: .typingIndicator, afterItem: lastItem, in: &snapshot)
        }
        else {
            let message = "Couldn't insert typing indicator because section was invalid"
            if ChatViewConfiguration.strictMode {
                #if DEBUG
                    raise(SIGINT)
                #else
                    fatalError(message)
                #endif
            }
            else {
                DDLogError("\(message)")
            }
        }
    }
    
    private func insertOrMove(
        itemIdentifier: CellType,
        beforeItem: CellType,
        in snapshot: inout NSDiffableDataSourceSnapshot<String, CellType>
    ) {
        assert(itemIdentifier != beforeItem)
        
        if snapshot.itemIdentifiers.contains(where: { cellType in
            cellType == itemIdentifier.self
        }) {
            if let currentIndex = snapshot.indexOfItem(itemIdentifier),
               let beforeItemIndex = snapshot.indexOfItem(beforeItem) {
                guard currentIndex != beforeItemIndex - 1 else {
                    // We are already at the requested index
                    return
                }
            }
            
            snapshot.moveItem(itemIdentifier, beforeItem: beforeItem)
        }
        else {
            snapshot.insertItems([.typingIndicator], beforeItem: beforeItem)
        }
    }
    
    private func appendOrMove(
        itemIdentifier: CellType,
        afterItem: CellType,
        in snapshot: inout NSDiffableDataSourceSnapshot<String, CellType>
    ) {
        assert(itemIdentifier != afterItem)
        
        if snapshot.itemIdentifiers.contains(where: { cellType in
            cellType == itemIdentifier.self
        }) {
            if let currentIndex = snapshot.indexOfItem(itemIdentifier),
               let beforeItemIndex = snapshot.indexOfItem(afterItem) {
                guard currentIndex != beforeItemIndex + 1 else {
                    // We are already at the requested index
                    return
                }
            }
            snapshot.moveItem(itemIdentifier, afterItem: afterItem)
        }
        else {
            snapshot.insertItems([itemIdentifier], afterItem: afterItem)
        }
    }
    
    // MARK: Helper Functions for Database Objects
    
    private func isCurrentlyTyping(conversation: Conversation) -> Bool {
        var isTyping = false
        entityManager.performAndWait {
            if let conversation = self.entityManager.entityFetcher
                .existingObject(with: conversation.objectID) as? Conversation {
                isTyping = conversation.typing.boolValue
            }
        }
        return isTyping
    }
    
    private func messageIsOwn(messageID: NSManagedObjectID) -> Bool {
        var isOwn = false
        entityManager.performAndWait {
            if let message = self.entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessage {
                isOwn = message.isOwnMessage
            }
        }
        return isOwn
    }
    
    // MARK: - Snapshot Property Detection Helper Functions
    
    /// *Approximately* determines whether the next snapshot should animate or not to avoid flickering cells when
    /// animating the application of snapshots that only reload cells
    /// Approximately means that flickering may still occur if a cell updates it state in the same snapshot as another
    /// one is added.
    /// This should currently not happen as we save often and a new snapshot should be applied after every safe. If
    /// these assumptions change we have to be more careful when determining the animation property.
    /// Ideally however we would determine this when creating snapshots and perhaps split a snapshot into animateable
    /// and non-animateable subsnapshots.
    /// - Parameters:
    ///   - currSnap: The last snap applied on the dataSource
    ///   - nextSnap: The next snap that will be applied on the dataSource
    /// - Returns: Indicating whether the next snapshotApply should animate or not
    private static func shouldAnimate(
        currSnap: ChatViewDiffableDataSourceSnapshot?,
        nextSnap: ChatViewDiffableDataSourceSnapshot,
        previousSnapshotInfo: SnapshotInfo?
    ) -> Bool {
        /// Do not animate before first snapshot has been applied
        guard previousSnapshotInfo != nil else {
            return false
        }
        
        /// Do not animate before first snapshot has been applied
        /// This is in practice equivalent to the statement above
        guard let currSnap else {
            return false
        }
                
        guard !Set(currSnap.itemIdentifiers).intersection(nextSnap.itemIdentifiers).isEmpty else {
            return false
        }
        
        return true
    }
    
    /// Approximates a changed snapshot by checking whether the last item identifier has changed
    /// - Parameters:
    ///   - previousSnapshot: Snapshot A
    ///   - nextSnap: Snapshot B
    /// - Returns: The last item identifier of snapshots A and B if they have identical last item identifiers and nil
    ///            otherwise
    private static func checkSnapshotChanged(
        previousSnapshot: SnapshotInfo?,
        nextSnap: ChatViewDiffableDataSourceSnapshot,
        userSettings: UserSettingsProtocol = UserSettings.shared()
    ) -> NSManagedObjectID? {
        guard case let .message(curr) = previousSnapshot?.snapshot.itemIdentifiers.last,
              case let .message(next) = nextSnap.itemIdentifiers.last, next == curr else {
            return nil
        }
        return next
    }
}

extension ChatViewSnapshotProvider {
    /// Batches two snapshots together retaining all relevant information.
    /// The two snapshots must have equal values for `rowAnimations` otherwise the output is undefined.
    /// The items from `snapshotB` will be used and merged with the reconfigured / reloaded item identifiers from the
    /// previous `snapshotA`.
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
                    .filter {
                        newSnapshot.itemIdentifiers.contains($0) && !newSnapshot.reloadedItemIdentifiers.contains($0)
                    }
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
        
        let mustWaitForApply = true
        
        let snapshotChanged = ChatViewSnapshotProvider.checkSnapshotChanged(
            previousSnapshot: snapshotA,
            nextSnap: snapshotB.snapshot
        ) ?? snapshotA.snapshotChanged
        
        // We need to check if one of the two snapshots has an animation that is not none.
        let rowAnimation: UITableView.RowAnimation
        switch (snapshotA.rowAnimation, snapshotB.rowAnimation) {
        case (.none, .none):
            rowAnimation = .none
            
        case let (a, b) where a != .none && b == .none:
            rowAnimation = a
            
        case let (a, b) where a == .none && b != .none:
            rowAnimation = b
            
        case let (a, b) where a == b:
            rowAnimation = a

        default:
            DDLogError(
                "Animations were both not none (a:\(snapshotA.rowAnimation), b: \(snapshotB.rowAnimation), This must not occur. Will use .fade as fallback."
            )
            rowAnimation = .none
        }
        
        let newSnapshotInfo = SnapshotInfo(
            snapshot: newSnapshot,
            rowAnimation: rowAnimation,
            mustWaitForApply: mustWaitForApply,
            snapshotChanged: snapshotChanged,
            previouslyNewestMessagesLoaded: snapshotA.previouslyNewestMessagesLoaded
        )
        
        return newSnapshotInfo
    }
}
