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
    private lazy var provider = GroupListProvider()
    
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: GroupListCellProvider(),
        in: tableView,
        sectionIndexEnabled: false,
        contentUnavailableConfiguration: createContentUnavailableConfiguration()
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
}

extension GroupListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
        .init(actions: [
            .init(style: .destructive, title: "") { [weak self] _, _, _ in
                guard let self else {
                    return
                }
                deleteGroup(for: tableView, at: indexPath)
            }
            .then { $0.image = UIImage(systemName: "trash") },
        ])
    }
}

extension GroupListViewController {
    private func group(for indexPath: IndexPath) -> ThreemaFramework.Group? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let group = provider.entity(for: id) else {
            return nil
        }
        
        return group
    }
    
    private func deleteGroup(for tableView: UITableView, at indexPath: IndexPath) {
        guard
            let group = group(for: indexPath),
            let deleteAction = DeleteConversationAction.delete(forConversation: group.conversation)
        else {
            return
        }
            
        deleteAction.presentingViewController = self
        deleteAction.execute { didDelete in
            if didDelete {
                tableView.reloadData()
            }
        }
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let group = group(for: indexPath) else {
            return []
        }
        
        let messageAction = UIContextualAction(
            style: .normal,
            title: "",
            handler: { _, _, handler in
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationShowConversation),
                    object: nil,
                    userInfo: [
                        kKeyConversation: group.conversation,
                        kKeyForceCompose: true,
                    ]
                )
                handler(true)
            }
        ).then {
            $0.image = ThreemaImageResource.bundleImage("threema.lock.bubble.right.fill").uiImage
            $0.backgroundColor = .primary
        }
        
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
        groupCallAction.image = ThreemaImageResource.bundleImage("threema.phone.fill").uiImage
        groupCallAction.backgroundColor = Colors.gray
        return [messageAction, groupCallAction]
    }
}

extension GroupListViewController {
    private func createContentUnavailableConfiguration() -> ThreemaTableContentUnavailableView.Configuration {
        .init(
            title: #localize("no_groups"),
            systemImage: "person.3.fill",
            description: #localize("no_groups_message"),
            actions: [
                .init(title: #localize("contactList_add"), block: { [weak self] in
                    guard let self else {
                        return
                    }
                    itemsDelegate?.add(.groups)
                }),
            ]
        )
    }
}
