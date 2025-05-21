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

@objc final class WorkContactListViewController: ContactListBaseViewController {
    // MARK: - Properties
    
    private lazy var provider = WorkContactListProvider()
    private lazy var dataSource = ContactListDataSource(
        sourceType: .contacts,
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var refreshAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_button_refresh")) { [weak self] in
            self?.syncContacts()
        }
    
    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: String
                .localizedStringWithFormat(
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
        tableView.deselectRow(at: indexPath, animated: true)

        guard let contact = contact(for: indexPath) else {
            return
        }
        show(SingleDetailsViewController(for: contact, displayStyle: .default), sender: self)
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
        
        let action = UIContextualAction(
            style: .destructive,
            title: #localize("delete_contact_button")
        ) { [weak self] _, _, _ in
            guard let self,
                  let contact = contact(for: indexPath),
                  let entity = EntityManager().entityFetcher.contact(for: contact.identity.string),
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
        action.image = UIImage(systemName: "trash")
       
        let swipeAction = UISwipeActionsConfiguration(actions: [action])
        swipeAction.performsFirstActionWithFullSwipe = false
        return swipeAction
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let contact = contact(for: indexPath) else {
            return []
        }
        var actions: [UIContextualAction] = []
        
        let messageAction = UIContextualAction(
            style: .normal,
            title: #localize("message"),
            handler: { _, _, handler in
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationShowConversation),
                    object: nil,
                    userInfo: [
                        kKeyContactIdentity: contact.objcIdentity,
                        kKeyForceCompose: true,
                    ]
                )
                handler(true)
            }
        )
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .tintColor
        actions.append(messageAction)

        if UserSettings.shared()?.enableThreemaCall == true, contact.supportsCalls {
            let callAction = UIContextualAction(
                style: .normal,
                title: #localize("call"),
                handler: { _, _, handler in
                    let action = VoIPCallUserAction(
                        action: .call,
                        contactIdentity: contact.identity.string,
                        callID: nil,
                        completion: nil
                    )
                    VoIPCallStateManager.shared.processUserAction(action)
                    
                    handler(true)
                }
            )
            
            callAction.image = ThreemaImageResource.bundleImage("threema.phone.fill").uiImage
            callAction.backgroundColor = .systemGray
            actions.append(callAction)
        }

        return actions
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
