//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import Foundation
import ThreemaFramework
import ThreemaMacros

@objc final class GroupListViewController: ContactListBaseViewController {
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
        
        itemsDelegate?.didSelect(.group(objectID: objectID))
    }
    
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: rowActions(for: indexPath))
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        
        let action = DeleteActionFactory { [weak self] in
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
                cell: cell,
            ) { didDelete in
                if didDelete {
                    tableView.reloadData()
                }
            }
        }.make()
       
        let swipeAction = UISwipeActionsConfiguration(actions: [action])
        swipeAction.performsFirstActionWithFullSwipe = false
        return swipeAction
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let group = group(for: indexPath) else {
            return []
        }
        
        let entityManager = businessInjector.entityManager
        let conversation: ConversationEntity? = entityManager.performAndWait { [weak self] in
            self?.businessInjector.groupManager.getConversation(for: group.groupIdentity)
        }
        
        guard let conversation else {
            return []
        }
        
        let messageAction = MessageActionFactory.make(for: conversation)
        
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            return [messageAction]
        }
        
        let groupCallAction = CallActionFactory.make(for: group)
        return [messageAction, groupCallAction]
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
