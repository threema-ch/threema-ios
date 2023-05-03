//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

final class StorageManagementConversationViewController: ThemedCodeModernGroupedTableViewController {
        
    init(conversation: Conversation, businessInjector: BusinessInjectorProtocol) {
        self.conversation = conversation
        self.businessInjector = businessInjector
        
        super.init()
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Private types

    private var conversation: Conversation?
    private var businessInjector: BusinessInjectorProtocol?
    
    private enum Section: Hashable {
        case messages
        case files
    }
    
    private enum Row: Hashable {
        case valueAllConversations(celltype: StorageConversationSMTableViewCell.CellType)
        case valueConversation(conversation: Conversation, celltype: StorageConversationSMTableViewCell.CellType)
        case action(action: Details.Action)
    }
    
    private lazy var headerView: DetailsHeaderView? = {
        guard let conversation = conversation else {
            return nil
        }

        let contentConfiguration = DetailsHeaderProfileView.ContentConfiguration(
            avatarImageProvider: avatarImageProvider(completion:),
            name: conversation.isGroup() ? conversation.groupName ?? "" : conversation.contact?.displayName ?? ""
        )
        return DetailsHeaderView(with: contentConfiguration) {
            // do nothing
        }
    }()
    
    private func avatarImageProvider(completion: @escaping (UIImage?) -> Void) {
        AvatarMaker.shared().avatar(
            for: conversation,
            size: DetailsHeaderProfileView.avatarImageSize,
            masked: true
        ) { avatarImage, _ in
            DispatchQueue.main.async {
                completion(avatarImage)
            }
        }
    }
    
    /// Simple subclass to provide easy header and footer string configuration
    private class DataSource: UITableViewDiffableDataSource<Section, Row> {
        typealias SupplementaryProvider = (UITableView, Section) -> String?
        
        let headerProvider: SupplementaryProvider
        let footerProvider: SupplementaryProvider
        
        init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider,
            headerProvider: @escaping SupplementaryProvider,
            footerProvider: @escaping SupplementaryProvider
        ) {
            self.headerProvider = headerProvider
            self.footerProvider = footerProvider
            
            super.init(tableView: tableView, cellProvider: cellProvider)
        }
        
        @available(*, unavailable)
        override init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider
        ) {
            fatalError("Not supported.")
        }
        
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return headerProvider(tableView, section)
        }
        
        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return footerProvider(tableView, section)
        }
    }
        
    // MARK: - Properties
    
    private lazy var dataSource = DataSource(
        tableView: tableView,
        cellProvider: { [weak self] tableView, indexPath, row -> UITableViewCell? in
            guard let strongSelf = self else {
                return nil
            }
            
            switch row {
            case let .valueAllConversations(celltype: celltype):
                let cell: StorageConversationSMTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.setup(cellType: celltype)
                return cell
            case let .valueConversation(conversation: conversation, celltype: celltype):
                let cell: StorageConversationSMTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.setup(conversation: conversation, cellType: celltype)
                return cell
            case let .action(action):
                let actionCell: ActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
                actionCell.action = action
                return actionCell
            }
        },
        headerProvider: { [weak self] _, _ -> String? in
            guard let strongSelf = self else {
                return nil
            }
        
            return nil
        
        },
        footerProvider: { [weak self] _, section -> String? in
            guard let strongSelf = self else {
                return nil
            }
                    
            switch section {
            case .messages:
                return BundleUtil.localizedString(forKey: "delete_messages_explain")
            case .files:
                return BundleUtil.localizedString(forKey: "delete_explain")
            }
        }
    )
            
    // MARK: - Lifecycle
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureNavigationBar()
        configureTableView()
        registerCells()
        configureHeaderView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateContent()
        
        // Call it here to ensure we have the correct constraints
        updateHeaderLayout(animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewLayoutMarginsDidChange() {
        super.viewLayoutMarginsDidChange()
        
        guard let headerView = headerView else {
            return
        }
        
        // WORKAROUND: See `configureHeaderView()` for details
        // The safe area is subtracted, because it is part of the layout margins. Top and bottom
        // margins are set in other places and don't need to be adjusted for this workaround.
        let currentMargins = headerView.layoutMargins
        headerView.layoutMargins = UIEdgeInsets(
            top: currentMargins.top + 15.0,
            left: tableView.layoutMargins.left - tableView.safeAreaInsets.left,
            bottom: currentMargins.bottom,
            right: tableView.layoutMargins.right - tableView.safeAreaInsets.right
        )
    }
}
    
// MARK: - Configuration

extension StorageManagementConversationViewController {
    
    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        
        guard conversation != nil else {
            navigationBarTitle = BundleUtil.localizedString(forKey: "manage_all_conversations")
            return
        }
        navigationBarTitle = BundleUtil.localizedString(forKey: "storage_management")
    }
    
    private func configureTableView() {
        tableView.delegate = self
    }
    
    private func registerCells() {
        tableView.registerCell(StorageConversationSMTableViewCell.self)
        tableView.registerCell(ActionDetailsTableViewCell.self)
    }
    
    private func configureHeaderView() {
        
        guard let headerView = headerView else {
            tableView.tableHeaderView = nil
            return
        }
        tableView.tableHeaderView = headerView
        
        // Header layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        // To make these constraints work always call `updateHeaderLayout(animated:)` when the header
        // layout might have changed
        // WORKAROUND (Last tested: iOS 14.5):
        // The leading and trailing constraints should be constraint to `tableView.marginLayoutGuide`,
        // but this leads sometimes to jumps to the right and back when scrolling (often at the start).
        // This is fixed by using the `tableView.frameLayoutGuide` and then setting the correct
        // margins on the header in `viewLayoutMarginsDidChange()`
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: tableView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: tableView.frameLayoutGuide.leadingAnchor),
            headerView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
            headerView.trailingAnchor.constraint(equalTo: tableView.frameLayoutGuide.trailingAnchor),
        ])
    }
    
    // Always call when the header layout might have changed (e.g. rotation, dynamic type change)
    private func updateHeaderLayout(animated: Bool = true) {
        DispatchQueue.main.async {
            let updateHeight = {
                self.tableView.tableHeaderView = self.headerView
            }
            
            if animated {
                // Use table view update to animate height change
                // https://stackoverflow.com/a/32228700/286611
                self.tableView.performBatchUpdates(updateHeight)
            }
            else {
                updateHeight()
            }
        }
    }
}

// MARK: - Updates

extension StorageManagementConversationViewController {
    
    private enum OlderThanOption: Int, CaseIterable {
        case oneYear = 0
        case sixMonths
        case threeMonths
        case oneMonth
        case oneWeek
        case everything
    }
    
    private enum ActionSheetType: Int, CaseIterable {
        case messages = 0
        case files
    }
    
    private func titleDescription(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear:
            return BundleUtil.localizedString(forKey: "one_year_title")
        case .sixMonths:
            return BundleUtil.localizedString(forKey: "six_months_title")
        case .threeMonths:
            return BundleUtil.localizedString(forKey: "three_months_title")
        case .oneMonth:
            return BundleUtil.localizedString(forKey: "one_month_title")
        case .oneWeek:
            return BundleUtil.localizedString(forKey: "one_week_title")
        case .everything:
            return BundleUtil.localizedString(forKey: "everything")
        }
    }
    
    private func description(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear:
            return BundleUtil.localizedString(forKey: "one_year")
        case .sixMonths:
            return BundleUtil.localizedString(forKey: "six_months")
        case .threeMonths:
            return BundleUtil.localizedString(forKey: "three_months")
        case .oneMonth:
            return BundleUtil.localizedString(forKey: "one_month")
        case .oneWeek:
            return BundleUtil.localizedString(forKey: "one_week")
        case .everything:
            return BundleUtil.localizedString(forKey: "everything")
        }
    }

    private func updateContent() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        snapshot.appendSections([.messages])
        if let conversation = conversation {
            snapshot.appendItems([.valueConversation(conversation: conversation, celltype: .messages)])
        }
        else {
            snapshot.appendItems([.valueAllConversations(celltype: .messages)])
        }
        snapshot.appendItems([.action(action: Details.Action(
            title: BundleUtil.localizedString(forKey: "manage_messages"),
            imageName: nil,
            destructive: false,
            action: { view in
                self.showActionSheet(.messages, view: view)
            }
        ))])
        
        snapshot.appendSections([.files])
        if let conversation = conversation {
            snapshot.appendItems([.valueConversation(conversation: conversation, celltype: .files)])
        }
        else {
            snapshot.appendItems([.valueAllConversations(celltype: .files)])
        }
        snapshot.appendItems([.action(action: Details.Action(
            title: BundleUtil.localizedString(forKey: "manage_media_and_files"),
            imageName: nil,
            destructive: false,
            action: { view in
                self.showActionSheet(.files, view: view)
            }
        ))])
        
        dataSource.apply(snapshot)
    }
    
    private func showActionSheet(_ type: ActionSheetType, view: UIView) {
        var title = ""
        var description = ""
        
        switch type {
        case .messages:
            title = BundleUtil.localizedString(forKey: "delete_messages")
            description = BundleUtil.localizedString(forKey: "delete_messages_older_than")
        case .files:
            title = BundleUtil.localizedString(forKey: "delete_media")
            description = BundleUtil.localizedString(forKey: "delete_media_older_than")
        }
        
        let actionSheet = UIAlertController(title: title, message: description, preferredStyle: .actionSheet)
        for option in OlderThanOption.allCases {
            actionSheet
                .addAction(UIAlertAction(title: titleDescription(for: option), style: .destructive, handler: { _ in
                    print("delete \(option) \(type)")
                    switch type {
                    case .messages:
                        self.deleteMessageConfirmationSentence(for: option, view: view)
                    case .files:
                        self.deleteMediaConfirmationSentence(for: option, view: view)
                    }
                }))
        }
        actionSheet.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "cancel"), style: .cancel))
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            actionSheet.popoverPresentationController?.sourceRect = view.bounds
            actionSheet.popoverPresentationController?.sourceView = view
        }
        
        present(actionSheet, animated: true)
    }
    
    private func deleteMediaConfirmationSentence(for option: OlderThanOption, view: UIView) {
        var title = ""
        switch option {
        case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
            let defaultString = BundleUtil.localizedString(forKey: "delete_media_confirm")
            title = String(format: defaultString, description(for: option))
        case .everything:
            title = BundleUtil.localizedString(forKey: "delete_media_confirm_all")
        }
        
        UIAlertTemplate.showConfirm(
            owner: self,
            popOverSource: view,
            title: title,
            message: nil,
            titleOk: BundleUtil.localizedString(forKey: "delete_media"),
            actionOk: { _ in
                self.startMediaDelete(option)
                self.cleanTemporaryDirectory(option)
            },
            titleCancel: BundleUtil.localizedString(forKey: "cancel")
        )
    }
    
    private func deleteMessageConfirmationSentence(for option: OlderThanOption, view: UIView) {
        var title = ""
        switch option {
        case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
            let defaultString = BundleUtil.localizedString(forKey: "delete_messages_confirm")
            title = String(format: defaultString, description(for: option))
        case .everything:
            title = BundleUtil.localizedString(forKey: "delete_messages_confirm_all")
        }
        
        UIAlertTemplate.showConfirm(
            owner: self,
            popOverSource: view,
            title: title,
            message: nil,
            titleOk: BundleUtil.localizedString(forKey: "delete_messages"),
            actionOk: { _ in
            
                self.startMessageDelete(option)
                self.cleanTemporaryDirectory()
            
            },
            titleCancel: BundleUtil.localizedString(forKey: "cancel")
        )
    }
    
    private func olderThanDate(_ option: OlderThanOption) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch option {
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .everything:
            return nil
        }
    }
    
    private func startMediaDelete(_ option: OlderThanOption) {
        if let actionCell = dataSource.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 1, section: 1)
        ) as? StorageConversationSMTableViewCell {
            actionCell.isUserInteractionEnabled = false
        }

        MBProgressHUD.showAdded(to: view, animated: true)
        MBProgressHUD.forView(view)?.label.text = BundleUtil
            .localizedString(forKey: "delete_in_progress")
                
        Timer.scheduledTimer(withTimeInterval: TimeInterval(0.3), repeats: false) { _ in
            self.mediaDelete(option)
        }
    }
    
    private func mediaDelete(_ option: OlderThanOption) {
        var dbContext: DatabaseContext!
        if Thread.isMainThread {
            dbContext = DatabaseManager.db()!.getDatabaseContext()
        }
        else {
            dbContext = DatabaseManager.db()!.getDatabaseContext(withChildContextforBackgroundProcess: true)
        }
        let destroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        if let count = destroyer.deleteMedias(olderThan: olderThanDate(option), for: conversation) {
            DDLogNotice("[EntityDestroyer] \(count) media files deleted")
            
            Old_ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            if let actionCell = self.dataSource.tableView(
                self.tableView,
                cellForRowAt: IndexPath(row: 1, section: 1)
            ) as? StorageConversationSMTableViewCell {
                actionCell.isUserInteractionEnabled = true
            }

            MBProgressHUD.hide(for: self.view, animated: true)
            
            self.refresh()
        }
    }
    
    private func startMessageDelete(_ option: OlderThanOption) {
        if let actionCell = dataSource.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 1, section: 0)
        ) as? StorageConversationSMTableViewCell {
            actionCell.isUserInteractionEnabled = false
        }

        MBProgressHUD.showAdded(to: view, animated: true)
        MBProgressHUD.forView(view)?.label.text = BundleUtil
            .localizedString(forKey: "delete_in_progress")
        
        Timer.scheduledTimer(withTimeInterval: TimeInterval(0.3), repeats: false) { _ in
            self.messageDelete(option)
        }
    }
    
    private func messageDelete(_ option: OlderThanOption) {
        var dbContext: DatabaseContext!
        if Thread.isMainThread {
            dbContext = DatabaseManager.db()!.getDatabaseContext()
        }
        else {
            dbContext = DatabaseManager.db()!.getDatabaseContext(withChildContextforBackgroundProcess: true)
        }
        let entityManager = EntityManager(databaseContext: dbContext)
        if let count = entityManager.entityDestroyer.deleteMessages(
            olderThan: olderThanDate(option),
            for: conversation
        ) {
            
            if let conversation = conversation {
                let unreadMessages = UnreadMessages(entityManager: entityManager)
                unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [conversation])
            }
            else {
                if let conversations = entityManager.entityFetcher.notArchivedConversations() as? [Conversation] {
                    let unreadMessages = UnreadMessages(entityManager: entityManager)
                    unreadMessages.totalCount(doCalcUnreadMessagesCountOf: Set(conversations))
                }
            }
            
            DDLogNotice("[EntityDestroyer] \(count) messages deleted")
            
            let notificationManager = NotificationManager()
            notificationManager.updateUnreadMessagesCount()
            
            Old_ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            if let actionCell = self.dataSource.tableView(
                self.tableView,
                cellForRowAt: IndexPath(row: 1, section: 0)
            ) as? StorageConversationSMTableViewCell {
                actionCell.isUserInteractionEnabled = true
            }

            MBProgressHUD.hide(for: self.view, animated: true)
            
            self.refresh()
        }
    }
    
    private func cleanTemporaryDirectory(_ option: OlderThanOption? = nil) {
        if option == .everything {
            FileUtility.cleanTemporaryDirectory(olderThan: Date())
        }
        else {
            FileUtility.cleanTemporaryDirectory(olderThan: nil)
        }
    }
}

// MARK: - UITableViewDelegate

extension StorageManagementConversationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        switch row {
        case .action(action: _):
            return indexPath
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        switch row {
        case let .action(action):
            guard let cell = tableView.cellForRow(at: indexPath) else {
                fatalError("We should have a cell that was tapped for an action.")
            }
            
            action.run(cell)
        case .valueAllConversations(celltype: _):
            break
        case .valueConversation(conversation: _, celltype: _):
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
