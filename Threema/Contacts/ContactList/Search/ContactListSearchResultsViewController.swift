import Foundation
import ThreemaFramework
import ThreemaMacros

protocol ContactListSearchResultsDelegate: AnyObject {
    func present(for destination: ContactListCoordinator.InternalDestination)
    func handleDirectoryContact(_ directoryContact: CompanyDirectoryContact) async
    func isDirectoryContactAvailable(for id: String) -> Bool
}

final class ContactListSearchResultsViewController: ThemedViewController {
    
    // MARK: - Private properties
    
    private weak var delegate: ContactListSearchResultsDelegate?
    private let dataSourceFactory: (UITableView) -> ContactListSearchDataSource
    private let onDirectoryContactAdded: () -> Void
    
    private lazy var dataSource = dataSourceFactory(tableView)
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
    
    // MARK: - Lifecycle

    init(
        delegate: ContactListSearchResultsDelegate?,
        dataSourceFactory: @escaping (UITableView) -> ContactListSearchDataSource,
        onDirectoryContactAdded: @escaping () -> Void
    ) {
        self.delegate = delegate
        self.dataSourceFactory = dataSourceFactory
        self.onDirectoryContactAdded = onDirectoryContactAdded
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
    }
    
    override func updateColors() {
        super.updateColors()

        tableView.backgroundColor = Colors.plainBackgroundTableView
    }
    
    // MARK: - Public functions
    
    public func setSearchController(_ controller: UISearchController) {
        searchController = controller
        tableView.dataSource = dataSource
    }
    
    // MARK: - Configuration
        
    private func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDelegate

extension ContactListSearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch identifier {
        case let .token(token):
            guard let searchController else {
                return
            }
            
            let currentTokenCount = searchController.searchBar.searchTextField.tokens.count
            searchController.searchBar.searchTextField.insertToken(token.searchToken, at: currentTokenCount)
            searchController.searchBar.text = " "
            
        case let .contact(contactID):
            delegate?.present(for: .contact(objectID: contactID))

        case let .group(conversationID):
            delegate?.present(for: .groupFromID(conversationID))

        case let .distributionList(distributionListID):
            delegate?.present(for: .distributionList(objectID: distributionListID))

        case let .directoryContact(directoryContact):
            Task { [weak self] in
                await self?.delegate?.handleDirectoryContact(directoryContact)
            }

        case .progress:
            return
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let identifier = dataSource.itemIdentifier(for: indexPath),
              case let .directoryContact(directoryContact) = identifier else {
            return nil
        }
        
        guard delegate?.isDirectoryContactAvailable(
            for: directoryContact.id
        ) == false else {
            return nil
        }
        
        let action = UIContextualAction(
            style: .normal,
            title: #localize("contact_list_directory_add")
        ) { [weak self] _, _, handler in
            Task {
                await self?.delegate?.handleDirectoryContact(directoryContact)
                
                await MainActor.run {
                    handler(true)
                }
            }
        }
        
        action.image = UIImage(systemName: "person.fill.badge.plus")
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        guard let section = contactListSearchSection(for: section) else {
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
        guard let section = contactListSearchSection(for: section) else {
            return nil
        }
        
        guard let localizedSectionTitle = section.localizedTitle else {
            return nil
        }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: SearchContentConfigurations.contentConfigurationSectionHeaderIdentifier
        )
        headerView?.contentConfiguration = SearchContentConfigurations.contentConfigurationForSectionHeader(
            with: localizedSectionTitle
        )
        
        return headerView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let height = scrollView.frame.size.height
        let contentYOffset = scrollView.contentOffset.y
        let scrollViewContentHeight = scrollView.contentSize.height
        let distanceFromBottom = scrollViewContentHeight - contentYOffset - 200
        
        // We only load when we are close but not at the bottom
        if distanceFromBottom < height {
            dataSource.loadMoreDirectoryContacts()
        }
    }
    
    private func contactListSearchSection(for sectionIndex: Int) -> ContactListSearch.Section? {
        let sectionIdentifiers = dataSource.snapshot().sectionIdentifiers
        
        // This should always be true, but just to be safe
        guard sectionIndex >= 0, sectionIndex < sectionIdentifiers.count else {
            return nil
        }
        
        return sectionIdentifiers[sectionIndex]
    }
}

// MARK: - UISearchControllerDelegate, UISearchResultsUpdating

extension ContactListSearchResultsViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        // This is also called when the search appears/disappears, so we use it to directly show and hide the results
        // controller and scope buttons
        searchController.showsSearchResultsController = searchController.isActive
        searchController.searchBar.showsScopeBar = searchController.isActive
        
        // Update the results depending on current values
        let searchText = searchController.searchBar.text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let selectedTokens = searchController.searchBar.searchTextField.tokens
            .compactMap { $0.representedObject as? ContactListSearchToken }
        
        // We remove all added directory filter tokens, when the main directory token is not in the current tokens
        if !selectedTokens.contains(.directoryContacts) {
            let filtered = selectedTokens.filter { token in
                if case .directoryFilterToken = token {
                    true
                }
                else {
                    false
                }
            }
            
            if !filtered.isEmpty {
                searchController.searchBar.searchTextField.tokens.removeAll { token in
                    guard let searchToken = token.representedObject as? ContactListSearchToken else {
                        return false
                    }
                    return filtered.contains(searchToken)
                }
                
                // We return here to remove concurrency issues in the data source. The `removeAll` above triggers this
                // function again anyways
                return
            }
        }
        
        // Update results via data source
        Task.detached(priority: .background) { [weak self] in
            guard let self else {
                return
            }
            
            await dataSource.updateSearchResults(for: searchText, with: selectedTokens)
        }
    }
}
