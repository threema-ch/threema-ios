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
import SwiftUI
import ThreemaFramework
import ThreemaMacros

@objc class ContactListBaseViewController: ThemedTableViewController {
    weak var itemsDelegate: ContactListActionDelegate?
    
    init(itemsDelegate: ContactListActionDelegate? = nil) {
        self.itemsDelegate = itemsDelegate
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@objc final class ContactListViewController: ContactListBaseViewController {
    private lazy var provider = ContactListProvider()
   
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: createContentUnavailableConfiguration()
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let contact = provider.entity(for: id) else {
            return
        }
        show(SingleDetailsViewController(for: contact, displayStyle: .default), sender: self)
    }
    
    private var accessActions: [ThreemaTableContentUnavailableView.Action] {
        let inviteAction: ThreemaTableContentUnavailableView.Action = .init(title: #localize("invite")) {
            _ = AppDelegate.shared().currentTopViewController().map { currentVC in
                InviteController().then {
                    $0.parentViewController = currentVC
                    $0.shareViewController = currentVC
                    $0.actionSheetViewController = currentVC
                    $0.rect = .zero
                    $0.invite()
                }
            }
        }
        
        return switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            [.init(title: #localize("contactList_sync_contacts"), block: {
                // TODO: Add Sync Contacts
                print("Sync Contacts")
            }), inviteAction]
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
    
    private func requestAccess() {
        Task { @MainActor in
            guard let _ = try? await CNContactStore().requestAccess(for: .contacts) else {
                return
            }
        }
    }
}

extension ContactListViewController {
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

@objc final class WorkContactListViewController: ContactListBaseViewController {
    private lazy var provider = WorkContactListProvider()
    
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView,
        contentUnavailableConfiguration: createContentUnavailableConfiguration()
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let contact = provider.entity(for: id) else {
            return
        }
        show(SingleDetailsViewController(for: contact, displayStyle: .default), sender: self)
    }
}

extension WorkContactListViewController {
    private func createContentUnavailableConfiguration() -> ThreemaTableContentUnavailableView.Configuration {
        .init(
            title: #localize("no_work_contacts"),
            systemImage: "threema.case.circle.fill",
            description: #localize("no_contacts_loading"),
            actions: [
                .init(title: #localize("contactList_refresh"), block: {
                    // TODO: Add Refresh Work Contacts
                    print("Refresh Work Contacts")
                }),
            ]
        )
    }
}

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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let group = provider.entity(for: id) else {
            return
        }
        show(GroupDetailsViewController(for: group, displayStyle: .default), sender: self)
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

@objc class DistributionListViewController: ContactListBaseViewController {
    private lazy var provider = DistributionListProvider()

    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: DistributionListCellProvider(),
        in: tableView,
        sectionIndexEnabled: false,
        contentUnavailableConfiguration: createContentUnavailableConfiguration()
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let distributionList = provider.entity(for: id) else {
            return
        }
        show(DistributionListDetailsViewController(for: distributionList, displayStyle: .default), sender: self)
    }
}

extension DistributionListViewController {
    private func createContentUnavailableConfiguration() -> ThreemaTableContentUnavailableView.Configuration {
        .init(
            title: #localize("no_distribution_list"),
            systemImage: "megaphone.fill",
            description: #localize("no_distribution_list_message"),
            actions: [
                .init(title: #localize("contactList_add"), block: { [weak self] in
                    guard let self else {
                        return
                    }
                    itemsDelegate?.add(.distributionLists)
                }),
            ]
        )
    }
}
