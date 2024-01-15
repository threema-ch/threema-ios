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
import UIKit

/// Updates on `ChatSearchResultsViewController` interactions
protocol ChatSearchResultsViewControllerDelegate: AnyObject {
    /// Called when a search result is selected
    /// - Parameter messageObjectID: Managed object ID of selected message
    func chatSearchResults(didSelect messageObjectID: NSManagedObjectID)
}

/// Show results of a chat search
///
/// All messages of the managed object IDs assigned to `filteredMessageObjectIDs` are shown.
final class ChatSearchResultsViewController: ThemedViewController {
    
    /// Managed object IDs of messages to show in results table view
    ///
    /// This should always be set from the same queue.
    var filteredMessageObjectIDs = [NSManagedObjectID]() {
        didSet {
            searchResultsApplyQueue.async {
                var snapshot = NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>()
                snapshot.appendSections([.main])
                snapshot.appendItems(self.filteredMessageObjectIDs)
                
                self.dataSource.apply(snapshot)
            }
        }
    }
    
    // MARK: - Private properties
    
    private enum Section: Hashable {
        case main
    }
    
    private weak var delegate: ChatSearchResultsViewControllerDelegate?
    private let entityManager: EntityManager
    
    private let searchResultsApplyQueue = DispatchQueue(
        label: "ch.threema.chatView.searchResultsApplyQueue",
        qos: .userInitiated,
        target: DispatchQueue.global()
    )
    
    /// The table view set as root view
    private lazy var tableView: UITableView = {
        // .grouped so the footer appears after the last search result
        // instead of floating above the results
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return tableView
    }()
    
    private lazy var dataSource: TableViewDiffableSimpleHeaderAndFooterDataSource<Section, NSManagedObjectID> = {
        let dataSource = TableViewDiffableSimpleHeaderAndFooterDataSource<
            Section,
            NSManagedObjectID
        >(tableView: tableView) { [weak self] tableView, indexPath, messageObjectID in
            
            let searchResultsCell: ChatSearchResultsTableViewCell = tableView.dequeueCell(for: indexPath)
            
            var baseMessage: BaseMessage?
            self?.entityManager.performBlockAndWait {
                baseMessage = self?.entityManager.entityFetcher.existingObject(with: messageObjectID) as? BaseMessage
                
                searchResultsCell.message = baseMessage
            }
            
            guard let baseMessage else {
                DDLogWarn(
                    "Unable to fetch message (\(messageObjectID.uriRepresentation().absoluteString)) for search result"
                )
                return nil
            }
            
            return searchResultsCell
            
        } headerProvider: { _, _ in
            // We don't actually need a header, but specifying a footer triggers an
            // empty header to be shown.
            //
            // Solution: return a dummy value so we can set the height to 0 in
            // UITableViewDelegate. An empty space or nil doesn't work, these cause
            // an empty header to be shown even if we set the height to 0.
            " "
        } footerProvider: { _, _ in
            BundleUtil.localizedString(forKey: "chat_search_note")
        }
        
        dataSource.defaultRowAnimation = .top
        return dataSource
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new chat search results controller
    /// - Parameter delegate: Delegate that gets called when a result is selected
    /// - Parameter entityManager: Entity manager used to fetch messages shown in search results
    init(
        delegate: ChatSearchResultsViewControllerDelegate,
        entityManager: EntityManager
    ) {
        self.delegate = delegate
        self.entityManager = entityManager
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("No available")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // DON'T call super!
        view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        configureTableView()
    }
    
    // MARK: - Configuration
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = dataSource

        tableView.keyboardDismissMode = .onDrag
        tableView.registerCell(ChatSearchResultsTableViewCell.self)
    }
}

// MARK: - UITableViewDelegate

extension ChatSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Don't show the header (see headerProvider definition above)
        0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        
        guard let messageObjectID = dataSource.itemIdentifier(for: indexPath) else {
            // This should never really fail
            DDLogWarn("Unable to load message object ID of search result at: \(indexPath)")
            return
        }
        
        delegate?.chatSearchResults(didSelect: messageObjectID)
    }
}
