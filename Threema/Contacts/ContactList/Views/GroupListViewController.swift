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
        tableView.deselectRow(at: indexPath, animated: true)

        guard let group = group(for: indexPath) else {
            return
        }
        show(GroupDetailsViewController(for: group, displayStyle: .default), sender: self)
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
        
        let action = UIContextualAction(style: .destructive, title: #localize("delete")) { [weak self] _, _, _ in
            guard let self,
                  let group = group(for: indexPath)
            else {
                return
            }
            
            let conversation: ConversationEntity? = businessInjector.entityManager.performAndWait {
                self.businessInjector.groupManager.getConversation(for: group.groupIdentity)
            }
            guard let conversation,
                  let deleteAction = DeleteConversationAction.delete(forConversation: conversation) else {
                return
            }
            
            deleteAction.presentingViewController = self
            deleteAction.execute { didDelete in
                if didDelete {
                    tableView.reloadData()
                }
            }
        }
        action.image = UIImage(systemName: "trash")
       
        let swipeAction = UISwipeActionsConfiguration(actions: [action])
        swipeAction.performsFirstActionWithFullSwipe = false
        return swipeAction
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let group = group(for: indexPath) else {
            return []
        }
        
        let conversation: ConversationEntity? = businessInjector.entityManager.performAndWait {
            self.businessInjector.groupManager.getConversation(for: group.groupIdentity)
        }
        
        guard let conversation else {
            return []
        }
        
        let messageAction = UIContextualAction(
            style: .normal,
            title: ""
        ) { _, _, handler in
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: [
                    kKeyConversation: conversation,
                    kKeyForceCompose: true,
                ]
            )
            handler(true)
        }
        
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .tintColor
        
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            return [messageAction]
        }
        
        let groupCallAction = UIContextualAction(
            style: .normal,
            title: "",
            handler: { _, _, handler in
                GlobalGroupCallManagerSingleton.shared.startGroupCall(
                    in: group,
                    intent: .createOrJoin
                )
                handler(true)
            }
        )
        groupCallAction.image = UIImage(resource: .threemaPhoneFill)
        groupCallAction.backgroundColor = .systemGray
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
