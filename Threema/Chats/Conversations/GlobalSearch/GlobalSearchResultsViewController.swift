//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import SwiftUI
import ThreemaFramework

final class GlobalSearchResultsViewController: ThemedViewController {
    
    // MARK: - Private properties
        
    private let entityManager: EntityManager
    
    private weak var searchController: UISearchController?
        
    // MARK: - Views
    
    /// The table view set as first sub view
    private lazy var tableView: UITableView = {
        // Use `.grouped` for best design style
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .onDrag

        tableView.backgroundColor = Colors.plainBackgroundTableView
        
        return tableView
    }()
    
    // This needs to be public since they are set on the `ConversationsViewController`
    public lazy var searchScopeButtonTitles: [String] = [
        GlobalSearchConversationScope.all.title,
        GlobalSearchConversationScope.oneToOne.title,
        GlobalSearchConversationScope.groups.title,
        GlobalSearchConversationScope.archived.title,
    ]
       
    private lazy var dataSource = GlobalSearchDataSource(tableview: tableView, entityManager: entityManager)
    
    // MARK: - Lifecycle
    
    /// Create a new chat search results controller
    /// - Parameter entityManager: Entity manager used to fetch messages shown in search results
    init(
        entityManager: EntityManager
    ) {
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        addObservers()
    }
    
    // MARK: - Public functions
    
    public func setSearchController(_ controller: UISearchController) {
        searchController = controller
    }
    
    // MARK: - Configuration
        
    private func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = dataSource
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func addObservers() {
        // Add observer for theme changes as `refresh()` in the parent is only called if the view controller is inside a
        // `ThemedNavigationController`, which is generally no the case for this view controller
        if navigationController == nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refresh),
                name: Notification.Name(kNotificationColorThemeChanged),
                object: nil
            )
        }
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        tableView.backgroundColor = Colors.plainBackgroundTableView
        
        for cell in tableView.visibleCells {
            if let globalSearchResultsTableViewCell = cell as? GlobalSearchResultsTableViewCell {
                globalSearchResultsTableViewCell.updateColors()
            }
            else if let conversationTableViewCell = cell as? ConversationTableViewCell {
                conversationTableViewCell.updateColors()
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension GlobalSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        guard let section = globalSearchSection(for: section) else {
            return 0
        }
        
        // To not end up with a default space for sections with no header we set the height to 0 for them. For the rest
        // we just let the system calculate the correct height
        if section.localizedTitle == nil {
            return 0
        }
        else {
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = globalSearchSection(for: section) else {
            return nil
        }
        
        guard let localizedSectionTitle = section.localizedTitle else {
            return nil
        }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: GlobalSearchContentConfigurations.contentConfigurationSectionHeaderIdentifier
        )
        headerView?.contentConfiguration = GlobalSearchContentConfigurations.contentConfigurationForSectionHeader(
            with: localizedSectionTitle
        )
        
        return headerView
    }
    
    private func globalSearchSection(for sectionIndex: Int) -> GlobalSearch.Section? {
        let sectionIdentifiers = dataSource.snapshot().sectionIdentifiers
        
        // This should always be true, but just to be safe
        guard sectionIndex >= 0, sectionIndex < sectionIdentifiers.count else {
            return nil
        }
        
        return sectionIdentifiers[sectionIndex]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if case let .messageToken(token) = dataSource.itemIdentifier(for: indexPath) {
            guard let searchController else {
                return
            }
            
            let currentTokenCount = searchController.searchBar.searchTextField.tokens.count
            searchController.searchBar.searchTextField.insertToken(token.searchToken, at: currentTokenCount)
            searchController.searchBar.text = ""
        }
        
        if case let .conversation(conversationID) = dataSource.itemIdentifier(for: indexPath) {
            entityManager.performAndWait {
                guard let conversation = self.entityManager.entityFetcher
                    .existingObject(with: conversationID) as? Conversation else {
                    return
                }
                
                let info: Dictionary = [kKeyConversation: conversation]
                NotificationCenter.default.post(
                    name: NSNotification.Name(kNotificationShowConversation),
                    object: nil,
                    userInfo: info
                )
            }
        }
        
        if case let .message(messageID) = dataSource.itemIdentifier(for: indexPath) {
            entityManager.performAndWait {
                guard let message = self.entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessage,
                      let conversation = message.conversation else {
                    return
                }
                let info: [AnyHashable: Any] = [kKeyConversation: conversation, kKeyMessage: message]
                NotificationCenter.default.post(
                    name: NSNotification.Name(kNotificationShowConversation),
                    object: nil,
                    userInfo: info
                )
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let height = scrollView.frame.size.height
        let contentYOffset = scrollView.contentOffset.y
        let scrollViewContentHeight = scrollView.contentSize.height
        let distanceFromBottom = scrollViewContentHeight - contentYOffset - 200
        
        // We only load when we are close but not at the bottom
        if distanceFromBottom < height {
            dataSource.loadMoreMessages()
        }
    }
}

// MARK: - UISearchControllerDelegate, UISearchResultsUpdating

extension GlobalSearchResultsViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        
        // This is also called when the search appears/disappears, so we use it to directly show and hide the results
        // controller and scope buttons
        searchController.showsSearchResultsController = searchController.isActive
        searchController.searchBar.showsScopeBar = searchController.isActive
        
        // Update the results depending on current values
        let searchText = searchController.searchBar.text ?? ""
        let selectedTokens = searchController.searchBar.searchTextField.tokens
            .compactMap { $0.representedObject as? GlobalSearchMessageToken }
        let scope = GlobalSearchConversationScope(
            rawValue: searchController.searchBar.selectedScopeButtonIndex
        ) ?? .all
        
        Task.detached(priority: .background) { [self] in
            await dataSource.updateSearchResults(for: searchText, with: selectedTokens, in: scope)
        }
    }
}
