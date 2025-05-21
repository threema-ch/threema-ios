//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import Foundation
import ThreemaFramework
import ThreemaMacros

final class ContactListSearchResultsViewController: ThemedViewController {
    
    // MARK: - Private properties
        
    private let businessInjector: BusinessInjector
    
    private weak var searchController: UISearchController?
   
    private lazy var dataSource = ContactListSearchDataSource(
        tableView: tableView,
        businessInjector: businessInjector
    )
    
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

    init(businessInjector: BusinessInjector) {
        self.businessInjector = businessInjector
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
        
        guard let identifier = dataSource.itemIdentifier(for: indexPath),
              let navigationController = parent?.presentingViewController?.navigationController else {
            return
        }
        
        let entityManager = businessInjector.entityManager
        
        switch identifier {
        case let .token(token):
            guard let searchController else {
                return
            }
            
            let currentTokenCount = searchController.searchBar.searchTextField.tokens.count
            searchController.searchBar.searchTextField.insertToken(token.searchToken, at: currentTokenCount)
            searchController.searchBar.text = ""
            
        case let .contact(contactID):
            let contactEntity = entityManager.performAndWait {
                entityManager.entityFetcher.existingObject(with: contactID) as? ContactEntity
            }
            guard let contactEntity else {
                return
            }
            
            navigationController.pushViewController(
                SingleDetailsViewController(for: Contact(contactEntity: contactEntity), displayStyle: .default),
                animated: true
            )

        case let .group(conversationID):
            let conversationEntity = entityManager.performAndWait {
                entityManager.entityFetcher.existingObject(with: conversationID) as? ConversationEntity
            }
            guard let conversationEntity,
                  let group = businessInjector.groupManager.getGroup(conversation: conversationEntity) else {
                return
            }
            
            navigationController.pushViewController(
                GroupDetailsViewController(for: group, displayStyle: .default),
                animated: true
            )

        case let .distributionList(distributionListID):
            let distributionListEntity = entityManager.performAndWait {
                entityManager.entityFetcher.existingObject(with: distributionListID) as? DistributionListEntity
            }
            guard let distributionListEntity else {
                return
            }
            
            navigationController.pushViewController(
                DistributionListDetailsViewController(
                    for: DistributionList(distributionListEntity: distributionListEntity),
                    displayStyle: .default
                ),
                animated: true
            )

        case let .directoryContact(directoryContact):
            addDirectoryContact(directoryContact) { contact in
                guard let contact else {
                    return
                }
                
                Task { @MainActor in
                    let contactEntity = entityManager.performAndWait {
                        entityManager.entityFetcher.existingObject(with: contact.objectID) as? ContactEntity
                    }
                    guard let contactEntity else {
                        return
                    }
                    
                    navigationController.pushViewController(
                        SingleDetailsViewController(for: Contact(contactEntity: contactEntity), displayStyle: .default),
                        animated: true
                    )
                }
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
        
        let contact = businessInjector.entityManager.performAndWait {
            self.businessInjector.entityManager.entityFetcher.contact(for: directoryContact.id)
        }
        
        guard contact == nil else {
            return nil
        }
        
        let action = UIContextualAction(
            style: .normal,
            title: #localize("contact_list_directory_add")
        ) { [weak self] _, _, handler in
            self?.addDirectoryContact(directoryContact) { _ in
                handler(true)
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
    
    private func addDirectoryContact(
        _ directoryContact: CompanyDirectoryContact,
        completion: @escaping (ContactEntity?) -> Void
    ) {
        // If we already have the contact, we unhide it
        let contactEntity = businessInjector.entityManager.performAndWaitSave {
            let contact = self.businessInjector.entityManager.entityFetcher.contact(for: directoryContact.id)
            
            if let contact {
                contact.isHidden = false
            }
            
            return contact
        }
        
        if let contactEntity {
            completion(contactEntity)
            return
        }
        
        businessInjector.contactStore.addWorkContact(
            with: directoryContact.id,
            publicKey: directoryContact.pk,
            firstname: directoryContact.first,
            lastname: directoryContact.last,
            csi: directoryContact.csi,
            jobTitle: directoryContact.jobTitle,
            department: directoryContact.department,
            acquaintanceLevel: .direct
        ) { contact in
            NotificationPresenterWrapper.shared.present(type: .directoryContactAdded)
            completion(contact)
        } onError: { error in
            DDLogError("Add work contact failed \(error)")
            completion(nil)
        }
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
        let searchText = searchController.searchBar.text ?? ""
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
        Task.detached(priority: .background) { [self] in
            await dataSource.updateSearchResults(for: searchText, with: selectedTokens)
        }
    }
}
