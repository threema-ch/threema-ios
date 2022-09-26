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
import PromiseKit

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
    func didApplySnapshot()
}

/// Manage the table view data for a chat view
///
/// The data sources uses a `MessageProvider` to load messages and `ChatViewCellProvider` for cell registration, loading and
/// configuration.
class ChatViewDataSource: UITableViewDiffableDataSource<String, NSManagedObjectID> {
    
    /// Last index path of the data
    var bottomIndexPath: IndexPath? {
        let snapshot = snapshot()
        let sectionIndex = snapshot.numberOfSections - 1
        
        guard sectionIndex >= 0 else {
            return nil
        }
        
        let lastSectionIdentifier = snapshot.sectionIdentifiers[sectionIndex]
        let lastItemInSectionIndex = snapshot.numberOfItems(inSection: lastSectionIdentifier) - 1
        
        guard lastItemInSectionIndex >= 0 else {
            return nil
        }
        
        return IndexPath(item: lastItemInSectionIndex, section: sectionIndex)
    }
    
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
    
    /// Is the data source in the process of loading (more) messages?
    ///
    /// Only set after `initialSetupCompleted` is `true`
    private(set) var isLoadingNewMessages = false
    
    // MARK: - Private properties
    
    private let conversation: Conversation
    private weak var delegate: ChatViewDataSourceDelegate?
    
    private let entityManager: EntityManager
    private let messageProvider: MessageProvider
    
    private var bottomIdentifier: NSManagedObjectID? {
        guard let bottomIndexPath = bottomIndexPath else {
            return nil
        }
        
        return itemIdentifier(for: bottomIndexPath)
    }
        
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    /// Crate a new chat view data source
    /// - Parameters:
    ///   - conversation: Messages of this conversation will be provided by this data source
    ///   - tableView: Table view that will display the messages
    ///   - delegate: `ChatViewDataSourceDelegate` that is informed about certain changes
    ///   - chatViewTableViewCellDelegate: `ChatViewTableViewCellDelegate` that is informed about cell delegates
    ///   - entityManager: Entity manager used to fetch messages from the object store
    ///   - date: Date to load messages around. If `nil` newest messages are loaded.
    ///   - afterFirstSnapshotApply: Closure called only on first apply to data source snapshot (this will be called on the main queue)
    init(
        for conversation: Conversation,
        in tableView: UITableView,
        delegate: ChatViewDataSourceDelegate,
        chatViewTableViewCellDelegate: ChatViewTableViewCellDelegate,
        entityManager: EntityManager,
        loadAround date: Date?,
        afterFirstSnapshotApply: @escaping () -> Void
    ) {
        self.conversation = conversation
        self.delegate = delegate
        self.entityManager = entityManager
        
        // Workaround to fix circular `self` dependency during initialization
        // For the super class's initializer we need a `CellProvider` that needs to reference the message provider.
        // As `self` is not available before the super call we need to workaround this circular dependency.
        // Solved by steps 1 - 3 below:
        
        // 1. Create message provider stored in a local constant (needed) that can be referenced in the `CellProvider`
        let messageProvider = MessageProvider(
            for: conversation,
            around: date,
            entityManager: entityManager,
            initialFetchCompletion: afterFirstSnapshotApply
        )
        self.messageProvider = messageProvider
        
        // Ensure that cells will be available in our cell provider
        ChatViewCellProvider.registerCells(in: tableView)
        let chatViewCellProvider = ChatViewCellProvider(chatViewTableViewCellDelegate: chatViewTableViewCellDelegate)
        
        // 2. Setup class and use message provider in this call
        super.init(tableView: tableView) { tableView, indexPath, messageObjectID in
            // TODO: (IOS-2014) Is it a problem that we load the message by object id and not
            // by index path? We don't take advantage of batch fetching here, but it might never happen anyway.
            guard let message = messageProvider.message(for: messageObjectID) else {
                return nil
            }

            return chatViewCellProvider.cell(for: message, in: tableView, at: indexPath)
        }
        
        // Do our configuration
        configureDataSource()
        
        // 3. Load initial messages and observe changes
        loadInitialMessagesAndObserveChanges()
    }
        
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<String, NSManagedObjectID>.CellProvider
    ) {
        fatalError("Not supported")
    }
    
    // MARK: - Configure

    private func configureDataSource() {
        // TODO: (IOS-2014) Maybe add an empty snapshot to not crash if there was no snapshot so far
        
        defaultRowAnimation = .fade
    }
    
    private func loadInitialMessagesAndObserveChanges() {
        messageProvider.$currentMessages
            .sink { [weak self] messages in
                guard let messages = messages else {
                    return
                }
                                                
                DDLogVerbose("Will apply new snapshot")
                DispatchQueue.main.async {
                    self?.delegate?.willApplySnapshot(
                        currentDoesIncludeNewestMessage: messages.previouslyNewestMessagesLoaded
                    )
                }
                
                // Setting animatingDifferences to false before `self?.initialSetupCompleted` completed lead to a crash when applying the data source, we therefore use the default value `true` for now
                self?.apply(messages.snapshot) {
                    // This is on the main queue
                    DDLogVerbose("Did apply new snapshot")
                    self?.delegate?.didApplySnapshot()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Override UITableViewDataSource conformance
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard snapshot().sectionIdentifiers.count > section else {
            return nil
        }
        
        return snapshot().sectionIdentifiers[section]
    }
    
    // MARK: - Public functions
    
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
    /// - Returns: Guarantee that is fulfilled when loading completes
    @discardableResult func loadMessagesAtTop() -> Guarantee<Void> {
        DDLogVerbose("Trying to load more messages at top...")
        return loadMessagesIfAllowed(with: messageProvider.loadMessagesAtTop)
    }
    
    /// Load messages at the bottom. This happens asynchronously.
    ///
    /// Not every call leads to new messages as we don't start a new request for a while after a previous call.
    ///
    /// - Returns: Guarantee that is fulfilled when loading completes
    @discardableResult func loadMessagesAtBottom() -> Guarantee<Void> {
        DDLogVerbose("Trying to load more messages at bottom...")
        return loadMessagesIfAllowed(with: messageProvider.loadMessagesAtBottom)
    }
    
    /// Load messages around `date`
    ///
    /// This might replace already loaded messages.
    ///
    /// - Parameter date: Date to load messages around
    /// - Returns: Guarantee that is fulfilled when loading completes
    func loadMessages(around date: Date) -> Guarantee<Void> {
        DDLogVerbose("Trying to load more messages around \(date)...")
        return loadMessagesIfAllowed {
            self.messageProvider.loadMessages(around: date)
        }
    }
        
    /// Load newest messages (at the bottom)
    ///
    /// This also succeeds during setup. This might replace all already loaded messages. Use this to scroll all the way to the bottom.
    ///
    /// - Returns: Guarantee that is fulfilled when loading completes
    func loadNewestMessages() -> Guarantee<Void> {
        DDLogVerbose("Load newest messages...")
        return loadMessages(with: messageProvider.loadNewestMessages)
    }
    
    // MARK: - Private load helper
    
    /// Execute `loadRequest` if no-one is running at this point
    ///
    /// - Parameter loadRequest: Load request that might be executed
    /// - Returns: Guarantee that is fulfilled when loading completes
    private func loadMessagesIfAllowed(with loadRequest: @escaping () -> Guarantee<Void>) -> Guarantee<Void> {
        guard initialSetupCompleted, !isLoadingNewMessages else {
            DDLogVerbose("Skip loading...")
            return Guarantee()
        }
        
        DDLogVerbose("Load more messages...")
        
        return loadMessages(with: loadRequest)
    }
    
    /// Execute load request
    ///
    /// - Parameter loadRequest: Load request to execute
    /// - Returns: Guarantee that is fulfilled when loading completes
    private func loadMessages(with loadRequest: @escaping () -> Guarantee<Void>) -> Guarantee<Void> {
        firstly {
            isLoadingNewMessages = true
            return loadRequest()
        }.then {
            self.isLoadingNewMessages = false
            return Guarantee()
        }
    }
}
