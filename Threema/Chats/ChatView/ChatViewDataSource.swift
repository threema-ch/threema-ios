//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit
import ThreemaFramework

protocol ChatViewDataSourceDelegate: AnyObject {
    /// Called before a new snapshot is applied
    ///
    /// This is always called on the main queue. This might be called multiple times before the corresponding `didApplySnapshot()` is called.
    ///
    /// - Parameter currentDoesIncludeNewestMessage: Should the current snapshot include the newest message? (`false` if this is the first snapshot)
    func willApplySnapshot(currentDoesIncludeNewestMessage: Bool)
    
    /// Called after a new snapshot was applied
    ///
    /// This is always called on the main queue.
    func didApplySnapshot(delegateScrollCompletion: @escaping (() -> Void))
    
    func lastMessageChanged(messageIdentifier: NSManagedObjectID)
    
    func didDeleteMessages()
    
    var willDisappear: Bool { get }
}

/// Manage the table view data for a chat view
///
/// The data sources uses a `MessageProvider` to load messages and `ChatViewCellProvider` for cell registration, loading and
/// configuration.
class ChatViewDataSource: UITableViewDiffableDataSource<String, ChatViewDataSource.CellType> {
    typealias Config = ChatViewConfiguration.DataSource
    
    struct MessageNeighbors {
        let previousMessage: BaseMessage?
        let nextMessage: BaseMessage?
        
        static let noNeighbors = MessageNeighbors(previousMessage: nil, nextMessage: nil)
    }
    
    enum CellType: Hashable {
        case message(objectID: NSManagedObjectID)
        case unreadLine(state: UnreadMessagesStateManager.UnreadMessagesState)
        case typingIndicator
    }
    
    enum DataSourceError: Error {
        /// Used to cancel message load requests
        case cancelled
    }
    
    /// Last index path of the data
    var bottomIndexPath: IndexPath? {
        let snapshot = snapshot()
        let sectionIndex = snapshot.numberOfSections - 1
        
        // This should fail if we have an empty table view
        guard sectionIndex >= 0 else {
            return nil
        }
        
        guard !flippedTableView else {
            return IndexPath(row: 0, section: 0)
        }
        
        let lastSectionIdentifier = snapshot.sectionIdentifiers[sectionIndex]
        let lastItemInSectionIndex = snapshot.numberOfItems(inSection: lastSectionIdentifier) - 1
        
        guard lastItemInSectionIndex >= 0 else {
            return nil
        }
        
        return IndexPath(item: lastItemInSectionIndex, section: sectionIndex)
    }
    
    var topIndexPath: IndexPath? {
        let snapshot = snapshot()
        let sectionIndex = snapshot.numberOfSections - 1
        
        // This should fail if we have an empty table view
        guard sectionIndex >= 0 else {
            return nil
        }
        
        guard flippedTableView else {
            return IndexPath(row: 0, section: 0)
        }
        
        let lastSectionIdentifier = snapshot.sectionIdentifiers[sectionIndex]
        let lastItemInSectionIndex = snapshot.numberOfItems(inSection: lastSectionIdentifier) - 1
        
        guard lastItemInSectionIndex >= 0 else {
            return nil
        }
        
        return IndexPath(item: lastItemInSectionIndex, section: sectionIndex)
    }
    
    private var snapshotApplyTiming = CFAbsoluteTimeGetCurrent()
    
    /// Is the initial setup completed (e.g. scroll position restored)
    ///
    /// Set to true after the initial setup of messages loading is completed.
    var initialSetupCompleted = false {
        didSet {
            if initialSetupCompleted {
                DDLogVerbose("Initial setup completed!")
            }
        }
    }
    
    /// Keep track if the previous snapshot contained the newest messages
    /// This is needed by the chat view to decide if we scrolled all the way to the bottom
    var previouslyNewestMessagesLoaded = false
    
    /// Is the data source in the process of loading (more) messages?
    ///
    /// Only set after `initialSetupCompleted` is `true`
    private(set) var isLoadingNewMessages = false
    
    private let flippedTableView = UserSettings.shared().flippedTableView
    
    /// Used for ensuring mutual exclusion between animated scrolling and applying new snapshots
    /// `apply(_:animatingDifferences:)` will cancel in progress animations such as animated scrolling to the newest cell.
    /// We therefore do not want to apply new snapshots while we're scrolling to the newest cell in `didApplySnapshot`.
    /// This may be used on other instances as well but be wary of deadlocks.
    let snapshotApplyLock = NSLock()

    // MARK: - Private properties
    
    private let conversation: Conversation
    private weak var delegate: ChatViewDataSourceDelegate?
    private weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol?
    private weak var chatViewTableViewVoiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegateProtocol?
    
    private let entityManager: EntityManager
    private let messageProvider: MessageProvider
    
    private let unreadMessagesSnapshot: UnreadMessagesStateManager
    
    private lazy var snapshotProvider = ChatViewSnapshotProvider(
        conversation: conversation,
        entityManager: entityManager,
        messageProvider: messageProvider,
        unreadMessagesSnapshot: unreadMessagesSnapshot,
        delegate: self,
        userSettings: UserSettings.shared()
    )
    
    private let dataSourceApplyQueue = DispatchQueue(
        label: "ch.threema.chatView.dataSource.applyQueue",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    
    private let preDebounceDataSourceApplyQueue = DispatchQueue(
        label: "ch.threema.chatView.dataSource.preDebounceApplyQueue",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    
    /// Depending on the orientation of the tableView `firstOrLastMessage` contains the first or the last message in the requested snapshot
    private var fetchRequestSnapshotApplyStore: (firstOrLastMessage: NSManagedObjectID?, seal: Resolver<Void>)?
    
    private var bottomIdentifier: NSManagedObjectID? {
        guard let bottomIndexPath = bottomIndexPath else {
            return nil
        }
        
        guard case let .message(objectID) = itemIdentifier(for: bottomIndexPath) else {
            return nil
        }
        
        return objectID
    }
    
    private lazy var chatViewTypingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProvider? =
        ChatViewTypingIndicatorInformationProvider(
            conversation: conversation,
            entityManager: entityManager
        )
    
    private var afterFirstSnapshotApply: (() -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    private var lastSnapApply: NSDiffableDataSourceSnapshot<String, CellType>?
    
    private lazy var selectedObjectIDs = Set<NSManagedObjectID>()
    
    /// Object IDs of all deleted messages using multiselect since the creation of the data source (i.e. opening a chat)
    ///
    /// This is also needed for `ChatViewSnapshotProviderDelegate` conformance
    lazy var deletedMessagesObjectIDs = Set<NSManagedObjectID>()
    
    // MARK: - Lifecycle
    
    /// Crate a new chat view data source
    /// - Parameters:
    ///   - conversation: Messages of this conversation will be provided by this data source
    ///   - tableView: Table view that will display the messages
    ///   - delegate: `ChatViewDataSourceDelegate` that is informed about certain changes
    ///   - chatViewTableViewCellDelegate: `ChatViewTableViewCellDelegateProtocol` that is informed about cell delegates
    ///   - chatViewTableViewVoiceMessageCellDelegate: `ChatViewTableViewVoiceMessageCellDelegate` that is informed about voice message changes
    ///   - entityManager: Entity manager used to fetch messages from the object store
    ///   - date: Date to load messages around. If `nil` newest messages are loaded.
    ///   - afterFirstSnapshotApply: Closure called only on first apply to data source snapshot (this will be called on the main queue)
    init(
        for conversation: Conversation,
        in tableView: UITableView,
        delegate: ChatViewDataSourceDelegate,
        chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol,
        chatViewTableViewVoiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegateProtocol,
        entityManager: EntityManager,
        loadAround date: () -> Date?,
        afterFirstSnapshotApply: @escaping () -> Void,
        unreadMessagesSnapshot: UnreadMessagesStateManager
    ) {
        self.conversation = conversation
        self.delegate = delegate
        self.entityManager = entityManager
        self.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
        self.chatViewTableViewVoiceMessageCellDelegate = chatViewTableViewVoiceMessageCellDelegate
        self.afterFirstSnapshotApply = afterFirstSnapshotApply
        self.unreadMessagesSnapshot = unreadMessagesSnapshot
        
        // Workaround to fix circular `self` dependency during initialization
        // For the super class's initializer we need a `CellProvider` that needs to reference the message provider.
        // As `self` is not available before the super call we need to workaround this circular dependency.
        // Solved by steps 1 - 3 below:
        
        // 1. Create message provider stored in a local constant (needed) that can be referenced in the `CellProvider`
        let messageProvider = MessageProvider(
            for: conversation,
            around: date(),
            entityManager: entityManager
        )
        self.messageProvider = messageProvider
        
        // Ensure that cells will be available in our cell provider
        ChatViewCellProvider.registerCells(in: tableView)
        let chatViewCellProvider = ChatViewCellProvider(
            chatViewTableViewCellDelegate: chatViewTableViewCellDelegate,
            chatViewTableViewVoiceMessageCellDelegate: chatViewTableViewVoiceMessageCellDelegate
        )
        
        // 2. Setup class and use message provider in this call
        super.init(tableView: tableView) { tableView, indexPath, cellType in
            // TODO: (IOS-2014) Is it a problem that we load the message by object id and not
            // by index path? We don't take advantage of batch fetching here, but it might never happen anyway.
            
            switch cellType {
            case let .message(objectID: messageObjectID):
                guard let message = messageProvider.message(for: messageObjectID) else {
                    // This might happen if a delayed* snapshot apply still contains a message that was deleted in the
                    // meantime (e.g. when a group is dissolved and deleted at the "same" time).
                    // * the delay might be from us or from the apply API itself
                    DDLogError("Unable to load requested message. Show close to zero cell instead")
                    
                    return chatViewCellProvider.closeToZeroHeightCell(in: tableView, at: indexPath)
                }
                
                let neighbors = ChatViewDataSource.neighbors(of: messageObjectID, in: tableView, with: entityManager)
                
                let cell = chatViewCellProvider.cell(
                    for: message,
                    with: neighbors,
                    in: tableView,
                    at: indexPath
                )
                
                return cell
            case .typingIndicator:
                return chatViewCellProvider.typingIndicator(in: tableView, at: indexPath)
            case let .unreadLine(state: state):
                let cell = chatViewCellProvider.unreadMessageLine(
                    with: state.numberOfUnreadMessages,
                    in: tableView,
                    at: indexPath
                )
                return cell
            }
        }
        
        // Do our configuration
        configureDataSource()
        
        // 3. Load initial messages and observe changes
        loadInitialMessagesAndObserveChanges()
    }
    
    deinit {
        DDLogVerbose("\(#function)")
        self.fetchRequestSnapshotApplyStore?.seal.reject(DataSourceError.cancelled)
    }
        
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<String, CellType>.CellProvider
    ) {
        fatalError("Not supported")
    }
    
    // MARK: - Configure

    private func configureDataSource() {
        // TODO: (IOS-2014) Maybe add an empty snapshot to not crash if there was no snapshot so far
    }
    
    private func loadInitialMessagesAndObserveChanges() {
        // The actual subscription is handled by the `Subscriber` extension below
        snapshotProvider.$snapshotInfo
            .receive(on: preDebounceDataSourceApplyQueue)
            .compactMap { $0 }
            .debounceSnapshots(scheduler: dataSourceApplyQueue)
            .receive(on: dataSourceApplyQueue)
            .flatMap(maxPublishers: .max(1)) { [weak self] value -> Future<Void, Never> in
                Future<Void, Never> { [weak self] promise in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    // Ensure that we don't try to apply a snapshot with deleted messages in it
                    let deletesMessagesObjectIDsSet = Set(strongSelf.deletedMessagesObjectIDs.map {
                        CellType.message(objectID: $0)
                    })
                    let snapshotItemIdentifiersSet = Set(value.snapshot.itemIdentifiers)
                    
                    guard deletesMessagesObjectIDsSet.intersection(snapshotItemIdentifiersSet).isEmpty else {
                        DDLogWarn("Tried to apply a snapshot with deleted messages. Refetch now...")
                        strongSelf.messageProvider.refetch()
                        promise(.success(()))
                        return
                    }
                    
                    strongSelf.apply(snapshotInfo: value)
                    
                    // Delay next run after the first snapshot apply
                    let delay = Config.currentMessageSnapshotDelay
                    strongSelf.dataSourceApplyQueue.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                        promise(.success(()))
                    }
                }
            }.sink { $0 }.store(in: &cancellables)
    }
    
    /// Must always be called on `dataSourceApplyQueue`
    /// - Parameter snapshotInfo: Snapshot info to be applied
    private func apply(snapshotInfo: ChatViewSnapshotProvider.SnapshotInfo) {
        DDLogVerbose("apply async")
        
        DDLogVerbose("\(#function) dataSource.snapshotApplyLock.lock()")
        if !snapshotApplyLock.lock(before: Date().addingTimeInterval(5)) {
            let msg = "Could not take lock. This is a fatal error in strict mode. Continue in non-strict mode."
            guard let delegate = delegate, !delegate.willDisappear else {
                DDLogVerbose("Nevermind we have actually already disappeared")
                return
            }
            if ChatViewConfiguration.strictMode {
                fatalError(msg)
            }
            else {
                DDLogError(msg)
                assertionFailure()
            }
        }
        
        DDLogVerbose("apply start")
        let prevSnapshotApplyTiming = snapshotApplyTiming
        
        let startTime = CFAbsoluteTimeGetCurrent()
        snapshotApplyTiming = startTime
        
        let snapshotWillApplyDoneDispatchGroup = DispatchGroup()
        snapshotWillApplyDoneDispatchGroup.enter()
        
        DispatchQueue.main.async {
            DDLogVerbose("willApplySnapshot")
            self.delegate?.willApplySnapshot(
                currentDoesIncludeNewestMessage: snapshotInfo.previouslyNewestMessagesLoaded
            )
            
            if let snapshotChanged = snapshotInfo.snapshotChanged {
                self.delegate?.lastMessageChanged(messageIdentifier: snapshotChanged)
            }
            snapshotWillApplyDoneDispatchGroup.leave()
        }
        
        if snapshotWillApplyDoneDispatchGroup.wait(timeout: .now() + .seconds(15)) == .timedOut {
            guard let delegate = delegate, !delegate.willDisappear else {
                DDLogVerbose("Nevermind we have actually already disappeared")
                return
            }
            let msg =
                "Could not call willApplySnapshot in a timely manner. This is a fatal error in strict mode. Continue in non-strict mode."
            if ChatViewConfiguration.strictMode {
                fatalError(msg)
            }
            else {
                DDLogError(msg)
                #if DEBUG
                    raise(SIGINT)
                #endif
            }
        }
        
        let snapshotApplyDoneDispatchGroup: DispatchGroup?
        
        if snapshotInfo.mustWaitForApply {
            snapshotApplyDoneDispatchGroup = DispatchGroup()
        }
        else {
            snapshotApplyDoneDispatchGroup = nil
        }
        
        snapshotApplyDoneDispatchGroup?.enter()
        
        isLoadingNewMessages = false
        
        // Update the default Row animation based on snapshot info
        defaultRowAnimation = snapshotInfo.rowAnimation
        let shouldAnimate = snapshotInfo.rowAnimation != .none
        
        apply(snapshotInfo.snapshot, animatingDifferences: shouldAnimate) {
            DDLogVerbose("Did apply new snapshot")
            assert(Thread.isMainThread)
            
            self.previouslyNewestMessagesLoaded = snapshotInfo.previouslyNewestMessagesLoaded
            
            self.snapshotApplyLock.unlock()
            
            self.delegate?.didApplySnapshot {
                DDLogVerbose("Leaving DispatchGroup")
                snapshotApplyDoneDispatchGroup?.leave()
            }
        }
        
        /// The scrolling animation may be cancelled by layout changes.
        /// If the scrolling animation is cancelled the completion handler of `didApplySnapshot` is never called
        /// and we run into the timeout here. This causes noticeable delays if the timeout is large.
        /// We should avoid any layout passes as much as possible in the chat view controller.
        let wait = snapshotApplyDoneDispatchGroup?.wait(timeout: .now() + .seconds(15))
        if wait == .timedOut {
            guard let delegate = delegate, !delegate.willDisappear else {
                DDLogVerbose("Nevermind we have actually already disappeared")
                return
            }
                
            /// This might fail if slow animations are enabled
            let msg = "Scroll completion not called within n seconds. Assume that something is wrong."
            if ChatViewConfiguration.strictMode {
                fatalError(msg)
            }
            else {
                DDLogError(msg)
                #if DEBUG
                    raise(SIGINT)
                #endif
            }
            return
        }
        
        /// In order to signal the application of calls to `loadMessages` (see below) we check if the currently applied snapshot
        /// has the same identifier as the last (not cancelled) call to one of the load messages methods.
        ///
        /// If we cannot signal completion but have a fetch request waiting for application we cancel it.
        let firstOrLastMessage = flippedTableView ? snapshotInfo.snapshot.itemIdentifiers.first : snapshotInfo.snapshot
            .itemIdentifiers.last
        if case let .message(objectID) = firstOrLastMessage,
           let fetchRequestSnapshotApplyStore = fetchRequestSnapshotApplyStore {
            if fetchRequestSnapshotApplyStore.firstOrLastMessage == objectID {
                fetchRequestSnapshotApplyStore.seal.fulfill_()
                self.fetchRequestSnapshotApplyStore = nil
            }
            else {
                DDLogWarn(
                    "Cancel previous pending load request because it doesn't match what we have loaded."
                )
                fetchRequestSnapshotApplyStore.seal.reject(DataSourceError.cancelled)
                self.fetchRequestSnapshotApplyStore = nil
            }
        }
        else {
            DDLogWarn("Cancel previous pending load request because it doesn't match what we have loaded.")
            fetchRequestSnapshotApplyStore?.seal.reject(DataSourceError.cancelled)
            fetchRequestSnapshotApplyStore = nil
        }
        
        /// On the first publish we want to signal completion of the first snapshotApply
        DispatchQueue.main.async {
            if self.afterFirstSnapshotApply != nil {
                self.afterFirstSnapshotApply?()
                self.afterFirstSnapshotApply = nil
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        DDLogVerbose("Duration of this snapshot apply \(endTime - startTime) s")
        DDLogVerbose("Time between last snapshot apply and this one \(endTime - prevSnapshotApplyTiming) s")
    }
    
    // MARK: - Helper Functions
    
    static func neighbors(
        of messageObjectID: NSManagedObjectID,
        in tableView: UITableView,
        with entityManager: EntityManager = EntityManager()
    ) -> ChatViewDataSource.MessageNeighbors {
        guard let dataSource = tableView.dataSource as? UITableViewDiffableDataSource<String, CellType> else {
            return .noNeighbors
        }
        
        let snapshot = dataSource.snapshot()
        
        guard let index = snapshot.indexOfItem(.message(objectID: messageObjectID)) else {
            return .noNeighbors
        }
        
        var previousMessage: BaseMessage?
        var nextMessage: BaseMessage?
        
        if index - 1 >= 0, case let .message(objectID: prevObjectID) = snapshot.itemIdentifiers[index - 1] {
            previousMessage = entityManager.entityFetcher.existingObject(with: prevObjectID) as? BaseMessage
        }
        if index + 1 < snapshot.itemIdentifiers.count,
           case let .message(objectID: nextObjectID) = snapshot.itemIdentifiers[index + 1] {
            nextMessage = entityManager.entityFetcher.existingObject(with: nextObjectID) as? BaseMessage
        }
        
        return ChatViewDataSource.MessageNeighbors(previousMessage: previousMessage, nextMessage: nextMessage)
    }

    // MARK: - Multi-Select
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // For performance, we only check if table view is actually in edit mode
        guard tableView.isEditing else {
            return false
        }
        
        guard let cellType = itemIdentifier(for: indexPath),
              case let CellType.message(objectID: objectID) = cellType else {
            return false
        }
        
        var canEdit = true
        
        entityManager.performBlockAndWait {
            guard let message = self.entityManager.entityFetcher.existingObject(with: objectID) else {
                canEdit = false
                return
            }
            
            if let message = message as? SystemMessage,
               case SystemMessage.SystemMessageType.workConsumerInfo = message.systemMessageType {
                canEdit = false
            }
        }
        
        return canEdit
    }
    
    /// Adds object ID of cell at index path to selected cells
    /// - Parameter indexPath: Index path of cell to be selected
    public func didSelectRow(at indexPath: IndexPath) {
        guard let cellType = itemIdentifier(for: indexPath) else {
            return
        }
        
        if case let CellType.message(objectID: objectID) = cellType {
            selectedObjectIDs.insert(objectID)
        }
    }
    
    /// Removes object ID of cell at index path from selected cells
    /// - Parameter indexPath: Index path of cell to be deselected
    public func didDeselectRow(at indexPath: IndexPath) {
        guard let cellType = itemIdentifier(for: indexPath) else {
            return
        }
        
        if case let CellType.message(objectID: objectID) = cellType {
            selectedObjectIDs.remove(objectID)
        }
    }
    
    /// Checks if objectID belongs to a selected message
    /// - Parameter objectID: NSManagedObjectID of message
    /// - Returns: Bool if is selected
    public func isSelected(objectID: NSManagedObjectID) -> Bool {
        selectedObjectIDs.contains(objectID)
    }
    
    /// Returns whether there are currently selected object IDs
    /// - Returns: Bool
    public func hasSelectedObjectIDs() -> Bool {
        !selectedObjectIDs.isEmpty
    }
    
    /// Returns the count of the currently selected object IDs
    /// - Returns: Count as Int
    public func selectedObjectIDsCount() -> Int {
        selectedObjectIDs.count
    }
    
    /// Deletes the currently selected messages
    public func deleteSelectedMessages() {
        guard !selectedObjectIDs.isEmpty else {
            return
        }
        
        // Keep track of all deleted messages IDs
        deletedMessagesObjectIDs = deletedMessagesObjectIDs.union(selectedObjectIDs)
        
        entityManager.performSyncBlockAndSafe {
            var deletedCount = 0
            
            for objectID in self.selectedObjectIDs {
                guard let message = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
                else {
                    continue
                }
                self.entityManager.entityDestroyer.deleteObject(object: message)
                deletedCount += 1
            }
            self.showDeletedNotification(count: deletedCount)
        }
        
        deselectAllMessages()
        conversation.updateLastMessage(with: entityManager)
        
        delegate?.didDeleteMessages()
    }
    
    /// Call before deleting all message in this chat if you do the deletion yourself and don't call `deleteAllMessages()`
    public func willDeleteAllMessages() {
        let messageObjectIDsInCurrentSnapshot: [NSManagedObjectID] = snapshot().itemIdentifiers.compactMap { cellType in
            guard case let CellType.message(objectID: messageObjectID) = cellType else {
                return nil
            }
            
            return messageObjectID
        }
        
        // In rare cases we might miss a message here if the deleted message is already queues up and not published at
        // this point. Then there might be two following updates where in the second update the cell might be
        // reconfigured to another cell leading to a crash.
        deletedMessagesObjectIDs = deletedMessagesObjectIDs.union(messageObjectIDsInCurrentSnapshot)
    }
    
    /// Deletes all messages in conversation
    public func deleteAllMessages() {
        guard selectedObjectIDs.isEmpty else {
            DDLogError("[ChatViewDataSource] SelectedObjectIDs was not empty when deleteAllMessages() was called.")
            return
        }
        
        willDeleteAllMessages()
        
        entityManager.performSyncBlockAndSafe {
            let count = self.entityManager.entityDestroyer.deleteMessages(of: self.conversation)
            self.showDeletedNotification(count: count)
        }
        
        deselectAllMessages()
        conversation.updateLastMessage(with: entityManager)
        
        delegate?.didDeleteMessages()
    }
    
    /// Deselects all currently selected messages
    public func deselectAllMessages() {
        selectedObjectIDs.removeAll()
    }
    
    private func showDeletedNotification(count: Int) {
        let type = NotificationPresenterType(notificationText: String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "notification_deleted_messages_count"),
            count
        ), notificationStyle: .success)
        
        NotificationPresenterWrapper.shared.present(type: type)
    }
    
    // MARK: - Message Load Requests
    
    /// For all message load requests the promise resolves as soon as a snapshot containing the same last message as the fetchRequest has been applied.
    /// It is either fulfilled or cancelled if the last message is different.
    /// If a newer fetchRequest has been added it either cancels earlier fetchRequests or cancels itself.
    ///
    /// Additionally, the promise may be cancelled if the next applied fetch request does not contain the same last message.
    /// The message may however be loaded nevertheless. Cancellation does *not* mean that the message is not present in the last, currently or next applied snapshot.
    
    /// Load message
    /// - Parameter objectID: Object ID of message to load
    /// - Returns: Loaded message if there was any for this object ID
    func message(for objectID: NSManagedObjectID) -> BaseMessage? {
        messageProvider.message(for: objectID)
    }
    
    /// Load messages at the top. This happens asynchronously.
    ///
    /// Not every call leads to new messages as we don't start a new request if one is currently running.
    ///
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    @discardableResult func loadMessagesAtTop() -> Promise<Void> {
        DDLogVerbose("Trying to load more messages at top...")
        return loadMessagesIfAllowed(with: messageProvider.loadMessagesAtTop)
    }
    
    /// Load messages at the bottom. This happens asynchronously.
    ///
    /// Not every call leads to new messages as we don't start a new request for a while after a previous call.
    ///
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    @discardableResult func loadMessagesAtBottom() -> Promise<Void> {
        DDLogVerbose("Trying to load more messages at bottom...")
        return loadMessagesIfAllowed(with: messageProvider.loadMessagesAtBottom)
    }
    
    /// Load messages around `date`
    ///
    /// This might replace already loaded messages.
    ///
    /// - Parameter date: Date to load messages around
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    func loadMessages(around date: Date) -> Promise<Void> {
        DDLogVerbose("Trying to load more messages around \(date)...")
        return loadMessagesIfAllowed {
            self.messageProvider.loadMessages(around: date)
        }
    }
        
    /// Load newest messages (at the bottom)
    ///
    /// This also succeeds during setup. This might replace all already loaded messages. Use this to scroll all the way to the bottom.
    ///
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    func loadNewestMessages() -> Promise<Void> {
        DDLogVerbose("Load newest messages...")
        return loadMessages(with: messageProvider.loadNewestMessages, cancellable: false)
    }
    
    /// Load oldest messages (at the top)
    ///
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    func loadOldestMessages() -> Promise<Void> {
        DDLogVerbose("Load oldest messages...")
        return loadMessagesIfAllowed(with: messageProvider.loadOldestMessages, cancellable: false)
    }

    // MARK: - Private load helper
    
    /// Execute `loadRequest` if no-one is running at this point
    ///
    /// - Parameter loadRequest: Load request that might be executed
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    private func loadMessagesIfAllowed(
        with loadRequest: @escaping () -> Guarantee<NSManagedObjectID?>,
        cancellable: Bool = true
    )
        -> Promise<Void> {
        guard initialSetupCompleted, !isLoadingNewMessages || fetchRequestSnapshotApplyStore == nil else {
            DDLogVerbose("Skip loading...")
            return Promise { $0.reject(DataSourceError.cancelled) }
        }
        
        DDLogVerbose("Load more messages...")
        
        return loadMessages(with: loadRequest, cancellable: cancellable)
    }
    
    /// Execute load request
    ///
    /// - Parameter loadRequest: Load request to execute
    /// - Returns: See comment at the top of the section about when exactly this promise is resolved. Approximate tl;dr fulfilled if this exact fetchRequest had its snapshot applied; cancelled otherwise
    private func loadMessages(
        with loadRequest: @escaping () -> Guarantee<NSManagedObjectID?>,
        cancellable: Bool
    ) -> Promise<Void> {
        firstly {
            self.isLoadingNewMessages = true
            return loadRequest()
        }.then { (objectID: NSManagedObjectID?) -> Promise<Void> in
            defer { self.isLoadingNewMessages = false }
            
            guard let objectID = objectID, self.initialSetupCompleted else {
                DDLogVerbose("No new messages loaded, fulfill immediately")
                return Promise { $0.fulfill_() }
            }
            
            if let seal = self.fetchRequestSnapshotApplyStore?.seal {
                if cancellable {
                    DDLogVerbose("Cancelled loadMessages request bc. another request is still pending")
                    return Promise { $0.reject(DataSourceError.cancelled) }
                }
                else {
                    DDLogVerbose("Cancelling running loadMessages request bc. it has been overwritten by a newer one.")
                    seal.reject(DataSourceError.cancelled)
                }
            }
            return Promise { seal in
                self.fetchRequestSnapshotApplyStore = (objectID, seal)
            }
        }
    }
    
    func removeUnreadMessageLine() {
        snapshotProvider.removeUnreadMessageLine()
    }
    
    /// Reconfigures all existing cells
    func reconfigure() {
        dataSourceApplyQueue.async {
            var current = self.snapshot()
            
            current.reconfigureItems(current.itemIdentifiers)
            
            self.apply(current)
        }
    }
    
    /// Reconfigures the cells for all items in `items` if they exist
    /// - Parameter items:
    func reconfigure(_ items: [NSManagedObjectID]) {
        dataSourceApplyQueue.async {
            var current = self.snapshot()
            
            var cells = [CellType]()
            
            for item in items {
                if current.itemIdentifiers.contains(where: { $0 == .message(objectID: item) }) {
                    cells.append(.message(objectID: item))
                }
            }
            
            current.reconfigureItems(cells)
            
            self.apply(current)
        }
    }
}

// MARK: - ChatViewSnapshotProviderDelegate

extension ChatViewDataSource: ChatViewSnapshotProviderDelegate { }
