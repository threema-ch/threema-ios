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
import MBProgressHUD
import ThreemaMacros
import UIKit

/// Data source for `DistributionListDetailsViewController`
final class DistributionListDetailsDataSource: UITableViewDiffableDataSource<
    DistributionListDetails.Section,
    DistributionListDetails.Row
> {
    
    // MARK: - Properties
    
    private let displayMode: DistributionListDetailsDisplayMode

    private let distributionList: DistributionList
    private let conversation: ConversationEntity
    
    private weak var distributionListDetailsViewController: DistributionListDetailsViewController?
    private weak var tableView: UITableView?
    
    private lazy var businessInjector = BusinessInjector.ui
    private lazy var settingsStore = businessInjector.settingsStore as! SettingsStore
    private lazy var mdmSetup = MDMSetup(setup: false)
    
    private static let contentConfigurationCellIdentifier = "contentConfigurationCellIdentifier"
    
    // MARK: - Lifecycle
    
    init(
        for distributionList: DistributionList,
        displayMode: DistributionListDetailsDisplayMode,
        distributionListDetailsViewController: DistributionListDetailsViewController,
        tableView: UITableView
    ) {
        self.distributionList = distributionList
        self.displayMode = displayMode
        self.distributionListDetailsViewController = distributionListDetailsViewController
        self.tableView = tableView

        let em = EntityManager()
        self.conversation = em.entityFetcher.conversation(for: distributionList.distributionListID as NSNumber)!

        super.init(tableView: tableView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<
            DistributionListDetails.Section,
            DistributionListDetails.Row
        >.CellProvider
    ) {
        fatalError("Just use init(...).")
    }
    
    func registerHeaderAndCells() {
        tableView?.registerHeaderFooter(DetailsSectionHeaderView.self)
        
        tableView?.registerCell(ContactCell.self)
        tableView?.registerCell(MembersActionDetailsTableViewCell.self)
        tableView?.registerCell(ActionDetailsTableViewCell.self)
        tableView?.registerCell(WallpaperTableViewCell.self)
        tableView?.register(
            UITableViewCell.self,
            forCellReuseIdentifier: DistributionListDetailsDataSource.contentConfigurationCellIdentifier
        )
    }
    
    private let cellProvider: DistributionListDetailsDataSource.CellProvider = { tableView, indexPath, row in
        
        var cell: UITableViewCell
        
        switch row {
        case let .contact(contact, isSelfMember: isSelfMember):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .contact(contact)
            
            cell = contactCell
            
        case .unknownContact:
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .unknownContact
            cell = contactCell
            
        case let .recipientsAction(action):
            let actionCell: MembersActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            cell = actionCell
            
        case let .action(action):
            let actionCell: ActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            cell = actionCell
            
        case let .wallpaper(action, isDefault):
            let wallpaperCell: WallpaperTableViewCell = tableView.dequeueCell(for: indexPath)
            wallpaperCell.action = action
            wallpaperCell.isDefault = isDefault
            return wallpaperCell
        }
        
        return cell
    }
    
    // MARK: - Configure content
    
    func configureData() {
        var snapshot = NSDiffableDataSourceSnapshot<DistributionListDetails.Section, DistributionListDetails.Row>()
        
        // Only add a section if there are any rows to show
        func appendSectionIfNonEmptyItems(
            section: DistributionListDetails.Section,
            with items: [DistributionListDetails.Row]
        ) {
            guard !items.isEmpty else {
                return
            }
            
            snapshot.appendSections([section])
            snapshot.appendItems(items)
        }
        
        snapshot.appendSections([.recipients])
        snapshot.appendItems(distributionListRecipients())

        snapshot.appendSections([.wallpaperActions])
        snapshot.appendItems(wallpaperActions)
        
        if displayMode == .conversation {
            appendSectionIfNonEmptyItems(section: .contentActions, with: contentActions)
        }
        
        appendSectionIfNonEmptyItems(
            section: .destructiveDistributionListActions,
            with: destructiveDistributionListActions
        )
        
        apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Update content
    
    /// Freshly load the all the row items in the provided sections (and remove the section if there are no rows to
    /// show)
    ///
    /// If the you just want to refresh the items call `refresh(sections:)`.
    ///
    /// - Parameter sections: Sections to reload
    func reload(sections: [DistributionListDetails.Section]) {
        var localSnapshot = snapshot()
        
        func update(section: DistributionListDetails.Section, with items: [DistributionListDetails.Row]) {
            if items.isEmpty {
                localSnapshot.deleteSections([section])
            }
            else {
                localSnapshot.appendItems(items, toSection: section)
            }
        }
        
        for section in sections {
            if localSnapshot.sectionIdentifiers.contains(section) {
                let existingItems = localSnapshot.itemIdentifiers(inSection: section)
                localSnapshot.deleteItems(existingItems)
            }
            else {
                localSnapshot.appendSections([section])
            }
            
            switch section {
            case .contentActions:
                update(section: .contentActions, with: contentActions)
           
            case .recipients:
                localSnapshot.appendItems(distributionListRecipients(), toSection: .recipients)
                localSnapshot.reloadSections([.recipients])

            case .destructiveDistributionListActions:
                update(section: .destructiveDistributionListActions, with: destructiveDistributionListActions)
           
            case .wallpaperActions:
                localSnapshot.appendItems(wallpaperActions, toSection: .wallpaperActions)
            }
        }
        
        apply(localSnapshot)
    }
    
    /// Lightweight refresh of the provided sections
    /// - Parameter sections: Sections to refresh
    func refresh(sections: [DistributionListDetails.Section]) {
        var localSnapshot = snapshot()
        localSnapshot.reloadSections(sections)
        apply(localSnapshot)
    }
}

// MARK: - Quick Actions

extension DistributionListDetailsDataSource {
    
    func quickActions(in viewController: UIViewController) -> [QuickAction] {
        switch displayMode {
        case .default:
            defaultQuickActions(in: viewController)
        case .conversation:
            []
        }
    }
    
    private func defaultQuickActions(in viewController: UIViewController) -> [QuickAction] {
        var actions = [QuickAction]()
        
        let messageQuickAction = QuickAction(
            imageName: "threema.lock.bubble.right.fill",
            title: #localize("message"),
            accessibilityIdentifier: "DistributionListDetailsDataSourceMessageQuickActionButton"
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: [
                    kKeyConversation: strongSelf.conversation,
                    kKeyForceCompose: true,
                ]
            )
        }
        
        actions.append(messageQuickAction)
        
        return actions
    }
}

// MARK: - Sections

extension DistributionListDetailsDataSource {
    
    func distributionListRecipients() -> [DistributionListDetails.Row] {
        var rows = [DistributionListDetails.Row]()
        
        // Add recipients
        rows.append(contentsOf: conversation.unwrappedMembers.map { recipient in
            // Use creator row for creator
            let contact = Contact(contactEntity: recipient)
            return .contact(contact, isSelfMember: true)
        })
        
        return rows
    }
    
    private var contentActions: [DistributionListDetails.Row] {
        var rows = [DistributionListDetails.Row]()
        
        let messageFetcher = MessageFetcher(for: conversation, with: businessInjector.entityManager)
        if messageFetcher.count() > 0 {
            let localizedActionTitle = #localize("messages_delete_all_button")
            
            let deleteAllContentAction = Details.Action(
                title: localizedActionTitle,
                imageName: "trash",
                destructive: true
            ) { [weak self, weak distributionListDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongDistributionListDetailsViewController = distributionListDetailsViewController
                else {
                    return
                }
                
                let localizedTitle = #localize("messages_delete_all_confirm_title")
                let localizedMessage = #localize("messages_delete_all_confirm_message")
                let localizedDelete = #localize("delete")
                
                UIAlertTemplate.showDestructiveAlert(
                    owner: strongDistributionListDetailsViewController,
                    title: localizedTitle,
                    message: localizedMessage,
                    titleDestructive: localizedDelete,
                    actionDestructive: { _ in
                        if let tableView = strongSelf.tableView {
                            RunLoop.main.schedule {
                                let hud = MBProgressHUD(view: tableView)
                                hud.minShowTime = 1.0
                                hud.label.text = #localize("delete_in_progress")
                                tableView.addSubview(hud)
                                hud.show(animated: true)
                            }
                        }
                        
                        strongDistributionListDetailsViewController.willDeleteAllMessages()
                        
                        strongSelf.businessInjector.entityManager.performBlock {
                            _ = strongSelf.businessInjector.entityManager.entityDestroyer
                                .deleteMessages(of: strongSelf.conversation)
                            strongSelf.reload(sections: [.contentActions])
                            
                            DispatchQueue.main.async {
                                if let tableView = strongSelf.tableView {
                                    MBProgressHUD.hide(for: tableView, animated: true)
                                }
                            }
                        }
                    }
                )
            }
            rows.append(.action(deleteAllContentAction))
        }
        
        return rows
    }
    
    private var destructiveDistributionListActions: [DistributionListDetails.Row] {
        var rows = [DistributionListDetails.Row]()
        
        let localizedTitle = #localize("distribution_list_delete")
        let deleteAction = Details.Action(
            title: localizedTitle,
            destructive: true
        ) { [weak self, weak distributionListDetailsViewController] _ in
            guard let strongSelf = self,
                  let strongDistributionListDetailsViewController = distributionListDetailsViewController
            else {
                return
            }
            
            var cell: UITableViewCell?
            if let indexPathForSelectedRow = strongSelf.tableView?.indexPathForSelectedRow {
                cell = strongSelf.tableView?.cellForRow(at: indexPathForSelectedRow)
            }
            
            ConversationsViewControllerHelper.handleDeletion(
                of: strongSelf.conversation,
                owner: strongDistributionListDetailsViewController,
                cell: cell,
                singleFunction: .delete
            ) { _ in
                DDLogVerbose("Distribution list was deleted")
            }
        }
        rows.append(.action(deleteAction))
        
        return rows
    }
    
    private var wallpaperActions: [DistributionListDetails.Row] {
        var row = [DistributionListDetails.Row]()
        
        let wallpaperAction = Details.Action(
            title: #localize("settings_chat_wallpaper_title")
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            let navigationController =
                ThemedNavigationController(
                    rootViewController: CustomWallpaperSelectionViewController()
                        .customWallpaperSelectionView(conversationID: strongSelf.conversation.objectID) {
                            strongSelf.reload(sections: [.wallpaperActions])
                        }
                )
            navigationController.modalPresentationStyle = .formSheet
            strongSelf.distributionListDetailsViewController?.present(navigationController, animated: true)
        }
        
        row.append(.wallpaper(
            action: wallpaperAction,
            isDefault: !settingsStore.wallpaperStore.hasCustomWallpaper(for: conversation.objectID)
        ))
        return row
    }
}

// MARK: - Public recipients header configuration

extension DistributionListDetailsDataSource {
    var numberOfRecipients: Int {
        conversation.unwrappedMembers.count
    }
}

// MARK: - MWPhotoBrowserWrapperDelegate

extension DistributionListDetailsDataSource: MWPhotoBrowserWrapperDelegate {
    func willDeleteMessages(with objectIDs: [NSManagedObjectID]) {
        distributionListDetailsViewController?.willDeleteMessages(with: objectIDs)
    }
}
