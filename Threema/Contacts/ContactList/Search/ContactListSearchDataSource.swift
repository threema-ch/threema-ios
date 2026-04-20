import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaEssentials
import ThreemaMacros

enum ContactListSearch: Hashable {
    enum Section: Hashable {
        case tokens
        case contacts
        case groups
        case distributionLists
        case directoryContacts(companyName: String?)
    
        var localizedTitle: String? {
            switch self {
            case .tokens:
                nil
            case .contacts:
                #localize("contact_list_search_token_title_contacts")
            case .groups:
                #localize("contact_list_search_token_title_groups")
            case .distributionLists:
                #localize("contact_list_search_token_title_distribution_lists")
            case let .directoryContacts(companyName):
                if let companyName {
                    String.localizedStringWithFormat(
                        #localize("contact_list_search_token_title_directory_contacts_name"),
                        companyName
                    )
                }
                else {
                    #localize("contact_list_search_token_title_directory_contacts")
                }
            }
        }
    }
    
    enum Row: Hashable {
        case token(ContactListSearchToken)
        case contact(NSManagedObjectID)
        case group(NSManagedObjectID)
        case distributionList(NSManagedObjectID)
        case directoryContact(CompanyDirectoryContact)
        case progress
    }
}

final class ContactListSearchDataSource: UITableViewDiffableDataSource<
    ContactListSearch.Section,
    ContactListSearch.Row
> {
    
    // MARK: - Properties
    
    @Published private var currentSearchText = ""
    private var cancellables = Set<AnyCancellable>()
    private var currentTokens = [ContactListSearchToken]()
    private var currentContactIDs: Set<ThreemaIdentity> = []
    
    private let serverAPIConnectorFactory: () -> ServerAPIConnector
    private lazy var serverAPIConnector = serverAPIConnectorFactory()
    private var currentDirectoryTask: Task<Void, Never>?
    private var nextPage = 0
    private var availablePages = 0
    
    private lazy var directoryFilterTokens: [ContactListSearchToken] = {
        guard let filters = fetchers.fetchDirectoryCategories() else {
            return []
        }
        
        let tokenInfos = filters.map { key, value in
            ContactListSearchToken.DirectoryTokenInfo(id: key, title: value)
        }.sorted { $0.title < $1.title }
        
        return tokenInfos.map {
            ContactListSearchToken.directoryFilterToken(info: $0)
        }
    }()
    
    private let fetchers: ContactListSearchDataSourceFetchers
    
    init(
        tableView: UITableView,
        fetchers: ContactListSearchDataSourceFetchers,
        serverAPIConnectorFactory: @escaping () -> ServerAPIConnector
    ) {
        self.fetchers = fetchers
        self.serverAPIConnectorFactory = serverAPIConnectorFactory
        
        super.init(tableView: tableView) { tableView, indexPath, row in
            switch row {
            case let .token(token):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: SearchContentConfigurations.contentConfigurationTokenCellIdentifier,
                    for: indexPath
                )
                cell.contentConfiguration = token.contentConfiguration
                
                // For these tokens it looks better if there is no inset for the icons
                // (as in Mail.app & Photos.app in iOS 17)
                cell.separatorInset = .zero
                cell.backgroundColor = .clear
                
                return cell
            
            case let .contact(objectID):
                guard let contactEntity = fetchers.fetchContact(objectID) else {
                    // TODO: (IOS-4536) Error
                    fatalError()
                }
                
                let cell: ContactCell = tableView.dequeueCell(for: indexPath)
                cell.content = .contact(Contact(contactEntity: contactEntity))
                cell.backgroundColor = .clear
                
                return cell
                
            case let .group(objectID):
                guard let group = fetchers.fetchGroup(objectID) else {
                    // TODO: (IOS-4536) Error
                    fatalError()
                }
                
                let cell: GroupCell = tableView.dequeueCell(for: indexPath)
                cell.group = group
                cell.backgroundColor = .clear
                
                return cell
                
            case let .distributionList(objectID):
                guard let distributionListEntity = fetchers.fetchDistributionList(objectID) else {
                    // TODO: (IOS-4536) Error
                    fatalError()
                }
                
                let cell: DistributionListCell = tableView.dequeueCell(for: indexPath)
                cell.distributionList = DistributionList(distributionListEntity: distributionListEntity)
                cell.backgroundColor = .clear
                
                return cell

            case let .directoryContact(directoryContact):
                let cell: DirectoryContactCell = tableView.dequeueCell(for: indexPath)
                
                cell.directoryContact = directoryContact
                
                // For these tokens it looks better if there is no inset for the icons
                // (as in Mail.app & Photos.app in iOS 17)
                cell.separatorInset = .zero
                cell.backgroundColor = .clear
                
                return cell
                
            case .progress:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: SearchContentConfigurations.contentConfigurationProgressCellIdentifier,
                    for: indexPath
                )
                let view = UIActivityIndicatorView()
                view.translatesAutoresizingMaskIntoConstraints = false
                view.startAnimating()
                
                cell.contentView.addSubview(view)
                NSLayoutConstraint.activate([
                    view.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                    view.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                ])
                cell.backgroundColor = .clear

                return cell
            }
        }
        
        $currentSearchText.debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, searchCompanyDirectory() else {
                    return
                }
                
                loadDirectoryContacts()
            }
            .store(in: &cancellables)
        
        registerCells(for: tableView)
        
        defaultRowAnimation = .fade
    }
    
    private func registerCells(for tableView: UITableView) {
        // We register here the header used in `ContactListSearchResultsViewController`. If we extend this we might move
        // this logic over there
        tableView.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: SearchContentConfigurations.contentConfigurationSectionHeaderIdentifier
        )
        
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: SearchContentConfigurations.contentConfigurationTokenCellIdentifier
        )
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: SearchContentConfigurations.contentConfigurationProgressCellIdentifier
        )

        tableView.registerCell(ContactCell.self)
        tableView.registerCell(GroupCell.self)
        tableView.registerCell(DistributionListCell.self)
        tableView.registerCell(DirectoryContactCell.self)
    }
    
    public func updateSearchResults(for text: String, with tokens: [ContactListSearchToken]) async {
        
        // Create fresh snapshot
        var snapshot = NSDiffableDataSourceSnapshot<ContactListSearch.Section, ContactListSearch.Row>()
        
        // Update current values
        let searchTextDidChange = currentSearchText != text
        let tokensDidChange = currentTokens != tokens
        
        // Only assign the text if the text or the tokens did change
        // This is needed to have the current text for the loadTokens function
        if searchTextDidChange || tokensDidChange {
            currentSearchText = text
        }
        currentTokens = tokens
        
        // Tokens are always updated to not have empty search results
        loadTokens(snapshot: &snapshot)
        
        // Do not search if nothing changed and apply tokens
        guard tokensDidChange || searchTextDidChange else {
            if text.isEmpty {
                Task { @MainActor in
                    apply(snapshot)
                }
            }
            
            return
        }
        
        // Resolve section contents
        
        // Contacts
        if currentTokens.contains(.contacts) || currentTokens.isEmpty, !text.isEmpty {
            loadContacts(snapshot: &snapshot)
        }
        else {
            currentContactIDs = []
        }
        
        // Groups
        if currentTokens.contains(.groups) || currentTokens.isEmpty, !text.isEmpty {
            loadGroups(snapshot: &snapshot)
        }
        
        // Distribution lists
        if currentTokens.contains(.distributionLists) || currentTokens.isEmpty, !text.isEmpty {
            loadDistributionList(snapshot: &snapshot)
        }
        
        // Directory contacts
        if searchCompanyDirectory() {
            addProgressCell(snapshot: &snapshot)
        }
        
        // Finally, apply the updates
        Task { @MainActor in
            apply(snapshot)
        }
    }
    
    // MARK: - Fetching
    
    private func loadTokens(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        
        var tokensToShow: [ContactListSearchToken]
        
        // Show all options while nothing is selected
        if currentTokens.isEmpty {
            tokensToShow = ContactListSearchToken.availableTokens
        }
        // Show directory filters when directory token is selected
        else if currentTokens.contains(.directoryContacts) {
            // We show the user all available filters as long as no search text is entered
            if currentSearchText.isEmpty, currentTokens.count == 1 {
                tokensToShow = directoryFilterTokens.filter { !currentTokens.contains($0) }
            }
            else {
                tokensToShow = directoryFilterTokens
                    .filter {
                        !currentTokens.contains($0) && $0.title.localizedCaseInsensitiveContains(currentSearchText)
                    }
            }
        }
        // Never show directory token once other is selected, and filter once already selected
        else {
            let nonSelectedTokens = ContactListSearchToken.availableTokens.filter {
                !currentTokens.contains($0) && $0 != .directoryContacts
            }
            tokensToShow = nonSelectedTokens
        }
        
        // We do not show the section if we have no filtered tokens
        guard !tokensToShow.isEmpty else {
            return
        }
        
        if !snapshot.sectionIdentifiers.contains(.tokens) {
            snapshot.appendSections([.tokens])
        }
        
        let rows: [ContactListSearch.Row] = tokensToShow.map {
            ContactListSearch.Row.token($0)
        }
        snapshot.appendItems(rows, toSection: .tokens)
    }
    
    private func loadContacts(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        let contactsIDs = fetchers.fetchContactIDsForSearch(currentSearchText)
        
        // We do not show the section if we have no contacts
        guard !contactsIDs.isEmpty else {
            return
        }
        
        let rows: [ContactListSearch.Row] = contactsIDs.map {
            ContactListSearch.Row.contact($0.objectID)
        }
        
        currentContactIDs = Set(contactsIDs.lazy.map(\.identity))
        
        if !snapshot.sectionIdentifiers.contains(.contacts) {
            snapshot.appendSections([.contacts])
        }
        snapshot.appendItems(rows, toSection: .contacts)
    }
    
    private func loadGroups(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        let groupConversationIDs = fetchers.fetchConversationsForSearch(currentSearchText)
        
        // We do not show the section if we have no groups
        guard !groupConversationIDs.isEmpty else {
            return
        }
        
        let rows: [ContactListSearch.Row] = groupConversationIDs.map {
            ContactListSearch.Row.group($0)
        }
        
        if !snapshot.sectionIdentifiers.contains(.groups) {
            snapshot.appendSections([.groups])
        }
        snapshot.appendItems(rows, toSection: .groups)
    }
    
    private func loadDistributionList(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        let distributionListIDs = fetchers.fetchDistributionListIDsForSearch(currentSearchText)
        
        // We do not show the section if we have no distribution lists
        guard !distributionListIDs.isEmpty else {
            return
        }
        let rows: [ContactListSearch.Row] = distributionListIDs.map {
            ContactListSearch.Row.distributionList($0)
        }
        
        if !snapshot.sectionIdentifiers.contains(.distributionLists) {
            snapshot.appendSections([.distributionLists])
        }
        snapshot.appendItems(rows, toSection: .distributionLists)
    }
    
    private func loadDirectoryContacts() {
        // Reset current state
        if let currentDirectoryTask {
            currentDirectoryTask.cancel()
        }
        
        availablePages = 0
        nextPage = 0
        
        currentDirectoryTask = Task {
            do {
                let (contacts, paging) = try await serverAPIConnector.searchDirectory(
                    text: query(),
                    categoryIdentifiers: directoryCategoryIdentifiers(),
                    page: 0
                )
                
                guard let size = paging["size"] as? Double,
                      let total = paging["total"] as? Double else {
                    self.currentDirectoryTask = nil
                    self.applyDirectorySearchResults(contacts: [])
                    return
                }
                
                self.availablePages = Int((total / size).rounded(.up))
                self.nextPage = paging["next"] as? Int ?? 0
               
                self.applyDirectorySearchResults(contacts: contacts)
            }
            catch {
                DDLogError("Error fetching directory contacts: \(error)")
                self.applyDirectorySearchResults(contacts: [])
            }
            
            self.currentDirectoryTask = nil
        }
    }
    
    public func loadMoreDirectoryContacts() {
        guard fetchers.isBusinessApp(), fetchers.isCompanyDirectory(), searchCompanyDirectory(),
              currentDirectoryTask == nil,
              nextPage < availablePages else {
            return
        }
        
        var snapshot = snapshot()
        addProgressCell(snapshot: &snapshot)
        Task { @MainActor in
            self.apply(snapshot)
        }

        currentDirectoryTask = Task {
            do {
                let (contacts, paging) = try await serverAPIConnector.searchDirectory(
                    text: query(),
                    categoryIdentifiers: directoryCategoryIdentifiers(),
                    page: nextPage
                )
                
                guard let nextPage = paging["next"] as? Int, let size = paging["size"] as? Double,
                      let total = paging["total"] as? Double else {
                    self.applyDirectorySearchResults(contacts: [])
                    return
                }
                
                self.availablePages = Int((total / size).rounded(.up))
                self.nextPage = nextPage
               
                self.applyDirectorySearchResults(contacts: contacts)
            }
            catch {
                DDLogError("Error fetching directory contacts: \(error)")
                self.applyDirectorySearchResults(contacts: [])
            }
            
            self.currentDirectoryTask = nil
        }
    }
    
    private func applyDirectorySearchResults(contacts: [CompanyDirectoryContact]) {
        var snapshot = snapshot()
        
        let rows: [ContactListSearch.Row] = contacts.compactMap { directoryContact in
            /// In case a directory contact is already in the contact section,
            /// we don't show it in the directory contacts section.
            guard currentContactIDs.contains(where: {
                $0.rawValue == directoryContact.id
            }) == false else {
                return nil
            }
            
            return ContactListSearch.Row.directoryContact(directoryContact)
        }
        
        removeProgressCell(snapshot: &snapshot)
        
        let companyName = fetchers.fetchCompanyName()
        
        if !rows.isEmpty {
            if !snapshot.sectionIdentifiers.contains(.directoryContacts(companyName: companyName)) {
                snapshot.appendSections([.directoryContacts(companyName: companyName)])
            }
            
            snapshot.appendItems(rows, toSection: .directoryContacts(companyName: companyName))
        }
       
        if snapshot.indexOfSection(.directoryContacts(companyName: companyName)) != nil,
           snapshot.numberOfItems(inSection: .directoryContacts(companyName: companyName)) == 0 {
            snapshot.deleteSections([.directoryContacts(companyName: companyName)])
        }
        
        Task { @MainActor in
            self.apply(snapshot)
        }
    }
    
    private func directoryCategoryIdentifiers() -> [String] {
        var identifiers: [String] = []
        for token in currentTokens {
            if case let .directoryFilterToken(info) = token {
                identifiers.append(info.id)
            }
        }
        return identifiers
    }
    
    private func addProgressCell(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        guard !snapshot.itemIdentifiers.contains(.progress) else {
            return
        }
        
        let companyName = fetchers.fetchCompanyName()
        
        if !snapshot.sectionIdentifiers.contains(.directoryContacts(companyName: companyName)) {
            snapshot.appendSections([.directoryContacts(companyName: companyName)])
        }
        snapshot.appendItems([.progress], toSection: .directoryContacts(companyName: companyName))
    }
    
    private func removeProgressCell(snapshot: inout NSDiffableDataSourceSnapshot<
        ContactListSearch.Section,
        ContactListSearch.Row
    >) {
        snapshot.deleteItems([.progress])
    }
        
    private func searchCompanyDirectory() -> Bool {
        // We search if:
        // - we are running a business app
        // - the company directory is enabled
        // - current tokens contains the main directory token or is empty, and the search text has more than 3
        // characters
        let filtered = currentTokens.filter { token in
            if case .directoryFilterToken = token {
                true
            }
            else {
                false
            }
        }
        
        return fetchers.isBusinessApp() && fetchers.isCompanyDirectory() &&
            (
                (currentTokens.contains(.directoryContacts) && currentSearchText.count >= 3) ||
                    (currentTokens.contains(.directoryContacts) && !filtered.isEmpty) ||
                    (currentTokens.isEmpty && currentSearchText.count >= 3)
            )
    }
    
    private func query() -> String {
        let trimmedSearchText = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedSearchText.isEmpty {
            return "*"
        }
        
        return trimmedSearchText
    }
}
