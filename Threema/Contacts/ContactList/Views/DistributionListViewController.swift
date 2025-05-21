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

@objc class DistributionListViewController: ContactListBaseViewController {
    // MARK: - Properties
    
    private lazy var provider = DistributionListProvider()
    private lazy var dataSource = ContactListDataSource(
        sourceType: .distributionLists,
        provider: provider,
        cellProvider: DistributionListCellProvider(),
        in: tableView,
        sectionIndexEnabled: false,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var createDistributionListAction = ThreemaTableContentUnavailableView
        .Action(title: #localize("contact_list_button_create")) { [weak self] in
            guard let delegate = self?.itemsDelegate else {
                return
            }
            delegate.add(.distributionLists)
        }
    
    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: #localize("contact_list_distribution_list_unavailable_title"),
            systemImage: "megaphone.fill",
            description: #localize("contact_list_distribution_list_unavailable_description"),
            actions: [createDistributionListAction]
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

        let action = UIContextualAction(style: .destructive, title: #localize("delete")) { [weak self] _, _, _ in
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
                titleDestructive: #localize("delete")
            ) { [weak em] _ in
                guard let em else {
                    return
                }
                // TODO: (IOS-4515) Add correct logic
                assertionFailure("Not implemented")
//                    em.performAndWaitSave {
//                        em.entityDestroyer.delete(distributionListEntity: entity)
//                    }
            }
        }
        action.image = UIImage(systemName: "trash")
        
        let swipeAction = UISwipeActionsConfiguration(actions: [action])
        swipeAction.performsFirstActionWithFullSwipe = false
        return swipeAction
    }
    
    private func rowActions(for indexPath: IndexPath) -> [UIContextualAction] {
        guard let distributionList = distributionList(for: indexPath) else {
            return []
        }

        let messageAction = UIContextualAction(
            style: .normal,
            title: #localize("message"),
            handler: { _, _, handler in
                // TODO: (IOS-4515) Add legit fetching
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
        )
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .tintColor
        
        return [messageAction]
    }
    
    // MARK: - Helper
    
    private func distributionList(for indexPath: IndexPath) -> ThreemaFramework.DistributionList? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let distributionList = provider.entity(for: id) else {
            return nil
        }
        
        return distributionList
    }
}
