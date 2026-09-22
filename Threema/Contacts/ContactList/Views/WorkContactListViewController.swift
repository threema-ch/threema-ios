import Foundation
import ThreemaFramework
import ThreemaMacros

final class WorkContactListViewController: ContactListBaseViewController {
    // MARK: - Properties
    
    private lazy var provider = WorkContactListProvider()
    private lazy var dataSource = ContactListDataSource(
        sourceType: .contacts,
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var refreshAction = ThreemaTableContentUnavailableView.Action(
        title: #localize("contact_list_button_refresh")
    ) { [weak self] in
        self?.syncContacts()
    }
    
    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: String.localizedStringWithFormat(
                #localize("contact_list_work_contacts_unavailable_title"),
                TargetManager.appName
            ),
            systemImage: "case.fill",
            description: #localize("contact_list_work_contacts_unavailable_description"),
            actions: [refreshAction]
        )
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func viewWillAppear(_ animated: Bool) {
        dataSource.contentUnavailableConfiguration = unavailableConfiguration
    }
    
    // MARK: - TableView
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let objectID = dataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        itemsDelegate?.didSelect(.contact(objectID))
    }
    
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let contact = contact(for: indexPath) else {
            return nil
        }
        let provider = ContactListSwipeActionProvider(businessInjector: businessInjector)
        return UISwipeActionsConfiguration(actions: provider.makeLeadingSwipeActions(for: contact))
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let provider = ContactListSwipeActionProvider(businessInjector: businessInjector)
        return provider.makeTrailingDeleteConfiguration(title: #localize("delete")) { [weak self] in
            guard let self,
                  let contact = contact(for: indexPath),
                  let entity = BusinessInjector.ui.entityManager.entityFetcher
                  .contactEntity(for: contact.identity.rawValue),
                  let cell = tableView.cellForRow(at: indexPath)
            else {
                return
            }
            
            DeleteContactAction(for: entity).execute(in: cell, of: self) { didDelete in
                if didDelete {
                    // TODO: (IOS-4515) Is a reload needed here?
                    tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func contact(for indexPath: IndexPath) -> Contact? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let contact = provider.entity(for: id) else {
            return nil
        }
        
        return contact
    }
}
