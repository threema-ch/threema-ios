//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import UIKit

class ArchivedConversationsViewController: ThemedTableViewController {
    
    // MARK: - Property Declaration

    private lazy var editButton = UIBarButtonItem(
        barButtonSystemItem: .edit,
        target: self,
        action: #selector(showToolbar)
    )
    private lazy var cancelButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(hideToolbar)
    )
    private lazy var selectAllButton = UIBarButtonItem(
        title: #localize("select_all"),
        style: .plain,
        target: self,
        action: #selector(selectAllRows)
    )

    private lazy var toolbarUnarchiveButton = UIBarButtonItem(
        title: #localize("unarchive"),
        style: .plain,
        target: self,
        action: #selector(unarchiveSelected)
    )
    
    private let businessInjector = BusinessInjector()
    private lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = businessInjector.entityManager
            .entityFetcher
            .fetchedResultsControllerForArchivedConversations()
            
        fetchedResultsController.delegate = self
            
        return fetchedResultsController
    }()
    
    private lazy var utilities = ConversationActions(businessInjector: businessInjector)
        
    public var selectedConversation: ConversationEntity?
    private var allSelected = false
    private var didStartMultiselect = false
    
    private var lastAppearance = Date()
    private var viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
    
    private weak var previousNavigationControllerDelegate: UINavigationControllerDelegate?
    
    private lazy var lockScreen = LockScreen(isLockScreenController: false)
    
    // MARK: - Lifecycle
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        addObservers()
        
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            DDLogError("Failed to load archived conversations: \(error.localizedDescription)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
        
        navigationItem.title = #localize("archived_title")
        navigationItem.largeTitleDisplayMode = .never
        
        navigationItem.rightBarButtonItem = editButton
        
        tableView.allowsMultipleSelectionDuringEditing = true
        // Removes empty cells
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.register(ConversationTableViewCell.self, forCellReuseIdentifier: "ConversationTableViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
        
        updateDraftForCell()
        checkDateAndUpdateTimestamps()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            setSelection(for: selectedConversation)
        }
        
        // This and the opposite in `viewWillDisappear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideToolbar()
                
        // This and the opposite in `viewWillAppear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = false
    }
}

// MARK: - TableView

extension ArchivedConversationsViewController {
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "ConversationTableViewCell",
            for: indexPath
        ) as? ConversationTableViewCell else {
            DDLogError("Unable to create ConversationTableViewCell for cell at IndexPath: + \(indexPath)")
            fatalError("Unable to create ConversationTableViewCell for cell at IndexPath: + \(indexPath)")
        }
        cell.setConversation(to: fetchedResultsController.object(at: indexPath) as? ConversationEntity)
        cell.setNavigationController(to: navigationController)
        
        return cell
    }
        
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Disables Entering Chats when in Edit-Mode
        if isEditing {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            updateToolbarButtonTitles()
            return
        }
        
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            DDLogError("Could not select cell because there was no conversation for its indexPath")
            return
        }
                
        let info: Dictionary = [kKeyConversation: conversation]
        NotificationCenter.default.post(
            name: NSNotification.Name(kNotificationShowConversation),
            object: nil,
            userInfo: info
        )
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateToolbarButtonTitles()
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
        
        if tableView.indexPathsForSelectedRows?.count != nil {
            hideToolbar()
            didStartMultiselect = false
        }
    }
    
    // MARK: - Swipe Actions
    
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            return nil
        }
        
        let privateAction = ConversationsViewControllerHelper.createPrivateAction(
            viewController: self,
            conversation: conversation,
            lockScreenWrapper: lockScreen,
            businessInjector: businessInjector
        )
        
        let configuration = UISwipeActionsConfiguration(actions: [privateAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            return nil
        }
        
        // Unarchive
        
        let unarchiveAction = UIContextualAction(style: .normal, title: nil) { _, _, handler in
            self.utilities.unarchive(conversation)
            
            handler(true)
        }
        
        unarchiveAction.image = UIImage(resource: .threemaArchiveboxSlashFill)
        unarchiveAction.accessibilityLabel = #localize("unarchive")
        unarchiveAction.backgroundColor = Colors.gray
        
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
                handler: handler
            )
        }
        
        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.accessibilityLabel = #localize("delete")
        
        let configuration = UISwipeActionsConfiguration(actions: [unarchiveAction, deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        
        return configuration
    }
}

// MARK: - CellContextMenu

extension ArchivedConversationsViewController {
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

        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
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

extension ArchivedConversationsViewController {
   
    /// Shows Toolbar and enters Edit-Mode
    @objc private func showToolbar() {
        setEditing(true, animated: true)
        
        // NavBar
        cancelButton.style = .done
        
        navigationItem.rightBarButtonItem = cancelButton
        navigationItem.leftBarButtonItem = selectAllButton
        
        // Toolbar
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbarUnarchiveButton.isEnabled = false
        toolbarItems = [flexSpace, toolbarUnarchiveButton]
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    /// Hides Toolbar and exits Edit-Mode
    @objc private func hideToolbar() {
        // Properties
        setEditing(false, animated: true)
        allSelected = false
        navigationController?.setToolbarHidden(true, animated: true)

        // NavBar
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = editButton
        navigationItem.title = #localize("archived_title")
    }
    
    /// Unarchives selected Conversations
    @objc private func unarchiveSelected() {
        ConversationsViewControllerHelper.unarchiveConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) {
            self.hideToolbar()
        }
    }
    
    /// Selects all Rows of the TableView
    @objc private func selectAllRows() {
        if !allSelected {
            navigationItem.leftBarButtonItem?.title = #localize("deselect_all")
            allSelected = true
            for section in 0..<tableView.numberOfSections {
                for row in 0..<tableView.numberOfRows(inSection: section) {
                    let indexPath = IndexPath(row: row, section: section)
                    _ = tableView.delegate?.tableView?(tableView, willSelectRowAt: indexPath)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
                }
            }
        }
        else {
            navigationItem.leftBarButtonItem?.title = #localize("select_all")
            allSelected = false
            for section in 0..<tableView.numberOfSections {
                for row in 0..<tableView.numberOfRows(inSection: section) {
                    let indexPath = IndexPath(row: row, section: section)
                    _ = tableView.delegate?.tableView?(tableView, willSelectRowAt: indexPath)
                    tableView.deselectRow(at: indexPath, animated: true)
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
        toolbarUnarchiveButton.isEnabled = true
        
        if selectedCount == fetchedResultsController.fetchedObjects?.count {
            allSelected = true
            navigationItem.leftBarButtonItem?.title = #localize("deselect_all")
            navigationItem.title = #localize("all_selected")
        }
        else if selectedCount != 0 {
            allSelected = false
            navigationItem.leftBarButtonItem?.title = #localize("select_all")
            navigationItem.title = String.localizedStringWithFormat(
                #localize("selected_count"),
                selectedCount
            )
        }
        else {
            allSelected = false
            navigationItem.leftBarButtonItem?.title = #localize("select_all")
            navigationItem.title = #localize("archived_title")
            toolbarUnarchiveButton.isEnabled = false
        }
    }
}

// MARK: - Other

extension ArchivedConversationsViewController {
    @objc func setSelection(for conversation: ConversationEntity?) {
        guard let conversation,
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
}

// MARK: - Notifications

extension ArchivedConversationsViewController {
    
    private func addObservers() {
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
        if objectID.entity == ConversationEntity.entity() {
            DispatchQueue.main.async {
                self.refreshData()
            }
        }
    }
        
    @objc private func updateDraftForCell() {
        guard let selectedConversation,
              let indexPath = fetchedResultsController.indexPath(forObject: selectedConversation),
              let cell = tableView.cellForRow(at: indexPath) as? ConversationTableViewCell else {
            return
        }
        
        cell.updateLastMessagePreview()
    }
    
    @objc private func reloadTableView() {
        if !viewLoadedInBackground {
            tableView.reloadData()
        }
    }
    
    @objc private func addressBookSynchronized() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc private func updatePredicates() {
        var newPredicate: NSPredicate
        let archivedPredicate = NSPredicate(format: "visibility == %d", ConversationEntity.Visibility.archived.rawValue)
        let notPrivatePredicate = NSPredicate(format: "category != %d", ConversationEntity.Category.private.rawValue)
        
        if UserSettings.shared().hidePrivateChats {
            
            newPredicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [archivedPredicate, notPrivatePredicate]
            )
        }
        else {
            newPredicate = archivedPredicate
        }
        
        if fetchedResultsController.fetchRequest.predicate != newPredicate {
            fetchedResultsController.fetchRequest.predicate = newPredicate
            refreshData()
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ArchivedConversationsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
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
            guard let indexPath else {
                return
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            guard let obj = fetchedResultsController.fetchedObjects else {
                return
            }
            if obj.isEmpty, self == navigationController?.topViewController {
                navigationController?.popViewController(animated: true)
            }
            
        case .update:
            break
            
        case .move:
            if let indexPath,
               let newIndexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
        @unknown default:
            DDLogInfo("Unknown default called on controller() in ArchivedConversationsVC")
        }
    }
}
