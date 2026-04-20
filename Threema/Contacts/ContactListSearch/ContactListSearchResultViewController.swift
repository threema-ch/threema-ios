import ThreemaFramework
import ThreemaMacros

final class ContactListSearchResultViewController<CellProvider: ContactListCellProviderProtocol>:
    ThemedViewController,
    UITableViewDelegate,
    UISearchResultsUpdating
    where CellProvider.BusinessEntity == Contact {

    // MARK: - Public properties
    
    weak var delegate: ItemListSearchResultSelectionHandler?
    
    // MARK: - Private properties
        
    private let allowsMultiSelect: Bool
    private let provider: ContactListProvider
    private let cellProvider: CellProvider
    private let businessInjector: BusinessInjector
    private lazy var dataSource = ContactListSearchResultDataSource(
        tableView: tableView,
        businessInjector: businessInjector,
        cellProvider: cellProvider
    )
    
    // MARK: - Views
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .onDrag
        tableView.backgroundColor = .systemGroupedBackground
        return tableView
    }()
    
    // MARK: - Lifecycle

    init(
        businessInjector: BusinessInjector,
        cellProvider: CellProvider,
        provider: ContactListProvider,
        allowsMultiSelect: Bool
    ) {
        self.businessInjector = businessInjector
        self.cellProvider = cellProvider
        self.provider = provider
        self.allowsMultiSelect = allowsMultiSelect
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
    
    // MARK: - Configuration
        
    private func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.allowsMultipleSelection = true
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Public
    
    func updateSelection() {
        guard allowsMultiSelect else {
            return
        }
        
        let snapshot = dataSource.snapshot()
        for identifier in snapshot.itemIdentifiers {
            guard let indexPath = dataSource.indexPath(for: identifier),
                  let isSelected = delegate?.selectionFor(id: identifier)
            else {
                continue
            }
            
            if isSelected {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }
            else {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

    // MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !allowsMultiSelect {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        guard let id = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        delegate?.didSelect(id: id)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard allowsMultiSelect, let id = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        delegate?.didDeselect(id: id)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: SearchContentConfigurations.contentConfigurationSectionHeaderIdentifier
        )
        headerView?.contentConfiguration = SearchContentConfigurations.contentConfigurationForSectionHeader(
            with: #localize("contact_list_search_token_title_contacts")
        )
        
        return headerView
    }
    
    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        searchController.showsSearchResultsController = searchController.isActive
        
        let searchText = searchController.searchBar.text ?? ""
        
        Task.detached(priority: .background) { [self] in
            await dataSource.updateSearchResults(for: searchText) { [weak self] in
                Task { @MainActor in
                    self?.updateSelection()
                }
            }
        }
    }
}
