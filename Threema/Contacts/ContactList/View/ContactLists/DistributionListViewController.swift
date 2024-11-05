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

import Foundation
import ThreemaFramework
import ThreemaMacros

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
}

extension DistributionListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let distributionList = distributionList(for: indexPath) else {
            return
        }
        show(DistributionListDetailsViewController(for: distributionList, displayStyle: .default), sender: self)
    }
    
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: rowActions(for: indexPath))
    }

    // TODO: (IOS-4366) Use bottom action sheet
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        .init(
            actions: [
                .init(style: .destructive, title: "") { [weak self] _, _, _ in
                    let em = EntityManager()
                    guard
                        let self,
                        let distributionList = distributionList(for: indexPath),
                        let entity = em.entityFetcher
                        .distributionListEntity(forDistributionListID: distributionList.distributionListID as NSNumber)
                    else {
                        return
                    }
                    
                    UIAlertTemplate.showDestructiveAlert(
                        owner: self,
                        title: #localize("distribution_list_delete_sheet_title"),
                        message: nil,
                        titleDestructive: #localize("delete"),
                        actionDestructive: { [weak em] _ in
                            guard let em else {
                                return
                            }
                            
                            em.performAndWaitSave {
                                em.entityDestroyer.delete(distributionListEntity: entity)
                            }
                        },
                        titleCancel: #localize("cancel"),
                        actionCancel: { _ in }
                    )
                }
                .then { $0.image = UIImage(systemName: "trash") },
            ]
        )
    }
}

extension DistributionListViewController {
    private func distributionList(for indexPath: IndexPath) -> ThreemaFramework.DistributionList? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let distributionList = provider.entity(for: id) else {
            return nil
        }
        
        return distributionList
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let distributionList = distributionList(for: indexPath) else {
            return []
        }

        let messageAction = UIContextualAction(
            style: .normal,
            title: "",
            handler: { _, _, handler in
                let conversation = EntityManager().entityFetcher
                    .conversation(for: distributionList.distributionListID as NSNumber)!
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
        ).then {
            $0.image = ThreemaImageResource.bundleImage("threema.lock.bubble.right.fill").uiImage
            $0.backgroundColor = .primary
        }
        
        return [messageAction]
    }
    
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
