import Combine

final class ContactListSearchResultDataSource<CellProvider: ContactListCellProviderProtocol>:
    UITableViewDiffableDataSource<ContactListSearchResultDataSource.Section, NSManagedObjectID>
    where CellProvider.BusinessEntity == Contact {
    
    // MARK: - Type
    
    enum Section {
        case contacts
    }
    
    // MARK: - Private Properties

    private weak var tableView: UITableView?
    private weak var businessInjector: BusinessInjector?
    private var currentSearchText = ""
    
    // MARK: - Lifecycle

    init(
        tableView: UITableView,
        businessInjector: BusinessInjector,
        cellProvider: CellProvider
    ) {
        self.tableView = tableView
        self.businessInjector = businessInjector
        
        super.init(tableView: tableView) { tableView, indexPath, objectID in
            let contactEntity = businessInjector.entityManager.performAndWait {
                businessInjector.entityManager.entityFetcher.existingObject(with: objectID) as? ContactEntity
            }
            guard let contactEntity else {
                // TODO: (IOS-4536) Error
                fatalError()
            }
            
            return cellProvider.dequeueCell(for: indexPath, and: Contact(contactEntity: contactEntity), in: tableView)
        }
        
        registerCells(cellProvider)
        defaultRowAnimation = .fade
    }
    
    private func registerCells(_ cellProvider: CellProvider) {
        tableView.map { cellProvider.registerCells(in: $0) }
        tableView?.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: SearchContentConfigurations.contentConfigurationSectionHeaderIdentifier
        )
    }
    
    // MARK: - Contact loading

    private func loadContacts(snapshot: inout NSDiffableDataSourceSnapshot<
        Section,
        NSManagedObjectID
    >) {
        guard let entityFetcher = businessInjector?.entityManager.entityFetcher else {
            return
        }
        
        let contactsIDs = entityFetcher.matchingContactsForContactListSearch(
            containing: currentSearchText,
            hideStaleContacts: UserSettings.shared().hideStaleContacts
        )
        
        guard !contactsIDs.isEmpty else {
            return
        }
        
        if !snapshot.sectionIdentifiers.contains(.contacts) {
            snapshot.appendSections([.contacts])
        }
        snapshot.appendItems(contactsIDs, toSection: .contacts)
    }
    
    func updateSearchResults(for text: String) async {
        var snapshot = NSDiffableDataSourceSnapshot<
            Section,
            NSManagedObjectID
        >()
        let searchTextDidChange = currentSearchText != text
        if searchTextDidChange {
            currentSearchText = text
        }
        
        loadContacts(snapshot: &snapshot)
        
        Task { @MainActor in
            apply(snapshot)
        }
    }
    
    func updateSearchResults(for text: String, completion: (() -> Void)? = nil) async {
        var snapshot = NSDiffableDataSourceSnapshot<
            Section,
            NSManagedObjectID
        >()
        let searchTextDidChange = currentSearchText != text
        if searchTextDidChange {
            currentSearchText = text
        }
        
        loadContacts(snapshot: &snapshot)
        
        Task { @MainActor in
            apply(snapshot, completion: completion)
        }
    }
}
