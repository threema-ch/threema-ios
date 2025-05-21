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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework
import ThreemaMacros

@objc final class ContactListViewController: ContactListBaseViewController {
    
    // MARK: - Properties
    
    private lazy var provider = ContactListProvider()
    private lazy var dataSource = ContactListDataSource(
        sourceType: .contacts,
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var syncContactsAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_button_sync")) { [weak self] in
            self?.syncContacts()
        }
    
    private lazy var addContactAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_button_add")) { [weak self] in
            guard let delegate = self?.itemsDelegate else {
                return
            }
            delegate.add(.contacts)
        }
    
    private lazy var requestAccessAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_request_action_title")) {
            Task { @MainActor in
                _ = try? await CNContactStore().requestAccess(for: .contacts)
                self.dataSource.contentUnavailableConfiguration = self.unavailableConfiguration
            }
        }
    
    private lazy var limitedAccessAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_limited_access_action_title")) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Task { await UIApplication.shared.open(url) }
            }
        }
    
    private lazy var changeAccessInSettingsAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_change_access_in_settings_title")) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Task { await UIApplication.shared.open(url) }
            }
        }
    
    private var unavailableActions: [ThreemaTableContentUnavailableView.Action] {
        var actions = [addContactAction]
        
        guard businessInjector.userSettings.syncContacts else {
            return actions
        }
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
            
        case .notDetermined:
            actions.append(requestAccessAction)
        case .restricted:
            break
        case .denied:
            actions.append(changeAccessInSettingsAction)
        case .authorized:
            actions.append(syncContactsAction)
        case .limited:
            actions.append(syncContactsAction)
            actions.append(limitedAccessAction)
        @unknown default:
            break
        }
        return actions
    }
    
    private var unavailableDescription: String {
        guard businessInjector.userSettings.syncContacts else {
            return String.localizedStringWithFormat(
                #localize("contact_list_contacts_unavailable_description_sync_disabled"),
                #localize("settings"),
                #localize("settings_list_privacy_title")
            )
        }
        
        let description: String
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            description = #localize("contact_list_contacts_unavailable_description_not_determined")
        case .restricted:
            description = #localize("contact_list_contacts_unavailable_description_restricted")
        case .denied:
            description = #localize("contact_list_contacts_unavailable_description_denied")
        case .authorized:
            description = #localize("contact_list_contacts_unavailable_description_authorized")
        case .limited:
            description = #localize("contact_list_contacts_unavailable_description_limited")
        @unknown default:
            return ""
        }
        return String.localizedStringWithFormat(description, TargetManager.appName)
    }
    
    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: #localize("contact_list_contact_unavailable_title"),
            systemImage: "person.2.fill",
            description: unavailableDescription,
            actions: unavailableActions
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
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        dataSource.checkLimitedAccessHeader()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let header = tableView.tableHeaderView {
            header.setNeedsLayout()
            header.layoutIfNeeded()
        }
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
            title: #localize("message")
        ) { _, _, handler in
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
        
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .tintColor
        actions.append(messageAction)
        
        if UserSettings.shared()?.enableThreemaCall == true,
           contact.supportsCalls {
            let callAction = UIContextualAction(
                style: .normal,
                title: #localize("call")
            ) { _, _, handler in
                let action = VoIPCallUserAction(
                    action: .call,
                    contactIdentity: contact.identity.string,
                    callID: nil,
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
                    
                handler(true)
            }
            
            callAction.image = UIImage(resource: .threemaPhoneFill)
            callAction.backgroundColor = .tintColor
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
