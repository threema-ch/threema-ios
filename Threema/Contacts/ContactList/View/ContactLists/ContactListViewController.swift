//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import SwiftUI
import ThreemaFramework
import ThreemaMacros

@objc final class ContactListViewController: ContactListBaseViewController {
    private lazy var provider = ContactListProvider()
   
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: createContentUnavailableConfiguration()
    )
    
    private var accessActions: [ThreemaTableContentUnavailableView.Action] {
        return switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            [.init(title: #localize("contactList_sync_contacts"), block: {
                // TODO: IOS-4884 add contact sync
                print("Sync Contacts")
            })]
        case .restricted, .denied:
            [.init(title: #localize("contactList_go_to_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Task { await UIApplication.shared.open(url) }
                }
            }]
        case .notDetermined:
            [.init(title: #localize("contactList_request_access"), block: requestAccess)]
        @unknown default:
            []
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.refreshControl = UIRefreshControl().then {
            $0.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
            setRefreshControlTitle(false, $0)
        }
    }
}

extension ContactListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
        .init(actions: [
            .init(style: .destructive, title: "") { [weak self] _, _, _ in
                guard
                    let self,
                    let contact = contact(for: indexPath),
                    let entity = EntityManager().entityFetcher.contact(for: contact.identity.string),
                    let cell = tableView.cellForRow(at: indexPath)
                else {
                    return
                }
                    
                DeleteContactAction(for: entity).execute(in: cell, of: self) { didDelete in
                    if didDelete {
                        tableView.reloadData()
                    }
                }
            }
            .then { $0.image = UIImage(systemName: "trash") },
        ])
    }
}

extension ContactListViewController {
    @objc private func pulledToRefresh() {
        // TODO: IOS-4884 add contact sync
        tableView.refreshControl?.endRefreshing()
    }
    
    private func setRefreshControlTitle(_ active: Bool, _ rfControl: UIRefreshControl) {
        rfControl.attributedTitle = NSMutableAttributedString(
            string: active ? #localize("synchronizing") : #localize("pull_to_sync"),
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: Colors.textLight,
                .backgroundColor: UIColor.clear,
            ]
        )
    }
    
    private func requestAccess() {
        Task { @MainActor in
            guard let _ = try? await CNContactStore().requestAccess(for: .contacts) else {
                return
            }
        }
    }
    
    private func contact(for indexPath: IndexPath) -> Contact? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let contact = provider.entity(for: id) else {
            return nil
        }
        
        return contact
    }
    
    private func deleteContact(for tableView: UITableView, at indexPath: IndexPath) {
        guard
            let contact = contact(for: indexPath),
            let entity = EntityManager().entityFetcher.contact(for: contact.identity.string),
            let cell = tableView.cellForRow(at: indexPath)
        else {
            return
        }
            
        let deleteAction = DeleteContactAction(for: entity)
            
        deleteAction.execute(in: cell, of: self) { didDelete in
            if didDelete {
                tableView.reloadData()
            }
        }
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let contact = contact(for: indexPath) else {
            return []
        }
        var actions: [UIContextualAction] = []
        
        let messageAction = UIContextualAction(
            style: .normal,
            title: "",
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
        ).then {
            $0.image = ThreemaImageResource.bundleImage("threema.lock.bubble.right.fill").uiImage
            $0.backgroundColor = .primary
        }
        
        if
            UserSettings.shared()?.enableThreemaCall == true,
            !contact.hasGatewayID,
            !contact.isEchoEcho {
            let callAction = UIContextualAction(
                style: .normal,
                title: "",
                handler: { _, _, handler in
                    if FeatureMask.check(contact: contact, for: .o2OAudioCallSupport) {
                        let action = VoIPCallUserAction(
                            action: .call,
                            contactIdentity: contact.identity.string,
                            callID: nil,
                            completion: nil
                        )
                        VoIPCallStateManager.shared.processUserAction(action)
                    }
                    else {
                        NotificationPresenterWrapper.shared.present(type: .callCreationError)
                    }
                    
                    handler(true)
                }
            )
            
            callAction.image = ThreemaImageResource.bundleImage("threema.phone.fill").uiImage
            callAction.backgroundColor = Colors.gray
            actions.append(callAction)
        }
        
        return [messageAction] + actions
    }
    
    private func createContentUnavailableConfiguration() -> ThreemaTableContentUnavailableView.Configuration {
        .init(
            title: #localize("no_contacts"),
            systemImage: "person.2.fill",
            description: ThreemaApp
                .current == .onPrem ? "" : "no_contacts_sync\(UserSettings.shared().syncContacts ? "on" : "off")"
                .localized,
            actions: [
                .init(title: #localize("contactList_add"), block: { [weak self] in
                    guard let self else {
                        return
                    }
                    itemsDelegate?.add(.contacts)
                }),
            ] + accessActions
        )
    }
}
