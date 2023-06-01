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
import Foundation
import OSLog
import ThreemaFramework
import UIKit

class ConversationsViewController: ThemedTableViewController {
    
    // MARK: - Property Declaration

    @IBOutlet var archivedChatsButton: UIButton!
    
    private lazy var newChatButton = UIBarButtonItem(
        image: UIImage(named: "square.and.pencil_regular.L"),
        style: .plain,
        target: self,
        action: #selector(newMessage)
    )
    private lazy var editButton = UIBarButtonItem(
        barButtonSystemItem: .edit,
        target: self,
        action: #selector(showToolbar)
    )
    private lazy var toolbarArchiveButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "archive"),
        style: .plain,
        target: self,
        action: #selector(archiveSelected)
    )
    private lazy var toolbarReadButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "mark_read"),
        style: .plain,
        target: self,
        action: #selector(readSelected)
    )
    private lazy var toolbarUnreadButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "mark_unread"),
        style: .plain,
        target: self,
        action: #selector(unreadSelected)
    )
    private lazy var cancelButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(hideToolbar)
    )
    private lazy var selectAllButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "select_all"),
        style: .plain,
        target: self,
        action: #selector(selectAllRows)
    )
    
    private lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = businessInjector.entityManager
            .entityFetcher
            .fetchedResultsControllerForConversations(withSections: false)
        
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    private lazy var businessInjector = BusinessInjector()
    private lazy var utilities = ConversationActions(
        businessInjector: businessInjector,
        notificationManager: NotificationManager(businessInjector: businessInjector)
    )

    private lazy var searchController: UISearchController = {
        
        var searchController = UISearchController()
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = BundleUtil.localizedString(forKey: "conversations_search_placeholder")
        return searchController
    }()
    
    @objc public var selectedConversation: Conversation?
    private var allSelected = false
    private var didStartMultiselect = false
    
    private var lastAppearance = Date()
    private var viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
    
    private var oldChatViewController: Old_ChatViewController?
    private var oldChatViewCompletionBlock: Old_ChatViewControllerCompletionBlock?
    private weak var previousNavigationControllerDelegate: UINavigationControllerDelegate?
    
    private lazy var lockScreen = LockScreen(isLockScreenController: false)
    
    // MARK: - Lifecycle
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        newChatButton.accessibilityLabel = BundleUtil.localizedString(forKey: "new_message_accessibility")
        
        addObservers()
        // Sets TabBar Title
        navigationController?.title = BundleUtil.localizedString(forKey: "chats_title")
        title = BundleUtil.localizedString(forKey: "chats_title")
        
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            DDLogError("Failed to load conversations: \(error.localizedDescription)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newChatButton
        navigationItem.searchController = searchController
        
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.register(ConversationTableViewCell.self, forCellReuseIdentifier: "ConversationTableViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
        
        checkDateAndUpdateTimestamps()
        updateDraftForCell()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            setSelection(for: selectedConversation)
        }
        
        updateArchivedButton()
        archivedChatsButton.adjustsImageSizeForAccessibilityContentSizeCategory = true
        archivedChatsButton.titleLabel?.adjustsFontForContentSizeCategory = true
        archivedChatsButton.titleLabel?.adjustsFontSizeToFitWidth = true
        updateArchivedButton()
        
        // This and the opposite in `viewWillDisappear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideToolbar()
        
        if searchController.isActive {
            searchController.isActive = false
        }
        
        // This and the opposite in `viewWillAppear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = false
    }
        
    override func didReceiveMemoryWarning() {
        DDLogWarn("Memory warning, removing cached chat view controllers")
        Old_ChatViewControllerCache.clear()
        super.didReceiveMemoryWarning()
    }
}

// MARK: - StoryBoard Button Actions

extension ConversationsViewController {
    
    @IBAction func showArchivedConversations(_ sender: Any) {
        performSegue(withIdentifier: "showArchived", sender: self)
    }
    
    @objc func newMessage() {
        guard let contactsPickerNavController = storyboard?.instantiateViewController(
            withIdentifier: "ContactPickerNavigationController"
        ) else {
            DDLogError("Could not instantiate ContactPickerNavigationController from Storyboard")
            return
        }
        present(contactsPickerNavController, animated: true, completion: nil)
    }
}

// MARK: - TableView

extension ConversationsViewController {
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "ConversationTableViewCell", for: indexPath
        ) as? ConversationTableViewCell else {
            DDLogError("Unable to create ConversationTableViewCell for cell at IndexPath: + \(indexPath)")
            fatalError("Unable to create ConversationTableViewCell for cell at IndexPath: + \(indexPath)")
        }
        cell.setConversation(to: fetchedResultsController.object(at: indexPath) as? Conversation)
        return cell
    }
        
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if fetchedResultsController.sections?.count == 1 {
            return nil
        }
        
        if fetchedResultsController.sections?[section].name == "0" {
            return BundleUtil.localizedString(forKey: "chats_title")
        }
        
        return BundleUtil.localizedString(forKey: "chats_pinned")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        os_signpost(.begin, log: PointsOfInterestSignpost.log, name: "showChat")
        os_signpost(.event, log: PointsOfInterestSignpost.log, name: "didSelectRowAt")

        // Disables Entering Chats when in Edit-Mode
        if isEditing {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            updateToolbarButtonTitles()
            setToolbarItems()
            return
        }
        
        guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
            DDLogError("Could not select cell because there was no conversation for its indexPath")
            return
        }
        
        selectedConversation = conversation

        let info: Dictionary = [kKeyConversation: conversation]
        NotificationCenter.default.post(
            name: NSNotification.Name(kNotificationShowConversation),
            object: nil,
            userInfo: info
        )
        
        if searchController.isActive {
            searchController.isActive = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateToolbarButtonTitles()
        setToolbarItems()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
    // Disables Edit-Button during Swipe-Action
    override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        editButton.isEnabled = false
    }
    
    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        editButton.isEnabled = true
    }
    
    // Enables Multi-Select by Swiping with 2 Fingers
    override func tableView(
        _ tableView: UITableView,
        shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath
    ) -> Bool {
        true
    }
    
    override func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        guard !isEditing else {
            return
        }
        
        showToolbar()
        didStartMultiselect = true
    }
    
    override func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        guard didStartMultiselect else {
            return
        }
        
        if tableView.indexPathsForSelectedRows?.count == nil {
            hideToolbar()
            didStartMultiselect = false
        }
    }
}

// MARK: - Swipe Actions

extension ConversationsViewController {
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
            return nil
        }
        
        let readAction = createReadAction(conversation: conversation)
        let pinAction = createPinAction(conversation: conversation)
        let privateAction = ConversationsViewControllerHelper.createPrivateAction(
            viewController: self,
            conversation: conversation,
            lockScreenWrapper: lockScreen,
            businessInjector: businessInjector
        )
        
        let configuration = UISwipeActionsConfiguration(actions: [readAction, pinAction, privateAction])
        return configuration
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
            return nil
        }
        
        // Archive
        
        let archiveAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            UserReminder.maybeShowArchiveInfo(on: self)
            self.utilities.archive(conversation)
            self.updateArchivedButton()
            handler(true)
        }
        
        archiveAction.image = BundleUtil.imageNamed("archivebox.fill_regular.L")
        archiveAction.title = BundleUtil.localizedString(forKey: "archive")
        archiveAction.accessibilityLabel = BundleUtil.localizedString(forKey: "archive")
        archiveAction.backgroundColor = Colors.gray
        
        // Delete
        
        let cell = tableView.cellForRow(at: indexPath)
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, handler in
            // Show private chat delete info
            if conversation.conversationCategory == .private {
                UserReminder.maybeShowDeletePrivateChatInfoOnViewController(on: self)
            }
            
            ConversationsViewControllerHelper.handleDeletion(
                of: conversation,
                owner: self,
                cell: cell,
                entityManager: self.businessInjector.entityManager,
                handler: handler
            )
        }
        
        deleteAction.image = BundleUtil.imageNamed("trash.fill_regular.L")
        deleteAction.title = BundleUtil.localizedString(forKey: "delete")
        deleteAction.accessibilityLabel = BundleUtil.localizedString(forKey: "delete")
        
        let configuration = UISwipeActionsConfiguration(actions: [archiveAction, deleteAction])
        
        return configuration
    }
    
    /// Creates the Pin Action for the ContextMenu
    /// - Parameter conversation: Conversation for Action
    /// - Returns: ContextualAction for SwipeMenu of Cell
    private func createPinAction(conversation: Conversation) -> UIContextualAction {
        
        let isPinned = conversation.conversationVisibility == .pinned
        let pinTitle: String
        
        if isPinned {
            pinTitle = BundleUtil.localizedString(forKey: "unpin")
        }
        else {
            pinTitle = BundleUtil.localizedString(forKey: "pin")
        }
        
        let pinAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            
            if isPinned {
                self.businessInjector.conversationStore.unpin(conversation)
            }
            else {
                self.businessInjector.conversationStore.pin(conversation)
            }
            
            handler(true)
        }
        
        if isPinned {
            pinAction.image = BundleUtil.imageNamed("pin.slash.fill_regular.L")
        }
        else {
            pinAction.image = BundleUtil.imageNamed("pin.fill_regular.L")
        }

        pinAction.title = pinTitle
        pinAction.accessibilityLabel = pinTitle
        pinAction.backgroundColor = Colors.backgroundPinChat
        return pinAction
    }
    
    /// Creates the Read Action for the ContextMenu
    /// - Parameter conversation: Conversation for Action
    /// - Returns: ContextualAction for SwipeMenu of Cell
    private func createReadAction(conversation: Conversation) -> UIContextualAction {
        
        let hasUnread = conversation.unreadMessageCount.intValue != 0
        let unreadTitle: String
        
        if hasUnread {
            unreadTitle = BundleUtil.localizedString(forKey: "read")
        }
        else {
            unreadTitle = BundleUtil.localizedString(forKey: "unread")
        }
        
        let readAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            
            if hasUnread {
                self.utilities.read(conversation)
            }
            else {
                self.utilities.unread(conversation)
            }
            
            handler(true)
        }
        
        if hasUnread {
            readAction.image = BundleUtil.imageNamed("eye.fill_regular.L")
        }
        else {
            readAction.image = BundleUtil.imageNamed("envelope.badge.fill_regular.L")
        }
        readAction.title = unreadTitle
        readAction.accessibilityLabel = unreadTitle
        readAction.backgroundColor = Colors.blue
        return readAction
    }
}

// MARK: - CellContextMenu

extension ConversationsViewController {
    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        
        guard !isEditing,
              UIDevice.current.userInterfaceIdiom != .pad else {
            DDLogError("No context menu is shown when editing and on iPad")
            return nil
        }

        guard let conversation = fetchedResultsController.object(at: indexPath) as? Conversation else {
            DDLogError("Could not select cell because there was no conversation for its indexPath")
            return nil
        }
        
        guard conversation.conversationCategory != .private else {
            DDLogError("No context menu is shown if conversation is private")
            return nil
        }
        selectedConversation = conversation
        
        return UIContextMenuConfiguration(identifier: nil) {
            let chatViewController = ChatViewController(for: conversation)
            chatViewController.userInterfaceMode = .preview
            return chatViewController
        }
    }

    override func tableView(
        _ tableView: UITableView,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        guard let chatViewController = animator.previewViewController as? ChatViewController else {
            DDLogWarn("Unable to display chat after long press")
            return
        }
        
        animator.addCompletion {
            self.show(chatViewController, sender: self)
            // If we change the interface mode earlier the tab bar is still somewhat here and thus the chat bar appears
            // too high
            chatViewController.userInterfaceMode = .default
        }
    }
}

// MARK: - ToolBar

extension ConversationsViewController {
    /// Shows Toolbar and enters Edit-Mode
    @objc private func showToolbar() {
        setEditing(true, animated: true)
        archivedChatsButton.isHidden = true
        
        // Nav Bar
        cancelButton.style = .done
        
        navigationItem.rightBarButtonItem = cancelButton
        navigationItem.leftBarButtonItems = [selectAllButton]
        navigationItem.searchController = nil
        
        toolbarReadButton.isEnabled = false
        toolbarArchiveButton.isEnabled = false
        setToolbarItems()
        
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    /// Hides Toolbar and exits Edit-Mode
    @objc private func hideToolbar() {
        // Properties
        setEditing(false, animated: true)
        allSelected = false
        navigationController?.setToolbarHidden(true, animated: true)
        archivedChatsButton.isHidden = false
        
        // Navbar
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newChatButton
        navigationItem.searchController = searchController
        navigationItem.title = BundleUtil.localizedString(forKey: "chats_title")
    }
    
    /// Marks selected Conversations as "Read"
    @objc private func readSelected() {
        ConversationsViewControllerHelper.readConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) {
            self.hideToolbar()
        }
    }
    
    /// Marks selected Conversations as "Unread"
    @objc private func unreadSelected() {
        ConversationsViewControllerHelper.unreadConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) {
            self.hideToolbar()
        }
    }
    
    /// Archives selected Conversations
    @objc private func archiveSelected() {
        ConversationsViewControllerHelper.archiveConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) {
            self.hideToolbar()
        }
        updateArchivedButton()
    }
    
    /// Selects all Rows of the TableView
    @objc private func selectAllRows() {
        if !allSelected {
            navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "deselect_all")
            allSelected = true
            for section in 0..<tableView.numberOfSections {
                for row in 0..<tableView.numberOfRows(inSection: section) {
                    let indexPath = IndexPath(row: row, section: section)
                    _ = tableView.delegate?.tableView?(tableView, willSelectRowAt: indexPath)
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
                }
            }
        }
        else {
            navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "select_all")
            allSelected = false
            for section in 0..<tableView.numberOfSections {
                for row in 0..<tableView.numberOfRows(inSection: section) {
                    let indexPath = IndexPath(row: row, section: section)
                    _ = tableView.delegate?.tableView?(tableView, willSelectRowAt: indexPath)
                    tableView.deselectRow(at: indexPath, animated: false)
                    tableView.delegate?.tableView?(tableView, didDeselectRowAt: indexPath)
                }
            }
        }
    }
    
    /// Updates the titles of the ToolbarItems and NavBar
    private func updateToolbarButtonTitles() {
        
        guard isEditing else {
            return
        }
        
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        toolbarArchiveButton.isEnabled = true
        toolbarReadButton.isEnabled = true
        
        if selectedCount == fetchedResultsController.fetchedObjects?.count {
            allSelected = true
            navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "deselect_all")
            navigationItem.title = BundleUtil.localizedString(forKey: "all_selected")
        }
        else if selectedCount != 0 {
            allSelected = false
            navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "select_all")
            navigationItem.title = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "selected_count"),
                selectedCount
            )
        }
        else {
            allSelected = false
            navigationItem.leftBarButtonItem?.title = BundleUtil.localizedString(forKey: "select_all")
            navigationItem.title = BundleUtil.localizedString(forKey: "chats_title")
            toolbarReadButton.isEnabled = false
            toolbarArchiveButton.isEnabled = false
        }
    }
    
    /// Sets the ToolbarItems depending on the selection of Cells
    private func setToolbarItems() {
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbarItems = [toolbarReadButton, flexSpace, toolbarArchiveButton]
        
        guard let selected = tableView.indexPathsForSelectedRows else {
            return
        }
        
        for path in selected {
            guard let conversation = fetchedResultsController.object(at: path) as? Conversation else {
                continue
            }
            if conversation.unreadMessageCount != 0 {
                return
            }
        }
        
        toolbarItems = [toolbarUnreadButton, flexSpace, toolbarArchiveButton]
    }
}

// MARK: - UISearchResultsUpdating, UISearchControllerDelegate

extension ConversationsViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    
    func didPresentSearchController(_ searchController: UISearchController) {
        archivedChatsButton.isHidden = true
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        archivedChatsButton.isHidden = false
        if UIDevice.current.userInterfaceIdiom == .pad {
            setSelection(for: selectedConversation)
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        guard let searchText = searchController.searchBar.text else {
            return
        }
        
        let notPrivatePredicate = NSPredicate(format: "category != %d", ConversationCategory.private.rawValue)
        
        if !searchText.isEmpty {
            let groupPredicate = NSPredicate(format: "groupName contains[c] %@", searchText)
            let firstNamePredicate = NSPredicate(
                format: "contact.firstName contains[c] %@ AND groupId == nil",
                searchText
            )
            let lastNamePredicate = NSPredicate(
                format: "contact.lastName contains[c] %@ AND groupId == nil",
                searchText
            )
            let publicNamePredicate = NSPredicate(
                format: "contact.publicNickname contains[c] %@ AND groupId == nil",
                searchText
            )
            let identityPredicate = NSPredicate(
                format: "contact.identity contains[c] %@ AND groupId == nil",
                searchText
            )
            
            let searchCompound = NSCompoundPredicate(orPredicateWithSubpredicates: [
                groupPredicate,
                firstNamePredicate,
                lastNamePredicate,
                publicNamePredicate,
                identityPredicate,
            ])
            
            if UserSettings.shared().hidePrivateChats {
                let privateCompound = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    searchCompound,
                    notPrivatePredicate,
                ])
                fetchedResultsController.fetchRequest.predicate = privateCompound
            }
            else {
                fetchedResultsController.fetchRequest.predicate = searchCompound
            }
        }
        else {
            updatePredicates()
        }
        refreshData()
    }
}

// MARK: - Other

extension ConversationsViewController {
    
    private func setBackButton(unread: Int) {
        var backButtonTitle = " "
        
        if unread > 0 {
            backButtonTitle = String(unread)
        }
        
        let backButton = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
        backButton.accessibilityLabel = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "chat_back_button_accessibility"),
            unread
        )
        
        DispatchQueue.main.async {
            self.navigationItem.backBarButtonItem = backButton
        }
    }
    
    @objc func setSelection(for conversation: Conversation?) {
        guard let conversation = conversation,
              let newRow = fetchedResultsController.indexPath(forObject: conversation) else {
            return
        }
        
        tableView.selectRow(at: newRow, animated: true, scrollPosition: .none)
        selectedConversation = conversation
        
        DDLogInfo("newSelectedRow: \(String(describing: newRow))")
    }
    
    /// Should always be called on the Main-Thread
    private func refreshData() {
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        }
        catch {
            DDLogError("Failed to load conversations: \(error.localizedDescription)")
        }
    }
    
    private func checkDateAndUpdateTimestamps() {
        let now = Date()
        if !Calendar.current.isDate(lastAppearance, inSameDayAs: now) {
            DDLogInfo("Last appeared on a different date; updating timestamps")
            if !viewLoadedInBackground {
                tableView.reloadData()
            }
        }
        lastAppearance = now
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let navHeight = navigationController!.navigationBar.frame.size.height
        let textInNavBar = navigationItem.prompt != nil
        if (navHeight <= BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight <= BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            navigationItem.titleView != nil {
            navigationItem.titleView = nil
            title = BundleUtil.localizedString(forKey: "chats_title")
        }
        else if (navHeight > BrandingUtils.compactNavBarHeight && !textInNavBar) ||
            (navHeight > BrandingUtils.compactPromptNavBarHeight && textInNavBar),
            navigationItem.titleView == nil {
            BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        }
    }
    
    @objc func displayChat(chatViewController: ChatViewController, animated: Bool) {
        // Chat is already displayed
        if navigationController?.topViewController == chatViewController {
            return
        }
        
        // In the view hierarchy, there is already a view for the chat, pop overlaying VC's to it
        if navigationController?.viewControllers.contains(chatViewController) ?? false {
            if (navigationController?.topViewController?.presentedViewController) != nil {
                return
            }
            navigationController?.popToViewController(chatViewController, animated: animated)
            return
        }
        
        if chatViewController.conversation.conversationCategory == .private {
            
            lockScreen.presentLockScreenView(
                viewController: self,
                enteredCorrectly: {
                    guard let navigationController = self.navigationController else {
                        return
                    }
                    navigationController.popToViewController(self, animated: false)
                    navigationController.pushViewController(chatViewController, animated: false)
                }
            )
        }
        else {
            navigationController?.popToViewController(self, animated: false)
            navigationController?.pushViewController(chatViewController, animated: animated)
        }
        
        if UIDevice.current.userInterfaceIdiom != .pad,
           let conversation = selectedConversation,
           let selectedRow = fetchedResultsController.indexPath(forObject: conversation) {
            tableView.deselectRow(at: selectedRow, animated: false)
        }
        else {
            setSelection(for: chatViewController.conversation)
        }
    }
    
    @objc func displayOldChat(oldChatViewController: Old_ChatViewController, animated: Bool) {
        
        // Chat is already displayed
        if navigationController?.topViewController == oldChatViewController {
            return
        }
        
        // In the view hierarchy, there is already a view for the chat, pop overlaying VC's to it
        if navigationController?.viewControllers.contains(oldChatViewController) ?? false {
            if (navigationController?.topViewController?.presentedViewController) != nil {
                return
            }
            navigationController?.popToViewController(oldChatViewController, animated: animated)
            return
        }
        
        if oldChatViewController.isPrivateConversation() {
            self.oldChatViewController = oldChatViewController
            
            lockScreen.presentLockScreenView(
                viewController: self,
                enteredCorrectly: {
                    guard let chatViewController = self.oldChatViewController,
                          let navigationController = self.navigationController else {
                        return
                    }
                    navigationController.popToViewController(self, animated: false)
                    navigationController.pushViewController(chatViewController, animated: false)
                }
            )
        }
        else {
            navigationController?.popToViewController(self, animated: false)
            navigationController?.pushViewController(oldChatViewController, animated: animated)
        }
        
        if UIDevice.current.userInterfaceIdiom != .pad,
           let conversation = selectedConversation,
           let selectedRow = fetchedResultsController.indexPath(forObject: conversation) {
            tableView.deselectRow(at: selectedRow, animated: false)
        }
        else {
            setSelection(for: oldChatViewController.conversation)
        }
    }
    
    @objc func getFirstConversation() -> Conversation? {
        guard let objects = fetchedResultsController.fetchedObjects as NSArray? else {
            return nil
        }
        
        for object in objects {
            guard let conversation = object as? Conversation else {
                continue
            }
            
            selectedConversation = conversation
            return conversation
        }
        
        return nil
    }
    
    /// Enables or Disables the ArchiveButton
    private func updateArchivedButton() {
        
        // Disable button if no archived chats, hide it if there are not conversations at all
        let count = businessInjector.entityManager.entityFetcher.countArchivedConversations()
        if count > 0 {
            archivedChatsButton.isHidden = false
            archivedChatsButton.setTitle(BundleUtil.localizedString(forKey: "archived_chats") + " ", for: .normal)
            archivedChatsButton.setImage(BundleUtil.imageNamed("chevron.right_semibold.M"), for: .normal)
            archivedChatsButton.isEnabled = true
        }
        // swiftformat:disable:next isEmpty
        else if let objects = fetchedResultsController.fetchedObjects as NSArray?, objects.count != 0 {
            archivedChatsButton.setTitle(BundleUtil.localizedString(forKey: "no_archived_chats"), for: .normal)
            archivedChatsButton.setImage(nil, for: .normal)
            archivedChatsButton.isEnabled = false
            archivedChatsButton.isHidden = false
        }
        else {
            archivedChatsButton.isHidden = true
        }
    }
    
    @objc public func removeSelectedConversation() {
        selectedConversation = nil
    }
}

// MARK: - Notifications

extension ConversationsViewController {
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(unreadMessageCountChanged(_:)),
            name: NSNotification.Name(rawValue: kNotificationMessagesCountChanged),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDirtyObjects),
            name: NSNotification.Name(rawValue: kNotificationDBRefreshedDirtyObject),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorThemeChanged),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showProfilePictureChanged),
            name: NSNotification.Name(rawValue: kNotificationShowProfilePictureChanged),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTableView),
            name: NSNotification.Name(rawValue: kNotificationBlockedContact),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(addressBookSynchronized),
            name: NSNotification.Name(rawValue: kNotificationAddressbookSyncronized),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePredicates),
            name: NSNotification.Name(rawValue: kNotificationChangedHidePrivateChat),
            object: nil
        )
    }
    
    @objc private func unreadMessageCountChanged(_ notification: Notification) {
        let unread: Int = notification.userInfo?[kKeyUnread] as? Int ?? 0
        setBackButton(unread: unread)
    }
    
    @objc func applicationWillEnterForeground() {
        
        assert(Thread.isMainThread, "Notification was not delivered on main thread")
        
        checkDateAndUpdateTimestamps()
        if viewLoadedInBackground {
            viewLoadedInBackground = false
            refreshData()
        }
    }
    
    @objc private func refreshDirtyObjects(notification: NSNotification) {
        guard let objectID: NSManagedObjectID = notification.userInfo?[kKeyObjectID] as? NSManagedObjectID else {
            return
        }
        if objectID.entity == Conversation.entity() {
            DispatchQueue.main.async {
                self.refreshData()
            }
        }
    }
    
    @objc private func colorThemeChanged() {
        BrandingUtils.updateTitleLogo(of: navigationItem, in: navigationController)
        Colors.update(searchBar: searchController.searchBar)
    }
    
    @objc private func updateDraftForCell() {
        guard let selectedConversation = selectedConversation,
              let indexPath = fetchedResultsController.indexPath(forObject: selectedConversation),
              let cell = tableView.cellForRow(at: indexPath) as? ConversationTableViewCell else {
            return
        }
        
        cell.updateLastMessagePreview()
    }
    
    @objc private func showProfilePictureChanged() {
        refreshData()
    }
    
    @objc private func reloadTableView() {
        if !viewLoadedInBackground {
            tableView.reloadData()
        }
    }
    
    @objc private func addressBookSynchronized() {
        DispatchQueue.main.async {
            Old_ChatViewControllerCache.clear()
            self.tableView.reloadData()
        }
    }
    
    /// Updates the Predicates to the default and refreshes the TableView
    @objc private func updatePredicates() {
        
        let archivedPredicate = NSPredicate(format: "visibility != %d", ConversationVisibility.archived.rawValue)
        let privatePredicate = NSPredicate(format: "category != %d", ConversationCategory.private.rawValue)
        
        if UserSettings.shared().hidePrivateChats {
            
            fetchedResultsController.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                archivedPredicate,
                privatePredicate,
            ])
        }
        else {
            fetchedResultsController.fetchRequest.predicate = archivedPredicate
        }
        refreshData()
    }
}

// MARK: - UINavigationControllerDelegate

extension ConversationsViewController: UINavigationControllerDelegate {
    
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        
        guard let chatViewCompBlock = oldChatViewCompletionBlock,
              let oldViewController = viewController as? Old_ChatViewController else {
            return
        }
        
        oldViewController.showContentAfterForceTouch()
        chatViewCompBlock(oldViewController)
        oldChatViewCompletionBlock = nil
        
        navigationController.delegate = previousNavigationControllerDelegate
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConversationsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        updateArchivedButton()
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .automatic)
            }
            
        case .delete:
            guard let indexPath = indexPath,
                  let conversation = anObject as? Conversation else {
                return
            }
            Old_ChatViewControllerCache.clear(conversation)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        case .move:
            if let indexPath = indexPath,
               let newIndexPath = newIndexPath {
                tableView.moveRow(at: indexPath, to: newIndexPath)
            }
        case .update:
            break
        @unknown default:
            DDLogInfo("Unknown default called on controller() in ConversationsVC")
        }
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        let section = IndexSet(integer: sectionIndex)
        switch type {
        case .delete:
            tableView.deleteSections(section, with: .automatic)
        case .insert:
            tableView.insertSections(section, with: .automatic)
        default:
            break
        }
    }
}

// MARK: - Old_ChatViewControllerDelegate

extension ConversationsViewController: Old_ChatViewControllerDelegate {
    
    func present(_ chatViewController: Old_ChatViewController!, onCompletion: Old_ChatViewControllerCompletionBlock!) {
        previousNavigationControllerDelegate = navigationController?.delegate
        navigationController?.delegate = self
        
        chatViewController.showContentAfterForceTouch()
        oldChatViewCompletionBlock = onCompletion
        displayOldChat(oldChatViewController: chatViewController, animated: false)
    }
    
    @objc func pushSettingChanged(_ conversation: Conversation) {
        // do nothing, because cell is observe this by it self
    }
}
