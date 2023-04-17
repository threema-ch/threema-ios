//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import UIKit

extension GroupDetailsDataSource {
    struct Configuration {
        /// Number of members shown directly in details
        let maxNumberOfMembersShownInline = 5
        
        /// Reduced alpha if creator left group
        static let leftAlpha: CGFloat = 0.5
    }
}

/// Data source for `GroupDetailsViewController`
final class GroupDetailsDataSource: UITableViewDiffableDataSource<GroupDetails.Section, GroupDetails.Row> {
    
    // MARK: - Properties
    
    private let displayMode: GroupDetailsDisplayMode

    private let group: Group
    private let conversation: Conversation
    
    private weak var groupDetailsViewController: GroupDetailsViewController?
    private weak var tableView: UITableView?
    
    private lazy var entityManager = EntityManager()
    private lazy var groupManger = GroupManager()
    private lazy var mdmSetup = MDMSetup(setup: false)
    
    private lazy var photoBrowserWrapper: MWPhotoBrowserWrapper? = {
        if let viewController = groupDetailsViewController {
            return MWPhotoBrowserWrapper(
                for: conversation,
                in: viewController,
                entityManager: self.entityManager,
                delegate: self
            )
        }
        return nil
    }()
        
    private let configuration = Configuration()
    
    // MARK: - Lifecycle
    
    init(
        for group: Group,
        displayMode: GroupDetailsDisplayMode,
        groupDetailsViewController: GroupDetailsViewController,
        tableView: UITableView
    ) {
        self.group = group
        self.displayMode = displayMode
        self.groupDetailsViewController = groupDetailsViewController
        self.tableView = tableView

        let em = EntityManager()
        self.conversation = em.entityFetcher.conversation(
            for: group.groupID,
            creator: group.groupCreatorIdentity
        )!

        super.init(tableView: tableView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping UITableViewDiffableDataSource<GroupDetails.Section, GroupDetails.Row>.CellProvider
    ) {
        fatalError("Just use init(...).")
    }
    
    func registerHeaderAndCells() {
        tableView?.registerHeaderFooter(DetailsSectionHeaderView.self)
                
        tableView?.registerCell(ContactCell.self)
        tableView?.registerCell(MembersActionDetailsTableViewCell.self)
        tableView?.registerCell(ActionDetailsTableViewCell.self)
        tableView?.registerCell(DoNotDisturbDetailsTableViewCell.self)
        tableView?.registerCell(SwitchDetailsTableViewCell.self)
    }
    
    private let cellProvider: GroupDetailsDataSource.CellProvider = { tableView, indexPath, row in
        
        var cell: UITableViewCell
        
        switch row {
        
        case .meContact:
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .me
            cell = contactCell
        
        case let .contact(contact, isSelfMember: isSelfMember):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .contact(contact)
            contactCell.contentView.alpha = !isSelfMember ? Configuration.leftAlpha : 1
            cell = contactCell
            
        case .unknownContact:
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .unknownContact
            cell = contactCell
            
        case let .membersAction(action):
            let actionCell: MembersActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            cell = actionCell
            
        case let .meCreator(left, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .me
            contactCell.contentView.alpha = left ? Configuration.leftAlpha : 1
            cell = contactCell
            
        case let .contactCreator(contact, left: left, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .contact(contact)
            contactCell.contentView.alpha = left ? Configuration.leftAlpha : 1
            cell = contactCell
            
        case .unknownContactCreator(_, inMembers: _):
            let contactCell: ContactCell = tableView.dequeueCell(for: indexPath)
            contactCell.size = .medium
            contactCell.content = .unknownContact
            // No alpha change as an unknown contact is always shown dimmed
            cell = contactCell
        
        case let .action(action):
            let actionCell: ActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            cell = actionCell
            
        case let .booleanAction(action):
            let switchCell: SwitchDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            switchCell.action = action
            cell = switchCell
        
        case let .doNotDisturb(action, group):
            let dndCell: DoNotDisturbDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            dndCell.action = action
            dndCell.type = .group(group)
            cell = dndCell
        }
        
        return cell
    }
    
    // MARK: - Configure content
    
    func configureData() {
        var snapshot = NSDiffableDataSourceSnapshot<GroupDetails.Section, GroupDetails.Row>()
        
        // Only add a section if there are any rows to show
        func appendSectionIfNonEmptyItems(section: GroupDetails.Section, with items: [GroupDetails.Row]) {
            guard !items.isEmpty else {
                return
            }
            
            snapshot.appendSections([section])
            snapshot.appendItems(items)
        }
        
        snapshot.appendSections([.members])
        snapshot.appendItems(groupMembers())
        snapshot.appendSections([.creator])
        snapshot.appendItems([creatorRow()])
        
        if displayMode == .conversation {
            appendSectionIfNonEmptyItems(section: .contentActions, with: contentActions)
        }
        
        snapshot.appendSections([.notifications])
        snapshot.appendItems(notificationRows)
        appendSectionIfNonEmptyItems(section: .groupActions, with: groupActions)
        appendSectionIfNonEmptyItems(section: .destructiveGroupActions, with: destructiveGroupActions)
        
        apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: - Update content
    
    /// Freshly load the all the row items in the provided sections (and remove the section if there are no rows to show)
    ///
    /// If the you just want to refresh the items call `refresh(sections:)`.
    ///
    /// - Parameter sections: Sections to reload
    func reload(sections: [GroupDetails.Section]) {
        var localSnapshot = snapshot()
        
        func update(section: GroupDetails.Section, with items: [GroupDetails.Row]) {
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
            case .members:
                localSnapshot.appendItems(groupMembers(), toSection: .members)
                localSnapshot.reloadSections([.members])
            case .creator:
                localSnapshot.appendItems([creatorRow()], toSection: .creator)
            case .groupActions:
                update(section: .groupActions, with: groupActions)
            case .destructiveGroupActions:
                update(section: .destructiveGroupActions, with: destructiveGroupActions)
            default:
                fatalError("Unable to update section: \(section)")
            }
        }
        
        apply(localSnapshot)
    }
    
    /// Lightweight refresh of the provided sections
    /// - Parameter sections: Sections to refresh
    func refresh(sections: [GroupDetails.Section]) {
        var localSnapshot = snapshot()
        localSnapshot.reloadSections(sections)
        apply(localSnapshot)
    }
}

// MARK: - Quick Actions

extension GroupDetailsDataSource {
    
    func quickActions(in viewController: UIViewController) -> [QuickAction] {
        switch displayMode {
        case .default:
            return defaultQuickActions(in: viewController)
        case .conversation:
            return conversationQuickActions(in: viewController)
        }
    }
    
    private func defaultQuickActions(in viewController: UIViewController) -> [QuickAction] {
        var actions = [QuickAction]()
        
        // Only show message button if we're in the group
        if group.isSelfMember {
            let messageQuickAction = QuickAction(
                imageName: "threema.bubble.fill",
                title: BundleUtil.localizedString(forKey: "message"),
                accessibilityIdentifier: "GroupDetailsDataSourceMessageQuickActionButton"
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
        }
        
        actions.append(dndQuickAction(in: viewController))
        
        return actions
    }
    
    private func conversationQuickActions(in viewController: UIViewController) -> [QuickAction] {
        var conversationDetailsQuickActions = [QuickAction]()
        
        conversationDetailsQuickActions.append(dndQuickAction(in: viewController))
        conversationDetailsQuickActions.append(contentsOf: searchChatQuickAction(in: viewController, for: conversation))
        
        return conversationDetailsQuickActions
    }
    
    private func dndQuickAction(in viewController: UIViewController) -> QuickAction {
        let dndImageNameProvider: QuickAction.ImageNameProvider = { [weak self] in
            guard let strongSelf = self else {
                return "bell.fill"
            }
            
            let pushSetting = PushSetting(for: strongSelf.conversation)
            return pushSetting.sfSymbolNameForPushSetting
        }
                
        return QuickAction(
            imageNameProvider: dndImageNameProvider,
            title: BundleUtil.localizedString(forKey: "doNotDisturb_title"),
            accessibilityIdentifier: "GroupDetailsDataSourceDndQuickActionButton"
        ) { [weak self, weak viewController] quickAction in
            guard let strongSelf = self,
                  let strongViewController = viewController
            else {
                return
            }
            
            let dndViewController = DoNotDisturbViewController(for: strongSelf.group) { _ in
                quickAction.reload()
                strongSelf.refresh(sections: [.notifications])
            }
            
            let dndNavigationController = ThemedNavigationController(rootViewController: dndViewController)
            dndNavigationController.modalPresentationStyle = .formSheet
            
            strongViewController.present(dndNavigationController, animated: true)
        }
    }
    
    private func searchChatQuickAction(
        in viewController: UIViewController,
        for conversation: Conversation
    ) -> [QuickAction] {
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        guard messageFetcher.count() > 0 else {
            return []
        }
        
        guard let groupDetailsViewController = viewController as? GroupDetailsViewController else {
            return []
        }
        
        let quickAction = QuickAction(
            imageName: "magnifyingglass",
            title: BundleUtil.localizedString(forKey: "search"),
            accessibilityIdentifier: "GroupDetailsDataSourceSearchQuickActionButton"
        ) { [weak groupDetailsViewController] _ in
            groupDetailsViewController?.startChatSearch()
        }
        
        return [quickAction]
    }
}

// MARK: - Media & Polls Quick Actions

extension GroupDetailsDataSource {
    
    var mediaAndPollsQuickActions: [QuickAction] {
        var quickActions = [QuickAction]()
        
        guard let viewController = groupDetailsViewController else {
            return quickActions
        }
        
        if hasMedia(for: conversation) {
            quickActions.append(mediaQuickAction(for: conversation, in: viewController))
        }
        
        entityManager.performBlockAndWait {
            if self.entityManager.entityFetcher.countBallots(for: self.conversation) > 0 {
                quickActions.append(contentsOf: self.ballotsQuickAction(for: self.conversation, in: viewController))
            }
        }
        
        return quickActions
    }
    
    private func hasMedia(for conversation: Conversation) -> Bool {
        entityManager.entityFetcher.countMediaMessages(for: conversation) > 0
    }
    
    private func mediaQuickAction(for conversation: Conversation, in viewController: UIViewController) -> QuickAction {
        let localizedMediaString = BundleUtil.localizedString(forKey: "media_overview")
        
        return QuickAction(
            imageName: "photo.fill.on.rectangle.fill",
            title: localizedMediaString,
            accessibilityIdentifier: "GroupDetailsDataSourceMediaQuickActionButton"
        ) { _ in
            guard let photoBrowser = self.photoBrowserWrapper else {
                return
            }
            photoBrowser.openPhotoBrowser()
        }
    }
    
    private func ballotsQuickAction(
        for conversation: Conversation,
        in viewController: UIViewController
    ) -> [QuickAction] {
        let localizedBallotsString = BundleUtil.localizedString(forKey: "ballots")
        
        return [QuickAction(
            imageName: "chart.pie.fill",
            title: localizedBallotsString,
            accessibilityIdentifier: "GroupDetailsDataSourceBallotQuickActionButton"
        ) { [weak conversation, weak viewController] _ in
            guard let weakViewController = viewController else {
                return
            }
            
            guard let ballotViewController = BallotListTableViewController.ballotListViewController(for: conversation)
            else {
                UIAlertTemplate.showAlert(
                    owner: weakViewController,
                    title: BundleUtil.localizedString(forKey: "ballot_load_error"),
                    message: nil
                )
                return
            }
            
            // Encapsulate the `BallotListTableViewController` inside a navigation controller for modal
            // presentation
            let navigationController = ThemedNavigationController(rootViewController: ballotViewController)
            weakViewController.present(navigationController, animated: true)
        }]
    }
}

// MARK: - Sections

extension GroupDetailsDataSource {
    
    func groupMembers(limited: Bool = true) -> [GroupDetails.Row] {
        var rows = [GroupDetails.Row]()
        let numberOfInlineMembers = configuration.maxNumberOfMembersShownInline

        // Add members
        var sortedMembers = ArraySlice(group.sortedMembers)

        if limited {
            sortedMembers = sortedMembers.prefix(numberOfInlineMembers)
        }
        
        let creator = group.creator
        rows.append(contentsOf: sortedMembers.map { member in
            // Use creator row for creator
            guard member != creator else {
                return creatorRow(inMembers: true)
            }

            switch member {
            case .me:
                return .meContact
            case let .contact(contact):
                return .contact(contact, isSelfMember: group.isSelfMember)
            case .unknown:
                return .unknownContact
            }
        })
        
        // Show add members cell if editing is possible
        if group.canAddMembers {
            let localizedAddMembersButton = BundleUtil.localizedString(forKey: "group_manage_members_button")
            let addMembersAction = Details.Action(
                title: localizedAddMembersButton,
                imageName: "plus"
            ) { [weak self, weak groupDetailsViewController] cell in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController,
                      strongSelf.group.canAddMembers
                else {
                    return
                }
                
                let storyboard = UIStoryboard(name: "CreateGroup", bundle: nil)
                guard let pickGroupMembersViewController = storyboard
                    .instantiateViewController(
                        withIdentifier: "PickGroupMembersViewController"
                    ) as? PickGroupMembersViewController
                else {
                    DDLogWarn("Unable to load PickGroupMembersViewController from storyboard")
                    return
                }
                
                pickGroupMembersViewController.group = strongSelf.group
                
                let navigationViewController =
                    ThemedNavigationController(rootViewController: pickGroupMembersViewController)
                
                ModalPresenter.present(
                    navigationViewController,
                    on: strongGroupDetailsViewController,
                    from: cell.frame,
                    in: strongGroupDetailsViewController.view
                )
            }
            
            rows.append(.membersAction(addMembersAction))
        }
        
        return rows
    }
    
    private func creatorRow(inMembers: Bool = false) -> GroupDetails.Row {
        let left = group.didCreatorLeave || !group.isSelfMember
        switch group.creator {
        case .me:
            return .meCreator(left: left, inMembers: inMembers)
        case let .contact(contact):
            return .contactCreator(contact, left: left, inMembers: inMembers)
        case .unknown:
            return .unknownContactCreator(left: left, inMembers: inMembers)
        }
    }
    
    private var contentActions: [GroupDetails.Row] {
        var rows = [GroupDetails.Row]()
        
        if ConversationExporter.canExport(conversation: conversation, entityManager: entityManager) {
            let localizedExportConversationTitle = BundleUtil.localizedString(forKey: "export_chat")
            
            let exportConversationAction = Details.Action(
                title: localizedExportConversationTitle,
                imageName: "square.and.arrow.up"
            ) { [weak self, weak groupDetailsViewController] view in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
                
                let localizedTitle = BundleUtil.localizedString(forKey: "include_media_title")
                let localizedMessage = BundleUtil.localizedString(forKey: "include_media_message")
                let localizedIncludeMediaTitle = BundleUtil.localizedString(forKey: "include_media")
                let localizedExcludeMediaTitle = BundleUtil.localizedString(forKey: "without_media")
                
                func exportMediaAction(includeMedia: Bool) -> ((UIAlertAction) -> Void) {{ _ in
                    let exporter = ConversationExporter(
                        viewController: strongGroupDetailsViewController,
                        conversationObjectID: strongSelf.conversation.objectID,
                        withMedia: includeMedia
                    )
                    exporter.exportConversation()
                }}
                
                UIAlertTemplate.showSheet(
                    owner: strongGroupDetailsViewController,
                    popOverSource: view,
                    title: localizedTitle,
                    message: localizedMessage,
                    actions: [
                        UIAlertAction(
                            title: localizedIncludeMediaTitle,
                            style: .default,
                            handler: exportMediaAction(includeMedia: true)
                        ),
                        UIAlertAction(
                            title: localizedExcludeMediaTitle,
                            style: .default,
                            handler: exportMediaAction(includeMedia: false)
                        ),
                    ]
                )
            }
            rows.append(.action(exportConversationAction))
        }
        
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        if messageFetcher.count() > 0 {
            let localizedActionTitle = BundleUtil.localizedString(forKey: "messages_delete_all_button")
            
            let deleteAllContentAction = Details.Action(
                title: localizedActionTitle,
                imageName: "trash",
                destructive: true
            ) { [weak self, weak groupDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
                
                let localizedTitle = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_title")
                let localizedMessage = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_message")
                let localizedDelete = BundleUtil.localizedString(forKey: "delete")
                
                UIAlertTemplate.showDestructiveAlert(
                    owner: strongGroupDetailsViewController,
                    title: localizedTitle,
                    message: localizedMessage,
                    titleDestructive: localizedDelete,
                    actionDestructive: { _ in
                        if let tableView = strongSelf.tableView {
                            RunLoop.main.schedule {
                                let hud = MBProgressHUD(view: tableView)
                                hud.minShowTime = 1.0
                                hud.label.text = BundleUtil.localizedString(forKey: "delete_in_progress")
                                tableView.addSubview(hud)
                                hud.show(animated: true)
                            }
                        }
                        
                        strongGroupDetailsViewController.willDeleteAllMessages()
                        
                        strongSelf.entityManager.performBlock {
                            _ = strongSelf.entityManager.entityDestroyer
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
    
    private var notificationRows: [GroupDetails.Row] {
        var rows = [GroupDetails.Row]()
        
        let localizedDoNotDisturbTitle = BundleUtil.localizedString(forKey: "doNotDisturb_title")
        let doNotDisturbAction = Details
            .Action(title: localizedDoNotDisturbTitle) { [weak self, weak groupDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
            
                let dndViewController = DoNotDisturbViewController(
                    for: strongSelf.group,
                    willDismiss: { [weak self, weak groupDetailsViewController] _ in
                        self?.refresh(sections: [.notifications])
                        groupDetailsViewController?.reloadHeader()
                    }
                )
            
                let dndNavigationController = ThemedNavigationController(rootViewController: dndViewController)
                dndNavigationController.modalPresentationStyle = .formSheet
            
                strongGroupDetailsViewController.present(dndNavigationController, animated: true)
            }
        rows.append(.doNotDisturb(action: doNotDisturbAction, group: group))
        
        let localizedPlayNotificationSoundTitle = BundleUtil.localizedString(forKey: "notification_sound_title")
        let playSoundBooleanAction = Details.BooleanAction(
            title: localizedPlayNotificationSoundTitle,
            boolProvider: { [weak self] () -> Bool in
                guard let strongSelf = self else {
                    return true
                }
            
                let pushSetting = PushSetting(for: strongSelf.conversation)
                return !pushSetting.silent
            }
        ) { [weak self] isSet in
            guard let strongSelf = self else {
                return
            }
            
            let pushSetting = PushSetting(for: strongSelf.conversation)
            pushSetting.silent = !isSet
            pushSetting.save()
        }
        rows.append(.booleanAction(playSoundBooleanAction))
        
        return rows
    }
    
    private var groupActions: [GroupDetails.Row] {
        var rows = [GroupDetails.Row]()
        
        // Allow group sync if I'm the creator
        if group.isOwnGroup {
            let localizedSynchronizeGroupTitle = BundleUtil.localizedString(forKey: "group_sync_button")
            let synchronizeGroupAction = Details.Action(
                title: localizedSynchronizeGroupTitle,
                imageName: "arrow.triangle.2.circlepath"
            ) { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.groupManger.sync(group: strongSelf.group)
                    .done {
                        NotificationPresenterWrapper.shared.present(type: .groupSyncSuccess)
                    }
                    .catch { error in
                        DDLogError("Sync of group failed: \(error.localizedDescription)")
                        NotificationPresenterWrapper.shared.present(type: .groupSyncError)
                    }
            }
            rows.append(.action(synchronizeGroupAction))
        }
        
        // Only allow cloning if not disabled by mdm
        if let mdmSetup = mdmSetup, !mdmSetup.disableCreateGroup() {
            let localizedCloneGroupTitle = BundleUtil.localizedString(forKey: "group_clone_button")
            let cloneGroupAction = Details.Action(
                title: localizedCloneGroupTitle,
                imageName: "doc.on.doc"
            ) { [weak self, weak groupDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
                
                // Safety net if creating new groups got disabled in the meantime
                guard let mdmSetup = strongSelf.mdmSetup, !mdmSetup.disableCreateGroup() else {
                    let localizedDisabledByDevicePolicy = BundleUtil
                        .localizedString(forKey: "disabled_by_device_policy")
                    UIAlertTemplate.showAlert(
                        owner: strongGroupDetailsViewController,
                        title: localizedDisabledByDevicePolicy,
                        message: nil
                    )
                    return
                }
                
                // Confirm cloning
                
                let localizedGroupCloneTitle = BundleUtil.localizedString(forKey: "group_clone_title")
                let localizedGroupCloneMessage = BundleUtil.localizedString(forKey: "group_clone_message")
                let localizedGroupCloneActionButton = BundleUtil.localizedString(forKey: "group_clone_action_button")
                
                UIAlertTemplate.showAlert(
                    owner: strongGroupDetailsViewController,
                    title: localizedGroupCloneTitle,
                    message: localizedGroupCloneMessage,
                    titleOk: localizedGroupCloneActionButton,
                    actionOk: { _ in
                        let storyboard = UIStoryboard(name: "CreateGroup", bundle: nil)
                        guard let createGroupNavigationController = storyboard
                            .instantiateInitialViewController() as? CreateGroupNavigationController else {
                            fatalError("Unable to load CreateGroupNavigationController")
                        }
                        
                        createGroupNavigationController.cloneGroupID = strongSelf.group.groupID
                        createGroupNavigationController.cloneGroupCreator = strongSelf.group
                            .groupCreatorIdentity
                        
                        strongGroupDetailsViewController.present(createGroupNavigationController, animated: true)
                    }
                )
            }
            rows.append(.action(cloneGroupAction))
        }
        
        return rows
    }
    
    private var destructiveGroupActions: [GroupDetails.Row] {
        var rows = [GroupDetails.Row]()
        
        if group.canLeave {
            let localizedGroupTitle = BundleUtil.localizedString(forKey: "group_leave_button")
            let leaveAction = Details.Action(
                title: localizedGroupTitle,
                destructive: true
            ) { [weak self, weak groupDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
                
                var cell: UITableViewCell?
                if let indexPathForSelectedRow = strongSelf.tableView?.indexPathForSelectedRow {
                    cell = strongSelf.tableView?.cellForRow(at: indexPathForSelectedRow)
                }

                ConversationsViewControllerHelper.handleDeletion(
                    of: strongSelf.group.conversation,
                    owner: strongGroupDetailsViewController,
                    cell: cell,
                    entityManager: strongSelf.entityManager,
                    singleFunction: .leaveDissolve
                ) { _ in
                    DDLogVerbose("Left group")
                }
            }
            rows.append(.action(leaveAction))
        }
        else if group.canDissolve {
            let localizedGroupTitle = BundleUtil.localizedString(forKey: "group_dissolve_button")
            let dissolveAction = Details.Action(
                title: localizedGroupTitle,
                destructive: true
            ) { [weak self, weak groupDetailsViewController] _ in
                guard let strongSelf = self,
                      let strongGroupDetailsViewController = groupDetailsViewController
                else {
                    return
                }
                
                var cell: UITableViewCell?
                if let indexPathForSelectedRow = strongSelf.tableView?.indexPathForSelectedRow {
                    cell = strongSelf.tableView?.cellForRow(at: indexPathForSelectedRow)
                }

                ConversationsViewControllerHelper.handleDeletion(
                    of: strongSelf.group.conversation,
                    owner: strongGroupDetailsViewController,
                    cell: cell,
                    entityManager: strongSelf.entityManager,
                    singleFunction: .leaveDissolve
                ) { _ in
                    DDLogVerbose("Group was deleted")
                }
            }
            rows.append(.action(dissolveAction))
        }
        
        let localizedGroupTitle = BundleUtil.localizedString(forKey: "group_delete")
        let deleteAction = Details.Action(
            title: localizedGroupTitle,
            destructive: true
        ) { [weak self, weak groupDetailsViewController] _ in
            guard let strongSelf = self,
                  let strongGroupDetailsViewController = groupDetailsViewController
            else {
                return
            }
            
            var cell: UITableViewCell?
            if let indexPathForSelectedRow = strongSelf.tableView?.indexPathForSelectedRow {
                cell = strongSelf.tableView?.cellForRow(at: indexPathForSelectedRow)
            }
                        
            ConversationsViewControllerHelper.handleDeletion(
                of: strongSelf.group.conversation,
                owner: strongGroupDetailsViewController,
                cell: cell,
                entityManager: strongSelf.entityManager,
                singleFunction: .delete
            ) { _ in
                DDLogVerbose("Group was deleted")
            }
        }
        rows.append(.action(deleteAction))
        
        return rows
    }
}

// MARK: - Public members header configuration

extension GroupDetailsDataSource {
    var membersTitleSummary: String {
        group.membersTitleSummary
    }
    
    // This might be off by one compared to the number of contacts shown in the list as the creator
    // is always shown. Also when they left the group.
    var numberOfMembers: Int {
        group.numberOfMembers
    }
    
    var hasMoreMembersToShow: Bool {
        var numberOfGroupMembersWithCreator = group.numberOfMembers
        
        // Workaround as the creator is always shown in the members list (also when they left the
        // group). This is for consistency with the group `membersList` shown in `GroupCell`.
        if group.didCreatorLeave {
            numberOfGroupMembersWithCreator += 1
        }
        
        return numberOfGroupMembersWithCreator > configuration.maxNumberOfMembersShownInline
    }
    
    func showAllMembers(in viewController: UIViewController) {
        let groupMembersTableViewController = GroupMembersTableViewController(groupDetailsDataSource: self)
        
        viewController.show(groupMembersTableViewController, sender: viewController)
    }
}

// MARK: - MWPhotoBrowserWrapperDelegate

extension GroupDetailsDataSource: MWPhotoBrowserWrapperDelegate {
    func willDeleteMessages(with objectIDs: [NSManagedObjectID]) {
        groupDetailsViewController?.willDeleteMessages(with: objectIDs)
    }
}
