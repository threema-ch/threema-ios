import ThreemaFramework
import ThreemaMacros

final class SelectContactListTableViewController: ThemedTableViewController {
    
    // MARK: - Public properties
    
    weak var delegate: ItemSelectionHandler?

    // MARK: - Private Properties
    
    private let coordinator: ContactListCoordinator?
    private let cellProvider: ContactListSelectionCellProvider
    private let provider: ContactListProvider
    private let businessInjector: BusinessInjectorProtocol
    private lazy var dataSource = SelectContactListDataSource(
        coordinator: coordinator,
        provider: provider,
        cellProvider: cellProvider,
        entityManager: businessInjector.entityManager,
        in: tableView,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var unavailableDescription = {
        let stringSyncON = #localize("no_contacts_syncon")
        let stringSyncOFF = #localize("no_contacts_syncoff")
        return UserSettings.shared().syncContacts ? stringSyncON : stringSyncOFF
    }()

    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: #localize("contact_list_contact_unavailable_title"),
            systemImage: "person.2.fill",
            description: unavailableDescription,
            actions: []
        )
    }
    
    // MARK: - Lifecycle
    
    init(
        coordinator: ContactListCoordinator?,
        cellProvider: ContactListSelectionCellProvider,
        provider: ContactListProvider,
        businessInjector: BusinessInjectorProtocol,
        style: UITableView.Style = .plain
    ) {
        self.coordinator = coordinator
        self.cellProvider = cellProvider
        self.provider = provider
        self.businessInjector = businessInjector
        super.init(style: style)
        
        // This fixes the inset for the footer
        additionalSafeAreaInsets.bottom = 0
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.allowsMultipleSelection = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        dataSource.contentUnavailableConfiguration = unavailableConfiguration
    }
    
    // MARK: - TableView selection
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        delegate?.didSelect(id: id)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard
            let id = dataSource.itemIdentifier(for: indexPath)
        else {
            return
        }
        
        delegate?.didDeselect(id: id)
    }
    
    func updateSelection() {
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
}
