//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import MBProgressHUD
import ThreemaMacros
import UIKit

/// Get updates for `ChatSearchController` interactions
protocol ChatSearchControllerDelegate: AnyObject {
    
    /// Selected the message with the passed managed object ID
    ///
    /// If another message is already selected this should have its selection removed. If the item is already selected
    /// it should stay selected.
    ///
    /// - Parameter messageObjectID: Managed object ID of message to select
    func chatSearchController(
        select messageObjectID: NSManagedObjectID,
        highlighting searchText: String,
        in filteredSearchResults: [NSManagedObjectID]
    )
    
    /// Remove selection of the message with the passed managed object ID
    /// - Parameter messageObjectID: Managed object ID of message to remove selection from
    func chatSearchController(removeSelectionFrom messageObjectID: NSManagedObjectID)
    
    /// Show toolbar with the passed toolbar button items
    /// - Parameters:
    ///   - barButtonItems: Toolbar items to show
    ///   - animated: Animate showing?
    func chatSearchController(showToolbarWith barButtonItems: [UIBarButtonItem], animated: Bool)
    
    /// Update toolbar with new passed items
    /// - Parameter barButtonItems: Toolbar items to show
    func chatSearchController(updateToolbarWith barButtonItems: [UIBarButtonItem])
    
    /// Hide toolbar
    /// - Parameter animated: Animate hiding?
    func chatSearchControllerHideToolbar(animated: Bool)
    
    /// Hide the search interface
    func chatSearchControllerHideSearch()
}

/// Controller to manage search in a chat
///
/// Use the `searchBar` to show a search bar in the interface, activate the search  with `activateSearch()` and then use
/// the delegate methods to observe any updates.
///
/// - Note: You need the correct implementation of `definePresentationContext` for the search bar to work. See inline
///         documentation for details.
///
/// ## `definePresentationContext` workaround
///
/// Last update: iOS 16.0b8
///
/// ### Problem
///
/// If you have view controller **A** with a `UISearchBar` managed by a `UISearchViewController` that shows view
/// controller **B** also with a manage search bar on the same `UINavigationBar` it will work if you use
/// `searchController` on the navigation item in both views, otherwise not. The search bar cannot become the first
/// responder in **B**.
///
/// ### Solution
///
/// You need to set `definePresentationContext` to `true` in `viewWillAppear` and to `false` in `viewWillDisappear` in
/// **A** _and_ **B**.
///
/// ### Source
///
/// - https://stackoverflow.com/a/42148381
///
final class ChatSearchController: NSObject {
    
    // MARK: - Public properties
    
    /// Search bar for this controller
    ///
    /// Add this to the view hierarchy where the search bar should appear
    var searchBar: UIView {
        searchController.searchBar
    }
    
    // MARK: - Private properties
    
    private let conversation: ConversationEntity
    private weak var delegate: ChatSearchControllerDelegate?
    private let context: NSManagedObjectContext
    private let entityFetcher: EntityFetcher
    private let entityManager: EntityManager
    
    private let searchQueue = DispatchQueue(label: "ch.threema.chatSearchQueue")
    private var cancellables = Set<AnyCancellable>()
    @Published var searchText: String?
    
    private var starredToken: UISearchToken {
        let token = UISearchToken(icon: UIImage(systemName: "star.fill"), text: #localize("search_token_starred_title"))
        return token
    }
    
    private lazy var chatSearchResultsViewController = ChatSearchResultsViewController(
        delegate: self,
        entityManager: entityManager
    )
    
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: chatSearchResultsViewController)
        
        // Otherwise the search bar disappears if we add it the `titleView` of the navigation item
        searchController.hidesNavigationBarDuringPresentation = false
        // We have a custom interaction flow managed via the search bar delegate
        searchController.automaticallyShowsSearchResultsController = false
        
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        
        searchController.searchBar.searchTextField.allowsDeletingTokens = true
        searchController.obscuresBackgroundDuringPresentation = false
        
        return searchController
    }()
    
    private var filteredMessageObjectIDs = [NSManagedObjectID]() {
        didSet {
            chatSearchResultsViewController.filteredMessageObjectIDs = filteredMessageObjectIDs
        }
    }

    private var currentResultOffset: Int? {
        didSet {
            // Ask delegate to select new item
            
            guard let currentResultOffset else {
                // Remove previous selection if nothing is selected anymore
                if let oldValue,
                   oldValue < filteredMessageObjectIDs.count {
                    let messageObjectID = filteredMessageObjectIDs[oldValue]
                    delegate?.chatSearchController(removeSelectionFrom: messageObjectID)
                }
                return
            }
            
            let messageObjectID = filteredMessageObjectIDs[currentResultOffset]
            delegate?.chatSearchController(
                select: messageObjectID,
                highlighting: searchText!,
                in: filteredMessageObjectIDs
            )
        }
    }
    
    private var currentToolbarButtonItems: [UIBarButtonItem] {
        let nextResultBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.up"),
            style: .plain,
            target: self,
            action: #selector(nextResultBarButtonItemTapped)
        )
        
        let previousResultBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(previousResultBarButtonItemTapped)
        )
        
        let localizedMatchesText: String
        let hasMatches: Bool
        
        // Determinate who is active and what text is shown
        if let currentResultOffset {
            // Disable previous button if there are now previous items
            if currentResultOffset == 0 {
                previousResultBarButtonItem.isEnabled = false
            }
            // Disable next button if there are now next items
            else if currentResultOffset == (filteredMessageObjectIDs.count - 1) {
                nextResultBarButtonItem.isEnabled = false
            }
            
            localizedMatchesText = String.localizedStringWithFormat(
                #localize("chat_search_matches"),
                currentResultOffset + 1,
                filteredMessageObjectIDs.count
            )
            hasMatches = true
        }
        else {
            // No matches. Disable everything.
            nextResultBarButtonItem.isEnabled = false
            previousResultBarButtonItem.isEnabled = false
            localizedMatchesText = #localize("chat_search_no_matches")
            hasMatches = false
        }
        
        let searchInfoBarButtonItem = UIBarButtonItem(
            title: localizedMatchesText,
            style: .plain,
            target: self,
            action: #selector(searchInfoBarButtonItemTapped)
        )
        searchInfoBarButtonItem.isEnabled = hasMatches
        
        return [
            nextResultBarButtonItem,
            previousResultBarButtonItem,
            .flexibleSpace(),
            searchInfoBarButtonItem,
        ]
    }
    
    // MARK: - Lifecycle
    
    /// Create a new chat search controller
    /// - Parameter conversation: ConversationEntity to search messages in
    /// - Parameter delegate: Delegate that gets updated during the use of the search controller
    /// - Parameter entityManager: Entity manager used for search and to fetch results messages
    init(
        for conversation: ConversationEntity,
        delegate: ChatSearchControllerDelegate,
        entityManager: EntityManager = EntityManager()
    ) {
        self.conversation = conversation
        self.delegate = delegate
        self.entityManager = entityManager
        
        // We setup a private background context to allow offloading the majority of the search results fetching
        // onto a background thread.
        let context: TMAManagedObjectContext = DatabaseContext
            .directBackgroundContext(withPersistentCoordinator: DatabaseManager.db().persistentStoreCoordinator)
        
        self.context = context

        self.entityFetcher = EntityFetcher(
            context,
            myIdentityStore: BusinessInjector.ui.myIdentityStore
        )
        
        super.init()
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("No available")
    }
    
    deinit {
        DatabaseContext.removeDirectBackgroundContext(with: context)
    }
    
    // MARK: - Public functions
    
    /// Activate the search bar text field
    ///
    /// Call this after you added the `searchBar` to your view hierarchy and ensure the it can become first responder.
    func activateSearch() {
        searchController.searchBar.becomeFirstResponder()
        setupSearchResultsFetching()
    }
    
    /// Adds the starred message token to the `searchBar` which is used to filter the messages
    func addStarredToken() {
        searchController.searchBar.searchTextField.insertToken(starredToken, at: 0)
        setupSearchResultsFetching()
    }
    
    // MARK: - Private functions
    
    private func setupSearchResultsFetching() {
        
        cancellables.forEach { $0.cancel() }
        
        $searchText
            .debounce(for: ChatViewConfiguration.SearchResultsFetching.debounceInputSeconds, scheduler: RunLoop.main)
            .receive(on: searchQueue)
            .sink { [weak self] searchText in
                guard let self else {
                    return
                }
                
                guard let searchText else {
                    return
                }
                
                DispatchQueue.main.async {
                    let hud = MBProgressHUD.showAdded(to: self.chatSearchResultsViewController.view, animated: true)
                    hud.mode = .indeterminate
                    hud.label.text = #localize("chat_search_searching")
                    hud.removeFromSuperViewOnHide = true
                }
                var hasTokens = false
                DispatchQueue.main.sync {
                    hasTokens = !self.searchController.searchBar.searchTextField.tokens.isEmpty
                }
                
                // TODO: (IOS-2904) Only fetch object IDs
                // TODO: (IOS-4469) Simplify
                context.performAndWait {
                    if !hasTokens {
                        self.filteredMessageObjectIDs = self.entityFetcher.messagesContaining(
                            searchText,
                            in: self.conversation,
                            filterPredicate: nil,
                            fetchLimit: ChatViewConfiguration.SearchResultsFetching.maxItemsToFetch
                        )
                        .compactMap { $0 as? BaseMessageEntity }
                        .map(\.objectID)
                    }
                    else {
                        self.filteredMessageObjectIDs = self.entityFetcher.starredMessagesContaining(
                            searchText,
                            in: self.conversation,
                            filterPredicate: nil,
                            fetchLimit: ChatViewConfiguration.SearchResultsFetching.maxItemsToFetch
                        )
                        .compactMap { $0 as? BaseMessageEntity }
                        .map(\.objectID)
                    }
                }
                
                DispatchQueue.main.async {
                    MBProgressHUD.hide(for: self.chatSearchResultsViewController.view, animated: true)
                }
                
            }.store(in: &cancellables)
    }
    
    private func showSearchResultsController() {
        delegate?.chatSearchControllerHideToolbar(animated: true)
        searchController.showsSearchResultsController = true
    }
    
    private func hideSearchResultsController(showToolbar: Bool = true) {
        searchController.showsSearchResultsController = false
        if showToolbar {
            // We dismiss the searchResultsController to make the ChatView accessible for VoiceOver users.
            searchController.searchResultsController?.dismiss(animated: false)
            delegate?.chatSearchController(showToolbarWith: currentToolbarButtonItems, animated: true)
        }
    }
    
    // MARK: - Actions
    
    @objc private func previousResultBarButtonItemTapped() {
        guard let currentResultOffset else {
            DDLogVerbose("Failed to jump to next search result. No search result selected.")
            return
        }
        
        self.currentResultOffset = max(currentResultOffset - 1, 0)
        
        delegate?.chatSearchController(updateToolbarWith: currentToolbarButtonItems)
    }
    
    @objc private func nextResultBarButtonItemTapped() {
        guard let currentResultOffset else {
            DDLogVerbose("Failed to jump to previous search result. No search result selected.")
            return
        }
        
        self.currentResultOffset = min(currentResultOffset + 1, filteredMessageObjectIDs.count - 1)
        
        delegate?.chatSearchController(updateToolbarWith: currentToolbarButtonItems)
    }
    
    @objc private func searchInfoBarButtonItemTapped() {
        // We call this instead of `showSearchResultsController()` because this also presents the
        // SearchResultsController again, which might get removed in `hideSearchResultsController()`.
        searchController.searchBar.becomeFirstResponder()
    }
}

// MARK: - UISearchBarDelegate

extension ChatSearchController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateSearchResultsVisibility(with: searchText)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text else {
            hideSearchResultsController(showToolbar: false)
            return
        }
        
        updateSearchResultsVisibility(with: searchText)
    }
    
    private func updateSearchResultsVisibility(with searchText: String) {
        if searchText.isEmpty, searchController.searchBar.searchTextField.tokens.isEmpty {
            hideSearchResultsController(showToolbar: false)
        }
        else {
            showSearchResultsController()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchController.isActive = false
        currentResultOffset = nil
        filteredMessageObjectIDs = []
        delegate?.chatSearchControllerHideSearch()
    }
}

// MARK: - UISearchResultsUpdating

extension ChatSearchController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        
        // Cleanup search term
        let strippedAndLowercasedSearchText = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        
        self.searchText = strippedAndLowercasedSearchText
    }
}

// MARK: - ChatSearchResultsViewControllerDelegate

extension ChatSearchController: ChatSearchResultsViewControllerDelegate {
    func chatSearchResults(didSelect messageObjectID: NSManagedObjectID) {
        currentResultOffset = filteredMessageObjectIDs.firstIndex(of: messageObjectID)
        
        hideSearchResultsController(showToolbar: true)
        searchController.searchBar.resignFirstResponder()
    }
}
