//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import DiffableDataSources
import PromiseKit

extension SingleDetailsDataSource {
    struct Configuration {
        /// Number of groups shown directly in details
        let maxNumberOfGroupsShownInline = 4
    }
}

final class SingleDetailsDataSource: TableViewDiffableDataSource<SingleDetails.Section, SingleDetails.Row> {
    
    // MARK: - Properties
    
    private let state: SingleDetails.State
    
    private let contact: Contact
    
    private weak var singleDetailsViewController: SingleDetailsViewController?
    private weak var tableView: UITableView?
    private let linkedContactManager: LinkedContactManger
    
    private lazy var entityManager = EntityManager()
    private lazy var groupManager = GroupManager()
    
    private lazy var photoBrowserWrapper: MWPhotoBrowserWrapper? = {
        if case let .conversationDetails(contact: _, conversation: conversation) = state,
           let viewController = singleDetailsViewController {
            return MWPhotoBrowserWrapper(for: conversation, in: viewController, entityManager: self.entityManager)
        }
        return nil
    }()
        
    lazy var sortedGroupMembershipConversations = contact.groupConversations?
        .compactMap { $0 as? Conversation }
        .sortedDescendingByLastUpdatedDate()
    
    private let configuration = Configuration()
    
    // MARK: - Lifecycle
    
    init(
        state: SingleDetails.State,
        singleDetailsViewController: SingleDetailsViewController,
        tableView: UITableView,
        linkedContactManager: LinkedContactManger
    ) {
        self.singleDetailsViewController = singleDetailsViewController
        self.tableView = tableView
        self.state = state
        self.linkedContactManager = linkedContactManager
        
        switch state {
        case let .contactDetails(contact):
            self.contact = contact
        case let .conversationDetails(contact, _):
            self.contact = contact
        }
        
        super.init(tableView: tableView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        tableView: UITableView,
        cellProvider: @escaping TableViewDiffableDataSource<SingleDetails.Section, SingleDetails.Row>.CellProvider
    ) {
        fatalError("Just use init(tableView:).")
    }
    
    func registerHeaderAndCells() {
        tableView?.registerHeaderFooter(DetailsSectionHeaderView.self)
        
        tableView?.registerCell(ActionDetailsTableViewCell.self)
        tableView?.registerCell(ValueDetailsTableViewCell.self)
        tableView?.registerCell(VerificationLevelDetailsTableViewCell.self)
        tableView?.registerCell(LinkedContactDetailsTableViewCell.self)
        tableView?.registerCell(PublicKeyDetailsTableViewCell.self)
        tableView?.registerCell(DoNotDisturbDetailsTableViewCell.self)
        tableView?.registerCell(SwitchDetailsTableViewCell.self)
        tableView?.registerCell(GroupCell.self)
        tableView?.registerCell(PrivacySettingsTableViewCell.self)
    }
    
    private let cellProvider: SingleDetailsDataSource.CellProvider = { tableView, indexPath, row in
        
        switch row {
        
        case let .action(action):
            let actionCell: ActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            actionCell.action = action
            return actionCell
            
        case let .booleanAction(action):
            let switchCell: SwitchDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            switchCell.action = action
            return switchCell
            
        case let .value(label: label, value: value):
            let cell: ValueDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.label = label
            cell.value = value
            return cell
            
        case let .verificationLevel(contact):
            let verificationLevelCell: VerificationLevelDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            verificationLevelCell.contact = contact
            return verificationLevelCell
            
        case .publicKey:
            let cell: PublicKeyDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            return cell
            
        case let .linkedContact(linkedContactManger):
            let linkedContactCell: LinkedContactDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            linkedContactCell.linkedContactManger = linkedContactManger
            return linkedContactCell
                        
        case let .group(group):
            let groupCell: GroupCell = tableView.dequeueCell(for: indexPath)
            groupCell.size = .medium
            groupCell.group = group
            groupCell.accessoryType = .disclosureIndicator
            return groupCell
            
        case let .doNotDisturb(action, contact):
            let dndCell: DoNotDisturbDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
            dndCell.action = action
            dndCell.type = .contact(contact)
            return dndCell
            
        case let .privacySettings(action, contact):
            let privacySettingsCell: PrivacySettingsTableViewCell = tableView.dequeueCell(for: indexPath)
            privacySettingsCell.contact = contact
            privacySettingsCell.action = action
            return privacySettingsCell
        }
    }
    
    // MARK: - Configure content
    
    /// This only should be called once. We'll register an observer for every call
    func configureData() {
        var snapshot = DiffableDataSourceSnapshot<SingleDetails.Section, SingleDetails.Row>()
        
        if case let .conversationDetails(contact: _, conversation: conversation) = state {
            // This is the only table view section that is not shown in contact details
            snapshot.appendSections([.contentActions])
            snapshot.appendItems(contentActions(for: conversation))
        }
        
        appendDefaultSection(to: &snapshot)
        
        apply(snapshot, animatingDifferences: false)
    }
    
    // Sections are shown independent of `state`
    private func appendDefaultSection(to snapshot: inout DiffableDataSourceSnapshot<
        SingleDetails.Section,
        SingleDetails.Row
    >) {
        
        // Only add a section if there are any rows to show
        func appendSectionIfNonEmptyItems(section: SingleDetails.Section, with items: [SingleDetails.Row]) {
            guard !items.isEmpty else {
                return
            }
            
            snapshot.appendSections([section])
            snapshot.appendItems(items)
        }
        
        snapshot.appendSections([.contactInfo])
        snapshot.appendItems(contactInfo)
        appendSectionIfNonEmptyItems(section: .groups, with: groupRows)
        snapshot.appendSections([.notifications])
        snapshot.appendItems(notificationRows)
        snapshot.appendSections([.privacySettings])
        snapshot.appendItems(privacySettingsActions)
        snapshot.appendSections([.shareAction])
        snapshot.appendItems(shareRows)
        snapshot.appendSections([.contactActions])
        snapshot.appendItems(contactActions)
    }
    
    // MARK: - Update content
    
    /// Reload the passed sections
    ///
    /// For sections that do not exist nothing happens. Others are updated or removed if they have no more items.
    ///
    /// - Parameter sections: Sections to reload
    func reload(sections: [SingleDetails.Section]) {
        var localSnapshot = snapshot()
        
        func update(section: SingleDetails.Section, with items: [SingleDetails.Row]) {
            if items.isEmpty {
                localSnapshot.deleteSections([section])
            }
            else {
                localSnapshot.appendItems(items, toSection: section)
            }
        }
        
        for section in sections {
            guard localSnapshot.sectionIdentifiers.contains(section) else {
                continue
            }
            
            let existingItems = localSnapshot.itemIdentifiers(inSection: section)
            localSnapshot.deleteItems(existingItems)
            
            switch section {
            case .contentActions:
                guard case let .conversationDetails(contact: _, conversation: conversation) = state else {
                    continue
                }
                localSnapshot.appendItems(contentActions(for: conversation), toSection: .contentActions)
            case .contactInfo:
                localSnapshot.appendItems(contactInfo, toSection: .contactInfo)
            case .groups:
                update(section: .groups, with: groupRows)
            case .notifications:
                localSnapshot.appendItems(notificationRows, toSection: .notifications)
            case .contactActions:
                localSnapshot.appendItems(contactActions, toSection: .contactActions)
            case .privacySettings:
                localSnapshot.appendItems(privacySettingsActions, toSection: .privacySettings)
            default:
                fatalError("Unable to update section: \(section)")
            }
        }
        
        apply(localSnapshot)
    }
    
    func refresh(sections: [SingleDetails.Section]) {
        var localSnapshot = snapshot()
        localSnapshot.reloadSections(sections)
        apply(localSnapshot)
    }
    
    // MARK: - Footer helper text
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = snapshot().sectionIdentifiers[section]
        
        // If contacts can be picked to receive profile pictures there is some helper text
        if section == .privacySettings,
           contact.canBePickedAsProfilePictureRecipient {
            
            if contact.isProfilePictureRecipient {
                return BundleUtil.localizedString(forKey: "contact_added_to_profile_picture_list")
            }
            else {
                return BundleUtil.localizedString(forKey: "contact_removed_from_profile_picture_list")
            }
        }
        
        return nil
    }
}

// MARK: - Quick Actions

extension SingleDetailsDataSource {
    
    func quickActions(in viewController: UIViewController) -> [QuickAction] {
        switch state {
        case .contactDetails(contact: _):
            return contactQuickActions(in: viewController)
        case .conversationDetails(contact: _, conversation: _):
            return conversationQuickActions(in: viewController)
        }
    }
    
    private func contactQuickActions(in viewController: UIViewController) -> [QuickAction] {
        
        let localizesMessageTitle = BundleUtil.localizedString(forKey: "message")
        
        var contactDetailsQuickActions = [
            QuickAction(imageName: "threema.bubble.fill", title: localizesMessageTitle) { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationShowConversation),
                    object: nil,
                    userInfo: [
                        kKeyContact: strongSelf.contact,
                        kKeyForceCompose: true,
                    ]
                )
            },
        ]
        
        contactDetailsQuickActions.append(contentsOf: callQuickAction(in: viewController))
        contactDetailsQuickActions.append(contentsOf: scanIdentityQuickAction(in: viewController))
        
        return contactDetailsQuickActions
    }
    
    private func conversationQuickActions(in viewController: UIViewController) -> [QuickAction] {
        var conversationDetailsQuickActions = [QuickAction]()
        
        conversationDetailsQuickActions.append(doNotDisturbQuickAction(in: viewController))
        conversationDetailsQuickActions.append(contentsOf: callQuickAction(in: viewController))
        conversationDetailsQuickActions.append(contentsOf: scanIdentityQuickAction(in: viewController))
        
        return conversationDetailsQuickActions
    }
    
    private func callQuickAction(in viewController: UIViewController) -> [QuickAction] {
        // Only show call icon if Threema calls are enabled
        guard UserSettings.shared()?.enableThreemaCall == true,
              !contact.isGatewayID(), !contact.isEchoEcho() else {
            return []
        }
        
        // Can we synchronously test here if this contact supports calls (without updating the
        // feature mask) instead of checking when the action is actually triggered?
        let quickAction = QuickAction(
            imageName: "threema.phone.fill",
            title: BundleUtil.localizedString(forKey: "call")
        ) { [weak self, weak viewController] _ in
            guard let strongSelf = self else {
                return
            }
            
            // Check feature mask
            let contactSet = Set<Contact>([strongSelf.contact])
            FeatureMask
                .check(
                    Int(FEATURE_MASK_VOIP),
                    forContacts: contactSet
                ) { [weak self, weak viewController] unsupportedContacts in
                
                    if let strongSelf = self, unsupportedContacts?.isEmpty == true {
                        // Happy path: Start call
                        let action = VoIPCallUserAction(
                            action: .call,
                            contactIdentity: strongSelf.contact.identity,
                            callID: nil,
                            completion: nil
                        )
                        VoIPCallStateManager.shared.processUserAction(action)
                    }
                    else if let viewController = viewController {
                        // Calls not supported for this contact
                        UIAlertTemplate.showAlert(
                            owner: viewController,
                            title: BundleUtil.localizedString(forKey: "call_voip_not_supported_title"),
                            message: BundleUtil.localizedString(forKey: "call_voip_not_supported_text")
                        )
                    }
                    else {
                        DDLogWarn("Unable to show error for not supported Threema Calls")
                    }
                }
        }
        
        return [quickAction]
    }
    
    private func doNotDisturbQuickAction(in viewController: UIViewController) -> QuickAction {
        
        let dndImageNameProvider: QuickAction.ImageNameProvider = { [weak self] in
            guard let strongSelf = self else {
                return "bell.fill"
            }
            
            let pushSetting = PushSetting(for: strongSelf.contact)
            return pushSetting.sfSymbolNameForPushSetting
        }
        
        return QuickAction(
            imageNameProvider: dndImageNameProvider,
            title: BundleUtil.localizedString(forKey: "doNotDisturb_title")
        ) { [weak self, weak viewController] quickAction in
            guard let strongSelf = self,
                  let strongViewController = viewController
            else {
                return
            }
            
            let dndViewController = DoNotDisturbViewController(for: strongSelf.contact) { _ in
                quickAction.reload()
                strongSelf.reload(sections: [.notifications])
            }
            let dndNavigationController = ThemedNavigationController(rootViewController: dndViewController)
            dndNavigationController.modalPresentationStyle = .formSheet
            
            strongViewController.present(dndNavigationController, animated: true)
        }
    }
    
    private func scanIdentityQuickAction(in viewController: UIViewController) -> [QuickAction] {
        // If not fully verified and camera is available: show scan quick action
        guard ScanIdentityController.canScan(),
              !(
                  contact.verificationLevel.intValue == kVerificationLevelFullyVerified || contact.verificationLevel
                      .intValue == kVerificationLevelWorkFullyVerified
              ) else {
            return []
        }
        
        let quickAction = QuickAction(
            imageName: "qrcode.viewfinder",
            title: BundleUtil.localizedString(forKey: "scan")
        ) { [weak self, weak viewController] quickAction in
            guard let strongSelf = self,
                  let strongViewController = viewController
            else {
                return
            }
            
            let scanController = ScanIdentityController()
            scanController.containingViewController = strongViewController
            scanController.expectedIdentity = strongSelf.contact.identity
            
            scanController.completion = { isFullyVerified in
                guard isFullyVerified else {
                    return
                }
                
                quickAction.hide()
                // The header height will automatically update, because the verification level changed
            }
            
            scanController.startScan()
        }
        
        return [quickAction]
    }
}

// MARK: - Media & Polls Quick Actions

extension SingleDetailsDataSource {
    
    var mediaAndPollsQuickActions: [QuickAction] {
        var quickActions = [QuickAction]()
        
        guard let viewController = singleDetailsViewController else {
            return quickActions
        }
        
        guard case let .conversationDetails(contact: _, conversation: conversation) = state else {
            return quickActions
        }
        
        if hasMedia(for: conversation) {
            quickActions.append(mediaQuickAction(for: conversation, in: viewController))
        }
        
        // TODO: Implement!
        // quickActions.append(contentsOf: ballotsQuickAction(for: conversation, in: viewController))
        
        return quickActions
    }
    
    private func hasMedia(for conversation: Conversation) -> Bool {
        entityManager.entityFetcher.countMediaMessages(for: conversation) > 0
    }
    
    private func mediaQuickAction(for conversation: Conversation, in viewController: UIViewController) -> QuickAction {
        let localizedMediaString = BundleUtil.localizedString(forKey: "media_overview")
        
        return QuickAction(
            imageName: "photo.fill.on.rectangle.fill",
            title: localizedMediaString
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
        guard entityManager.entityFetcher.countBallots(for: conversation) > 0 else {
            return []
        }
        
        // This will fix itself when "IOS-1683" is implemented
        let localizedBallotsString = BundleUtil.localizedString(forKey: "ballots")
        
        return [QuickAction(
            imageName: "chart.pie.fill",
            title: localizedBallotsString
        ) { [weak conversation, weak viewController] _ in
            guard let weakViewController = viewController else {
                return
            }
            
            guard let ballotViewController = BallotListTableViewController.ballotListViewController(for: conversation)
            else {
                // TODO: Localize String
                UIAlertTemplate.showAlert(owner: weakViewController, title: "Polls unavailable", message: nil)
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

extension SingleDetailsDataSource {
    
    private func contentActions(for conversation: Conversation) -> [SingleDetails.Row] {
        var rows = [SingleDetails.Row]()
        
        if ConversationExporter.canExport(conversation: conversation, entityManager: entityManager) {
            let localizedExportConversationActionTitle = BundleUtil.localizedString(forKey: "export_chat")
            
            let exportConversationAction = Details.Action(
                title: localizedExportConversationActionTitle,
                imageName: "square.and.arrow.up"
            ) { [weak self, weak singleDetailsViewController, weak conversation] view in
                guard let strongSelf = self,
                      let strongSingleDetailsViewController = singleDetailsViewController,
                      let conversation = conversation
                else {
                    return
                }
                
                let localizedTitle = BundleUtil.localizedString(forKey: "include_media_title")
                let localizedMessage = BundleUtil.localizedString(forKey: "include_media_message")
                let localizedIncludeMediaTitle = BundleUtil.localizedString(forKey: "include_media")
                let localizedExcludeMediaTitle = BundleUtil.localizedString(forKey: "without_media")
                
                func exportMediaAction(includeMedia: Bool) -> ((UIAlertAction) -> Void) {{ _ in
                    let exporter = ConversationExporter(
                        viewController: strongSingleDetailsViewController,
                        conversation: conversation,
                        entityManager: strongSelf.entityManager,
                        withMedia: includeMedia
                    )
                    exporter.exportConversation()
                }}
                
                UIAlertTemplate.showSheet(
                    owner: strongSingleDetailsViewController,
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
            ) { [weak self, weak singleDetailsViewController, weak conversation] _ in
                guard let strongSelf = self,
                      let strongSingleDetailsViewController = singleDetailsViewController,
                      let conversation = conversation
                else {
                    return
                }
                
                let localizedTitle = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_title")
                let localizedMessage = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_message")
                let localizedDelete = BundleUtil.localizedString(forKey: "delete")
                
                UIAlertTemplate.showDestructiveAlert(
                    owner: strongSingleDetailsViewController,
                    title: localizedTitle,
                    message: localizedMessage,
                    titleDestructive: localizedDelete,
                    actionDestructive: { _ in
                        strongSelf.entityManager.performSyncBlockAndSafe {
                            _ = strongSelf.entityManager.entityDestroyer
                                .deleteMessages(of: conversation)
                            conversation.lastMessage = nil
                            strongSelf.reload(sections: [.contentActions])
                        }
                    }
                )
            }
            rows.append(.action(deleteAllContentAction))
        }
        
        return rows
    }
    
    private var contactInfo: [SingleDetails.Row] {
        var rows = [SingleDetails.Row]()
        
        let localizedThreemaID = BundleUtil.localizedString(forKey: "threema_id")
        rows.append(.value(label: localizedThreemaID, value: contact.identity))
        rows.append(.verificationLevel(contact: contact))
        rows.append(.publicKey)
        
        if let nickname = contact.publicNickname, !nickname.isEmpty {
            let localizedNickname = BundleUtil.localizedString(forKey: "nickname")
            rows.append(.value(label: localizedNickname, value: nickname))
        }
        
        if !contact.isGatewayID() {
            rows.append(.linkedContact(linkedContactManager))
        }
        
        return rows
    }
    
    private var groupRows: [SingleDetails.Row] {
        if sortedGroupMembershipConversations == nil {
            sortedGroupMembershipConversations = [Conversation]()
        }
        return sortedGroupMembershipConversations!
            // Only take the some groups at the beginning
            .prefix(configuration.maxNumberOfGroupsShownInline)
            // Convert `Conversation` to `Group`
            .compactMap(groupManager.getGroup(conversation:))
            // Convert `Group` to `Row`s
            .map(SingleDetails.Row.group)
    }
    
    private var notificationRows: [SingleDetails.Row] {
        var rows = [SingleDetails.Row]()
        
        let localizedDoNotDisturbTitle = BundleUtil.localizedString(forKey: "doNotDisturb_title")
        let doNotDisturbAction = Details.Action(
            title: localizedDoNotDisturbTitle
        ) { [weak self, weak singleDetailsViewController] _ in
            guard let strongSelf = self,
                  let strongSingleDetailsViewController = singleDetailsViewController
            else {
                return
            }
            
            let dndViewController = DoNotDisturbViewController(
                for: strongSelf.contact,
                willDismiss: { [weak self, weak singleDetailsViewController] _ in
                    self?.refresh(sections: [.notifications])
                    singleDetailsViewController?.reloadHeader()
                }
            )
            
            let dndNavigationController = ThemedNavigationController(rootViewController: dndViewController)
            dndNavigationController.modalPresentationStyle = .formSheet
            
            strongSingleDetailsViewController.present(dndNavigationController, animated: true)
        }
        rows.append(.doNotDisturb(action: doNotDisturbAction, contact: contact))
        
        let localizedPlayNotificationSoundTitle = BundleUtil.localizedString(forKey: "notification_sound_title")
        let playSoundBooleanAction = Details.BooleanAction(
            title: localizedPlayNotificationSoundTitle,
            boolProvider: { [weak self] () -> Bool in
                guard let strongSelf = self else {
                    return true
                }
            
                let pushSetting = PushSetting(for: strongSelf.contact)
                return !pushSetting.silent
            }
        ) { [weak self] isSet in
            guard let strongSelf = self else {
                return
            }
            
            let pushSetting = PushSetting(for: strongSelf.contact)
            pushSetting.silent = !isSet
            pushSetting.save()
        }
        rows.append(.booleanAction(playSoundBooleanAction))
        
        return rows
    }
    
    private var shareRows: [SingleDetails.Row] {
        let shareAction = Details.Action(
            title: BundleUtil.localizedString(forKey: "share_contact_id_button")
        ) { [weak self, weak singleDetailsViewController] cell in
            guard let strongSelf = self,
                  let strongSingleDetailsViewController = singleDetailsViewController
            else {
                return
            }
            
            let identity = strongSelf.contact.identity
            
            // Pick up activity items
            var activityItems = [Any]()
            
            let contactShareLink = "\(THREEMA_ID_SHARE_LINK)\(identity)"
            if let url = URL(string: contactShareLink) {
                activityItems.append(url)
            }
            else {
                activityItems.append(contactShareLink)
            }
            
            activityItems.append(strongSelf.contact.displayName)
            
            // Create our Share Sheet
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // Show
            ModalPresenter.present(
                activityViewController,
                on: strongSingleDetailsViewController,
                from: cell.frame,
                in: strongSingleDetailsViewController.view
            )
        }
        
        return [.action(shareAction)]
    }
    
    private var contactActions: [SingleDetails.Row] {
        
        let blockContactBooleanAction = Details.BooleanAction(
            title: BundleUtil.localizedString(forKey: "block_contact"),
            destructive: true,
            boolProvider: { [weak self] in
                self?.contact.isBlocked ?? false
            }, action: { [weak self, weak singleDetailsViewController] isSet in
                guard let strongSelf = self,
                      let strongSingleDetailsViewController = singleDetailsViewController
                else {
                    return
                }
                
                strongSelf.contact.block(isSet, in: strongSingleDetailsViewController)
                    .catch { error in
                        DDLogWarn("Unable to block contact: \(error.localizedDescription)")
                        
                        // Reset block state if we could not save the current state
                        strongSelf.refresh(sections: [.contactActions])
                    }
            }
        )
        
        let deleteContactAction = Details.Action(
            title: BundleUtil.localizedString(forKey: "delete_contact_button"),
            imageName: nil,
            destructive: true
        ) { [weak self, weak singleDetailsViewController] view in
            guard let strongSelf = self,
                  let strongSingleDetailsViewController = singleDetailsViewController
            else {
                return
            }
            
            let action = DeleteContactAction(for: strongSelf.contact)
            action.execute(in: view, of: strongSingleDetailsViewController)
        }
        
        return [
            .booleanAction(blockContactBooleanAction),
            .action(deleteContactAction),
        ]
    }
    
    private var privacySettingsActions: [SingleDetails.Row] {
        var rows = [SingleDetails.Row]()
        
        let readReceiptsAction = Details.Action(
            title: BundleUtil
                .localizedString(forKey: "send_readReceipts")
        ) { [weak self, weak singleDetailsViewController] view in
            guard let strongSelf = self,
                  let strongSingleDetailsViewController = singleDetailsViewController
            else {
                return
            }
            
            var defaultString = ""
            
            if UserSettings.shared().sendReadReceipts {
                defaultString = BundleUtil.localizedString(forKey: "send")
            }
            else {
                defaultString = BundleUtil.localizedString(forKey: "dont_send")
            }
            
            let action1 = UIAlertAction(title: BundleUtil.localizedString(forKey: "send"), style: .default) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.readReceipt = .send
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            let action2 = UIAlertAction(title: BundleUtil.localizedString(forKey: "dont_send"), style: .default) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.readReceipt = .doNotSend
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            let action3 = UIAlertAction(
                title: String(format: BundleUtil.localizedString(forKey: "use_default_send"), defaultString),
                style: .default
            ) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.readReceipt = .default
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            UIAlertTemplate.showSheet(
                owner: strongSingleDetailsViewController,
                popOverSource: view,
                title: BundleUtil.localizedString(forKey: "send_readReceipts"),
                message: BundleUtil.localizedString(forKey: "readReceipt_sheetMessage"),
                actions: [action3, action1, action2],
                cancelTitle: BundleUtil.localizedString(forKey: "cancel"),
                cancelAction: nil
            )
        }
        rows.append(.privacySettings(action: readReceiptsAction, contact: contact))
        
        let typingIndicatorsAction = Details.Action(
            title: BundleUtil
                .localizedString(forKey: "send_typingIndicator")
        ) { [weak self, weak singleDetailsViewController] view in
            guard let strongSelf = self,
                  let strongSingleDetailsViewController = singleDetailsViewController
            else {
                return
            }
            
            var defaultString = ""
            
            if UserSettings.shared().sendTypingIndicator {
                defaultString = BundleUtil.localizedString(forKey: "send")
            }
            else {
                defaultString = BundleUtil.localizedString(forKey: "dont_send")
            }
            
            let action1 = UIAlertAction(title: BundleUtil.localizedString(forKey: "send"), style: .default) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.typingIndicator = .send
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            let action2 = UIAlertAction(title: BundleUtil.localizedString(forKey: "dont_send"), style: .default) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.typingIndicator = .doNotSend
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            let action3 = UIAlertAction(
                title: String(format: BundleUtil.localizedString(forKey: "use_default_send"), defaultString),
                style: .default
            ) { _ in
                strongSelf.entityManager.performSyncBlockAndSafe {
                    strongSelf.contact.typingIndicator = .default
                    strongSelf.refresh(sections: [.privacySettings])
                }
            }
            
            UIAlertTemplate.showSheet(
                owner: strongSingleDetailsViewController,
                popOverSource: view,
                title: BundleUtil.localizedString(forKey: "send_typingIndicator"),
                message: BundleUtil.localizedString(forKey: "typingIndicator_sheetMessage"),
                actions: [action3, action1, action2],
                cancelTitle: BundleUtil.localizedString(forKey: "cancel"),
                cancelAction: nil
            )
        }
        rows.append(.privacySettings(action: typingIndicatorsAction, contact: contact))
        
        if contact.canBePickedAsProfilePictureRecipient {
            let identity = contact.identity
            
            let sendProfilePictureBooleanAction = Details.BooleanAction(
                title: BundleUtil.localizedString(forKey: "profile_picture_recipient"),
                boolProvider: { [weak self] in
                    self?.contact.isProfilePictureRecipient ?? false
                },
                action: { [weak self] isSet in
                    let profilePictureContactList = NSMutableOrderedSet(
                        array: UserSettings.shared()
                            .profilePictureContactList
                    )
                    
                    if isSet {
                        profilePictureContactList.add(identity)
                    }
                    else {
                        profilePictureContactList.remove(identity)
                    }
                    
                    UserSettings.shared()?.profilePictureContactList = profilePictureContactList.array
                    
                    self?.reload(sections: [.privacySettings])
                }
            )
            rows.append(.booleanAction(sendProfilePictureBooleanAction))
        }
        
        if contact.isProfilePictureRecipient {
            let sendPictureNowAction = Details.Action(
                title: BundleUtil.localizedString(forKey: "send_profile_picture")
            ) { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                ContactPhotoSender(BusinessInjector().entityManager).startWithImage(toMember: strongSelf.contact) {
                    NotificationBannerHelper.newInfoToast(
                        title: BundleUtil.localizedString(forKey: "my_profile_picture_title"),
                        body: BundleUtil.localizedString(forKey: "contact_send_profile_picture_success")
                    )
                } onError: { error in
                    DDLogError("Unable to send profile picture on user request: \(error?.localizedDescription ?? "")")
                    
                    NotificationBannerHelper.newErrorToast(
                        title: BundleUtil.localizedString(forKey: "my_profile_picture_title"),
                        body: BundleUtil.localizedString(forKey: "contact_send_profile_picture_error")
                    )
                }
            }
            rows.append(.action(sendPictureNowAction))
        }
        
        return rows
    }
}

// MARK: - Public group header configuration

extension SingleDetailsDataSource {
    var numberOfGroups: Int {
        guard let conversations = sortedGroupMembershipConversations else {
            return 0
        }
        return conversations.count
    }
    
    var hasMoreGroupsToShow: Bool {
        guard let conversations = sortedGroupMembershipConversations else {
            return false
        }
        return conversations.count > configuration.maxNumberOfGroupsShownInline
    }
    
    func showAllGroups(in viewController: UIViewController) {
        
        var groups = sortedGroupMembershipConversations?
            .compactMap(groupManager.getGroup(conversation:))
        
        if groups == nil {
            groups = [Group]()
        }
        
        let groupsTableViewController = GroupsTableViewController(groups: groups!)
        
        viewController.show(groupsTableViewController, sender: viewController)
    }
}

// MARK: - Contact+ProfilePicture & Contact+block

private extension Contact {
    var canBePickedAsProfilePictureRecipient: Bool {
        guard !(isEchoEcho() || isGatewayID()) else {
            return false
        }
        
        return UserSettings.shared().sendProfilePicture == SendProfilePictureContacts
    }
    
    var isProfilePictureRecipient: Bool {
        guard !(isEchoEcho() || isGatewayID()) else {
            return false
        }
        
        guard let sharedUserSettings = UserSettings.shared() else {
            return false
        }
        
        // If we send the profile picture to everyone we can send it
        if sharedUserSettings.sendProfilePicture == SendProfilePictureAll {
            return true
        }
        
        // If we only send it to selected contacts the contact needs to be in the list
        if sharedUserSettings.sendProfilePicture == SendProfilePictureContacts {
            return isInProfilePictureContactList
        }
        
        return false
    }
    
    private var isInProfilePictureContactList: Bool {
        UserSettings.shared().profilePictureContactList.contains { element in
            guard let elementID = element as? String else {
                return false
            }
            
            return elementID == identity
        }
    }
    
    func block(_ block: Bool, in viewController: UIViewController) -> Promise<Void> {
        Promise { seal in
            let settingsStore = SettingsStore()
            var settings = settingsStore.settings
            
            if block {
                settings.blacklist.insert(identity)
            }
            else {
                settings.blacklist.remove(identity)
            }
            
            let progressString = BundleUtil.localizedString(forKey: "syncing_settings")
            let syncHelper = UISyncHelper(viewController: viewController, progressString: progressString)
            
            syncHelper.execute(settings: settings)
                .done {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationBlockedContact),
                        object: self.identity
                    )
                    seal.fulfill_()
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }
}

// MARK: - Custom sorting for (group) conversations

private extension Array where Element: Conversation {
    /// Sort by last updated date of conversation (descending)
    /// - Returns: Sorted `Conversation` array
    func sortedDescendingByLastUpdatedDate() -> Array {
        sorted { firstConversation, secondConversation in
            let firstOptionalDate = firstConversation.lastUpdate
            let secondOptionalDate = secondConversation.lastUpdate
            
            guard let firstDate = firstOptionalDate else {
                if secondOptionalDate == nil {
                    // It doesn't matter how they are sorted
                    return true
                }
                else {
                    // Second date is more recent
                    return false
                }
            }
            
            guard let secondDate = secondOptionalDate else {
                // First date is more recent
                return true
            }
            
            return firstDate > secondDate
        }
    }
}
