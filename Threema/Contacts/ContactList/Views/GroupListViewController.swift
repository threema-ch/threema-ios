import Foundation
import ThreemaFramework
import ThreemaMacros

final class GroupListViewController: ContactListBaseViewController {
    // MARK: - Properties

    private lazy var provider = GroupListProvider()
    
    private lazy var dataSource = ContactListDataSource(
        sourceType: .groups,
        provider: provider,
        cellProvider: GroupListCellProvider(),
        in: tableView,
        sectionIndexEnabled: false,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var createGroupAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_button_create")) { [weak self] in
            guard let delegate = self?.itemsDelegate else {
                return
            }
            delegate.add(.groups)
        }
    
    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: #localize("contact_list_group_unavailable_title"),
            systemImage: "person.3.fill",
            description: #localize("contact_list_group_unavailable_description"),
            actions: [createGroupAction]
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
        
        itemsDelegate?.didSelect(.group(objectID))
    }
    
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let group = group(for: indexPath) else {
            return nil
        }
        
        let entityManager = businessInjector.entityManager
        let conversation: ConversationEntity? = entityManager.performAndWait { [weak self] in
            self?.businessInjector.groupManager.getConversation(for: group.groupIdentity)
        }
        
        guard let conversation else {
            return nil
        }
        
        let provider = ContactListSwipeActionProvider(businessInjector: businessInjector)
        return UISwipeActionsConfiguration(
            actions: provider.makeLeadingSwipeActions(for: group, conversation: conversation)
        )
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let provider = ContactListSwipeActionProvider(businessInjector: businessInjector)
        return provider.makeTrailingDeleteConfiguration(title: #localize("delete")) { [weak self] in
            guard let self,
                  let group = group(for: indexPath),
                  let cell = tableView.cellForRow(at: indexPath)
            else {
                return
            }
            
            let conversation: ConversationEntity? = businessInjector.entityManager.performAndWait {
                self.businessInjector.groupManager.getConversation(for: group.groupIdentity)
            }
            guard let conversation else {
                return
            }
            
            DeleteConversationAction.execute(
                for: conversation,
                owner: self,
                anchorView: cell,
            ) { didDelete in
                if didDelete {
                    tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func group(for indexPath: IndexPath) -> ThreemaFramework.Group? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let group = provider.entity(for: id) else {
            return nil
        }
        
        return group
    }
}
