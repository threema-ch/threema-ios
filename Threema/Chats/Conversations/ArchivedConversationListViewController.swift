import CocoaLumberjackSwift
import Foundation
import ThreemaFramework
import ThreemaMacros
import UIKit

final class ArchivedConversationListViewController: ThemedTableViewController {
    
    // MARK: - Property Declaration

    private lazy var editButton = UIBarButtonItem.editButton(
        target: self,
        selector: #selector(showToolbar)
    )
    private lazy var cancelButton = UIBarButtonItem.cancelButton(target: self, selector: #selector(hideToolbar))
    
    private lazy var selectAllButton = UIBarButtonItem(
        title: #localize("select_all"),
        style: .plain,
        target: self,
        action: #selector(selectAllRows)
    )
    
    private lazy var bottomToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isHidden = true
        return toolbar
    }()

    private lazy var toolbarUnarchiveButton = UIBarButtonItem(
        title: #localize("unarchive"),
        style: .plain,
        target: self,
        action: #selector(unarchiveSelected)
    )
    
    private let businessInjector = BusinessInjector.ui
    private lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = businessInjector.entityManager
            .entityFetcher
            .fetchedResultsControllerForArchivedConversationEntities(
                hidePrivateChats: businessInjector.userSettings.hidePrivateChats
            )
            
        fetchedResultsController.delegate = self
            
        return fetchedResultsController
    }()
    
    private lazy var utilities = ConversationActions(businessInjector: businessInjector)
    
    private lazy var selectionManager = ConversationSelectionManager(
        tableView: tableView,
        indexPathForConversation: { [weak self] conversation in
            guard let conversation else {
                return nil
            }
            
            return self?.fetchedResultsController.indexPath(forObject: conversation)
        },
        isRegularSizeClass: isRegularSizeClass,
        clearsSelectionOnViewWillAppear: { [weak self] in
            self?.clearsSelectionOnViewWillAppear = $0
        }
    )
    
    var selectedConversation: ConversationEntity? {
        selectionManager.selectedConversation
    }
    
    private var allSelected = false
    private var didStartMultiselect = false
    
    private var lastAppearance = Date()
    private var viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
    
    private weak var previousNavigationControllerDelegate: UINavigationControllerDelegate?
    
    private lazy var lockScreen = LockScreen(isLockScreenController: false)
    
    private weak var delegate: ConversationSelecting?
    
    /// While we would be able to access the size class in the view controller's
    /// trait collection, that value would not include the whole picture, only
    /// the current context. In order to correctly assess it, we inject it,
    /// letting the caller decide from where this information will be fetched.
    private let isRegularSizeClass: () -> Bool
    
    private let didDisappear: () -> Void
    
    // MARK: - Lifecycle
    
    init(
        delegate: ConversationSelecting,
        isRegularSizeClass: @autoclosure @escaping () -> Bool,
        didDisappear: @escaping () -> Void
    ) {
        self.delegate = delegate
        self.isRegularSizeClass = isRegularSizeClass
        self.didDisappear = didDisappear
        super.init(nibName: nil, bundle: nil)

        addObservers()

        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            DDLogError("Failed to load archived conversations: \(error)")
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        
        view.addSubview(bottomToolbar)
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: tableView.frameLayoutGuide.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: tableView.frameLayoutGuide.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        tableView.registerCell(ConversationTableViewCell.self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 26.0, *) {
            // Add extra padding so content doesn't feel cramped above the floating tab bar
            additionalSafeAreaInsets.bottom = bottomToolbar.isHidden ? 0 : max(
                0,
                bottomToolbar.bounds.height - view.safeAreaInsets.bottom
            ) + 8.0
        }
        else {
            additionalSafeAreaInsets.bottom = bottomToolbar.isHidden ? 0 : max(
                0,
                bottomToolbar.bounds.height - view.safeAreaInsets.bottom
            )
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewLoadedInBackground = AppDelegate.shared().isAppInBackground()
        
        updateDraftForCell()
        checkDateAndUpdateTimestamps()
        
        selectionManager.handleViewWillAppear()
        
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didDisappear()
    }
}

// MARK: - TableView

extension ArchivedConversationListViewController {
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ConversationTableViewCell = tableView.dequeueCell(for: indexPath)
        cell.setConversation(to: fetchedResultsController.object(at: indexPath) as? ConversationEntity)
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
        
        selectionManager.select(conversation: conversation, at: indexPath)
        
        delegate?.didSelectConversation(conversation: conversation)
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
        
        selectionManager.selectItemIfNeeded()
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
        
        if tableView.indexPathsForSelectedRows == nil {
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
        
        let privateAction = ConversationListViewControllerHelper.createPrivateAction(
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
        
        let unarchiveAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, handler in
            self?.utilities.unarchive(conversation)
            handler(true)
        }
        
        unarchiveAction.image = UIImage(resource: .threemaArchiveboxSlashFill)
        unarchiveAction.accessibilityLabel = #localize("unarchive")
        unarchiveAction.backgroundColor = .systemGray
        
        // Delete
        
        let cell = tableView.cellForRow(at: indexPath)
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, handler in
            guard let self else {
                return
            }
            
            // Show private chat delete info
            if conversation.conversationCategory == .private {
                UserReminder.maybeShowDeletePrivateChatInfoOnViewController(on: self)
            }
            
            selectionManager.clearSelectedItemIfNeeded(at: indexPath)
            
            DeleteConversationAction.execute(
                for: conversation,
                owner: self,
                cell: cell,
                onCompletion: handler
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

extension ArchivedConversationListViewController {
    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        
        guard !isEditing else {
            DDLogError("No context menu is shown when editing")
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
        
        selectionManager.select(conversation: conversation, at: indexPath)
        
        return UIContextMenuConfiguration(identifier: nil) {
            let chatViewController = ChatViewController(for: conversation, isRegularSizeClass: self.isRegularSizeClass)
            chatViewController.userInterfaceMode = .preview
            return chatViewController
        }
    }

    override func tableView(
        _ tableView: UITableView,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: any UIContextMenuInteractionCommitAnimating
    ) {
        guard let chatViewController = animator.previewViewController as? ChatViewController else {
            DDLogWarn("Unable to display chat after long press")
            return
        }
        
        animator.addCompletion { [delegate, chatViewController] in
            delegate?.didSelectConversation(conversation: chatViewController.conversation)
            // If we change the interface mode earlier the tab bar is still somewhat here and thus the chat bar appears
            // too high
            chatViewController.userInterfaceMode = .default
        }
    }
}

// MARK: - ToolBar

extension ArchivedConversationListViewController {
   
    /// Shows Toolbar and enters Edit-Mode
    @objc private func showToolbar() {
        setEditing(true, animated: true)
        
        // NavBar
        if #available(iOS 26.0, *) {
            cancelButton.style = .plain
        }
        else {
            cancelButton.style = .done
        }
        
        navigationItem.rightBarButtonItem = cancelButton
        navigationItem.leftBarButtonItem = selectAllButton
        
        // Toolbar
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbarUnarchiveButton.isEnabled = false
        bottomToolbar.items = [flexSpace, toolbarUnarchiveButton]
        bottomToolbar.isHidden = false
    }
    
    /// Hides Toolbar and exits Edit-Mode
    @objc private func hideToolbar() {
        // Properties
        setEditing(false, animated: true)
        allSelected = false
        bottomToolbar.isHidden = true
        
        // NavBar
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = editButton
        navigationItem.title = #localize("archived_title")
    }
    
    /// Unarchives selected Conversations
    @objc private func unarchiveSelected() {
        ConversationListViewControllerHelper.unarchiveConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) { [weak self] in
            self?.hideToolbar()
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

extension ArchivedConversationListViewController {
    
    func setSelection(for conversation: ConversationEntity?) {
        selectionManager.setSelection(for: conversation)
    }
    
    /// Should always be called on the Main-Thread
    private func refreshData() {
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        }
        catch {
            DDLogError("Failed to load conversations: \(error)")
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
    
    public func removeSelectedConversation() {
        selectionManager.removeSelection()
    }
}

// MARK: - Notifications

extension ArchivedConversationListViewController {
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(changedManagedObjects),
            name: DatabaseContext.changedManagedObjects,
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
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            checkDateAndUpdateTimestamps()
            if viewLoadedInBackground {
                viewLoadedInBackground = false
                refreshData()
            }
        }
    }
    
    @objc private func changedManagedObjects(_ notification: Notification) {
        guard let refreshedObjectIDs = notification
            .userInfo?[DatabaseContext.refreshedObjectIDsKey] as? Set<NSManagedObjectID> else {
            return
        }

        if refreshedObjectIDs.contains(where: { $0.entity == ConversationEntity.entity() }) {
            DispatchQueue.main.async { [weak self] in
                self?.refreshData()
            }
        }
    }
        
    private func updateDraftForCell() {
        guard
            let conversation = selectionManager.selectedConversation,
            let indexPath = fetchedResultsController.indexPath(forObject: conversation),
            let cell = tableView.cellForRow(at: indexPath) as? ConversationTableViewCell
        else {
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
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    @objc private func updatePredicates() {
        var newPredicate: NSPredicate
        let archivedPredicate = NSPredicate(format: "visibility == %d", ConversationEntity.Visibility.archived.rawValue)
        let notPrivatePredicate = NSPredicate(format: "category != %d", ConversationEntity.Category.private.rawValue)
        
        if businessInjector.userSettings.hidePrivateChats {
            
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

extension ArchivedConversationListViewController: NSFetchedResultsControllerDelegate {
    
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
