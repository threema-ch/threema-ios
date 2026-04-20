import CocoaLumberjackSwift
import Foundation
import OSLog
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ConversationSelecting: AnyObject {
    func didSelectConversation(conversation: ConversationEntity)
}

protocol ConversationListViewControllerDelegate: AnyObject, ConversationSelecting {
    func archivedConversationListTriggered()
    func willDisappear()
}

final class ConversationListViewController: ThemedTableViewController {
    
    // MARK: - Property Declaration
    
    private lazy var archivedChatsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = #localize("archived_chats")
        configuration.image = UIImage(systemName: "chevron.forward")
        configuration.imagePlacement = .trailing
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote)
        configuration.buttonSize = .large
        
        let action = UIAction { [weak self] _ in
            self?.showArchivedConversations()
        }
        
        return UIButton(configuration: configuration, primaryAction: action)
    }()
    
    private lazy var newChatButton = UIBarButtonItem(
        image: UIImage(systemName: "square.and.pencil"),
        style: .plain,
        target: self,
        action: #selector(newMessage)
    )
    private lazy var editButton: UIBarButtonItem = {
        let imageName =
            if #available(iOS 26.0, *) {
                "ellipsis"
            }
            else {
                "ellipsis.circle"
            }
        return UIBarButtonItem(
            title: #localize("edit"),
            image: UIImage(systemName: imageName),
            primaryAction: nil,
            menu: menu
        )
    }()
    
    private lazy var bottomToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isHidden = true
        return toolbar
    }()

    private lazy var toolbarArchiveButton = UIBarButtonItem(
        title: #localize("archive"),
        style: .plain,
        target: self,
        action: #selector(archiveSelected)
    )
    private lazy var toolbarReadButton = UIBarButtonItem(
        title: #localize("mark_read"),
        style: .plain,
        target: self,
        action: #selector(readSelected)
    )
    private lazy var toolbarUnreadButton = UIBarButtonItem(
        title: #localize("mark_unread"),
        style: .plain,
        target: self,
        action: #selector(unreadSelected)
    )
    
    private lazy var cancelButton = UIBarButtonItem.cancelButton(target: self, selector: #selector(hideToolbar))
    
    private lazy var selectAllButton = UIBarButtonItem(
        title: #localize("select_all"),
        style: .plain,
        target: self,
        action: #selector(selectAllRows)
    )
    
    private lazy var menu = UIMenu(title: "", image: nil, identifier: nil, options: [], children: [
        UIAction(title: #localize("conversations_menu_read_all"), image: UIImage(systemName: "eye")) { [weak self] _ in
            Task {
                guard let self else {
                    return
                }
                await self.utilities.readAll(isAppInBackground: self.viewLoadedInBackground)
            }
        },
        UIAction(
            title: #localize("conversations_menu_select"),
            image: UIImage(systemName: "checkmark.circle")
        ) { [weak self] _ in
            self?.showToolbar()
        },
    ])
    
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: globalSearchResultsViewController)
        controller.searchResultsUpdater = globalSearchResultsViewController
        controller.delegate = globalSearchResultsViewController
        controller.obscuresBackgroundDuringPresentation = false
        
        controller.searchBar.placeholder = #localize("conversations_global_search_placeholder")
        controller.searchBar.scopeButtonTitles = globalSearchResultsViewController.searchScopeButtonTitles
        controller.searchBar.searchTextField.allowsCopyingTokens = false
        
        return controller
    }()
    
    private lazy var globalSearchResultsViewController =
        GlobalSearchResultsViewController(entityManager: businessInjector.entityManager)
    
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = businessInjector.entityManager
            .entityFetcher
            .fetchedResultsControllerForConversationEntities(
                hidePrivateChats: businessInjector.userSettings.hidePrivateChats
            )
        
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    private lazy var businessInjector = BusinessInjector.ui
    private lazy var notificationManager = NotificationManager(businessInjector: businessInjector)
    private lazy var utilities = ConversationActions(businessInjector: businessInjector)
    
    private(set) lazy var selectionManager = ConversationSelectionManager(
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
    
    private var refreshConversationsDelay: Timer?
    
    private(set) weak var delegate: ConversationListViewControllerDelegate?
    
    /// While we would be able to access the size class in the view controller's
    /// trait collection, that value would not include the whole picture, only
    /// the current context. In order to correctly assess it, we inject it,
    /// letting the caller decide from where this information will be fetched.
    private let isRegularSizeClass: () -> Bool
    
    private var setBackButtonDebounceTask: Task<Void, Never>?

    // MARK: - Lifecycle
    
    init(
        delegate: ConversationListViewControllerDelegate,
        isRegularSizeClass: @autoclosure @escaping () -> Bool
    ) {
        self.delegate = delegate
        self.isRegularSizeClass = isRegularSizeClass
        super.init(nibName: nil, bundle: nil)
        
        editButton.accessibilityLabel = #localize("edit")
        newChatButton.accessibilityLabel = #localize("new_message_accessibility")
        
        addObservers()
        
        tabBarItem.title = #localize("chats_title")
        tabBarItem.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        tabBarItem.selectedImage = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        tabBarItem.accessibilityIdentifier = "TabBarChats"
        
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            DDLogError("Failed to load conversations: \(error)")
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        UserSettings.shared().removeObserver(
            self,
            forKeyPath: "blacklist"
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newChatButton
        
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.delegate = self
        tableView.registerCell(ConversationTableViewCell.self)
        
        // Sets TabBar Title
        title = #localize("chats_title")
        navigationController?.navigationBar.prefersLargeTitles = true
        globalSearchResultsViewController.setSearchController(searchController)
        
        tableView.tableFooterView = archivedChatsButton

        view.addSubview(bottomToolbar)
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: tableView.frameLayoutGuide.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: tableView.frameLayoutGuide.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
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
        
        checkDateAndUpdateTimestamps()
        updateDraftForCell()
        
        selectionManager.handleViewWillAppear()
        
        updateArchivedButton()
        
        updateNavigationBarContent()
        
        // This and the opposite in `viewWillDisappear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = true
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if navigationItem.searchController == nil, AppLaunchManager.isRemoteSecretEnabled == false {
            navigationItem.searchController = searchController
        }
        
        updateFooterIfNeeded()
    }
    
    func updateFooterIfNeeded() {
        archivedChatsButton.setNeedsLayout()
        archivedChatsButton.layoutIfNeeded()
        
        let fittingSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let targetHeight = archivedChatsButton.systemLayoutSizeFitting(fittingSize).height

        if tableView.tableFooterView?.frame.height != targetHeight {
            archivedChatsButton.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: targetHeight)
            tableView.tableFooterView = archivedChatsButton
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideToolbar()
                
        // This and the opposite in `viewWillAppear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = false
        delegate?.willDisappear()
    }
}

// MARK: - Button Actions

extension ConversationListViewController {
    
    func showArchivedConversations() {
        delegate?.archivedConversationListTriggered()
        
        let isRegularSizeClass = isRegularSizeClass()
        guard isRegularSizeClass else {
            return
        }
        
        selectionManager.allowSelectionSetting = false
        clearsSelectionOnViewWillAppear = isRegularSizeClass
    }
    
    @objc func newMessage() {
        let viewController = UINavigationController(rootViewController: StartChatViewController())
        present(viewController, animated: true, completion: nil)
    }
}

// MARK: - TableView

extension ConversationListViewController {
    
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
            setToolbarItems()
            return
        }
        
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            DDLogError("Could not select cell because there was no conversation for its indexPath")
            return
        }
        
        selectionManager.select(conversation: conversation, at: indexPath)

        delegate?.didSelectConversation(conversation: conversation)
        
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
        updateNavigationBarContent()
    }
    
    override func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        guard didStartMultiselect else {
            return
        }
        
        if tableView.indexPathsForSelectedRows == nil {
            hideToolbar()
            didStartMultiselect = false
            updateNavigationBarContent()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        updateNavigationBarContent()
    }
}

// MARK: - Swipe Actions

extension ConversationListViewController {
    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            return nil
        }
        
        let readAction = createReadAction(conversation: conversation)
        let pinAction = createPinAction(conversation: conversation)
        let privateAction = ConversationListViewControllerHelper.createPrivateAction(
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
        guard let conversation = fetchedResultsController.object(at: indexPath) as? ConversationEntity else {
            return nil
        }
        
        // Archive
        
        let archiveAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, handler in
            guard let self else {
                return
            }
            
            UserReminder.maybeShowArchiveInfo(on: self)
            utilities.archive(conversation)
            updateArchivedButton()
            handler(true)
        }
        
        archiveAction.image = UIImage(systemName: "archivebox.fill")
        archiveAction.title = #localize("archive")
        archiveAction.accessibilityLabel = #localize("archive")
        archiveAction.backgroundColor = .systemGray
        
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
        deleteAction.title = #localize("delete")
        deleteAction.accessibilityLabel = #localize("delete")
        
        let configuration = UISwipeActionsConfiguration(actions: [archiveAction, deleteAction])
        
        return configuration
    }
    
    /// Creates the Pin Action for the ContextMenu
    /// - Parameter conversation: ConversationEntity for Action
    /// - Returns: ContextualAction for SwipeMenu of Cell
    private func createPinAction(conversation: ConversationEntity) -> UIContextualAction {
        
        let isPinned = conversation.conversationVisibility == .pinned
        let pinTitle: String =
            if isPinned {
                #localize("unpin")
            }
            else {
                #localize("pin")
            }
        
        let pinAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, handler in
            guard let self else {
                return
            }
            
            if isPinned {
                businessInjector.conversationStore.unpin(conversation)
            }
            else {
                businessInjector.conversationStore.pin(conversation)
            }
            
            handler(true)
        }
        
        if isPinned {
            pinAction.image = UIImage(systemName: "pin.slash.fill")
        }
        else {
            pinAction.image = UIImage(systemName: "pin.fill")
        }

        pinAction.title = pinTitle
        pinAction.accessibilityLabel = pinTitle
        pinAction.backgroundColor = .pin
        return pinAction
    }
    
    /// Creates the Read Action for the ContextMenu
    /// - Parameter conversation: ConversationEntity for Action
    /// - Returns: ContextualAction for SwipeMenu of Cell
    private func createReadAction(conversation: ConversationEntity) -> UIContextualAction {
        
        let hasUnread = conversation.unreadMessageCount.intValue != 0
        let unreadTitle: String =
            if hasUnread {
                #localize("read")
            }
            else {
                #localize("unread")
            }
        
        let readAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, handler in
            guard let self else {
                return
            }
            
            if hasUnread {
                Task {
                    await self.utilities.read(conversation, isAppInBackground: AppDelegate.shared().isAppInBackground())
                }
            }
            else {
                utilities.unread(conversation)
            }
            
            handler(true)
        }
        
        if hasUnread {
            readAction.image = UIImage(systemName: "eye.fill")
        }
        else {
            readAction.image = UIImage(systemName: "envelope.badge.fill")
        }
        readAction.title = unreadTitle
        readAction.accessibilityLabel = unreadTitle
        readAction.backgroundColor = .systemBlue
        return readAction
    }
}

// MARK: - CellContextMenu

extension ConversationListViewController {
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

extension ConversationListViewController {
    /// Shows Toolbar and enters Edit-Mode
    private func showToolbar() {
        setEditing(true, animated: true)
        archivedChatsButton.isHidden = true
        
        // Nav Bar
        if #available(iOS 26.0, *) {
            cancelButton.style = .plain
        }
        else {
            cancelButton.style = .done
        }
        
        navigationItem.rightBarButtonItem = cancelButton
        navigationItem.leftBarButtonItems = [selectAllButton]
        navigationItem.searchController = nil
        
        toolbarReadButton.isEnabled = false
        toolbarArchiveButton.isEnabled = false
        setToolbarItems()

        bottomToolbar.isHidden = false
    }
    
    /// Hides Toolbar and exits Edit-Mode
    @objc private func hideToolbar() {
        // Properties
        setEditing(false, animated: true)
        allSelected = false
        bottomToolbar.isHidden = true
        archivedChatsButton.isHidden = false
        
        // Navbar
        navigationItem.leftBarButtonItem = editButton
        navigationItem.rightBarButtonItem = newChatButton
        if !AppLaunchManager.isRemoteSecretEnabled {
            navigationItem.searchController = searchController
        }
        navigationItem.title = #localize("chats_title")
    }
    
    /// Marks selected Conversations as "Read"
    @objc private func readSelected() {
        ConversationListViewControllerHelper.readConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) { [weak self] in
            self?.hideToolbar()
        }
    }
    
    /// Marks selected Conversations as "Unread"
    @objc private func unreadSelected() {
        ConversationListViewControllerHelper.unreadConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) { [weak self] in
            self?.hideToolbar()
        }
    }
    
    /// Archives selected Conversations
    @objc private func archiveSelected() {
        ConversationListViewControllerHelper.archiveConversations(
            at: tableView.indexPathsForSelectedRows,
            fetchedResultsController: fetchedResultsController,
            businessInjector: businessInjector
        ) { [weak self] in
            self?.hideToolbar()
        }
        updateArchivedButton()
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
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
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
            navigationItem.title = #localize("chats_title")
            toolbarReadButton.isEnabled = false
            toolbarArchiveButton.isEnabled = false
        }
    }
    
    /// Sets the ToolbarItems depending on the selection of Cells
    private func setToolbarItems() {
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        bottomToolbar.items = [toolbarReadButton, flexSpace, toolbarArchiveButton]

        guard let selected = tableView.indexPathsForSelectedRows else {
            return
        }

        if selected.contains(where: { path in
            (fetchedResultsController.object(at: path) as? ConversationEntity)?.unreadMessageCount != 0
        }) {
            return
        }

        bottomToolbar.items = [toolbarUnreadButton, flexSpace, toolbarArchiveButton]
    }
}

// MARK: - Other

extension ConversationListViewController {
    
    private func setBackButton(unread: Int) {
        setBackButtonDebounceTask?.cancel()
        
        setBackButtonDebounceTask = Task { @MainActor in
            // Wait a bit such that the there is no fast showing and hiding of the unread count if it switches back and
            // and forth between 0 and another number (e.g. when the chat opens)
            // This needs to be in sync with the sleep in `ChatProfileView.updateWidthConstraint(debounce:)`
            guard await (try? Task.sleep(for: .milliseconds(500))) != nil else {
                // no-op as we just not run it when canceled
                return
            }
            
            let backButton: UIBarButtonItem
            
            if #available(iOS 26.0, *) {
                backButton = UIBarButtonItem(
                    image: self.unreadCountImage(count: unread),
                    style: .plain,
                    target: nil,
                    action: nil
                )
            }
            else {
                var backButtonTitle = " "
                
                if unread > 0 {
                    backButtonTitle = String(unread)
                }
                
                backButton = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
            }
            
            backButton.accessibilityLabel = String.localizedStringWithFormat(
                #localize("chat_back_button_accessibility"),
                unread
            )
            
            self.navigationItem.backBarButtonItem = backButton
        }
    }
    
    private func unreadCountImage(count: Int) -> UIImage? {
        guard count > 0 else {
            return nil
        }
        
        // Use specific SwiftUI view to render unread count image
        
        let unreadCountBackButtonView = UnreadCountBackButtonView(count: count)
         
        let unreadCountBackButtonImageRenderer = ImageRenderer(content: unreadCountBackButtonView)
        unreadCountBackButtonImageRenderer.scale = UIScreen.main.scale
        
        return unreadCountBackButtonImageRenderer.uiImage
    }
    
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
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavigationBarContent()
    }
    
    private func updateNavigationBarContent() {
        guard let navigationController = navigationController as? StatusNavigationController else {
            return
        }
        
        navigationController.updateNavigationBarContent()
    }
    
    /// Enables or Disables the ArchiveButton
    private func updateArchivedButton() {
        let em = businessInjector.entityManager
        let count = em.performAndWait {
            em.entityFetcher.archivedConversationEntitiesCount()
        }
        
        var configuration = archivedChatsButton.configuration ?? .plain()
        
        if count > 0 {
            archivedChatsButton.isHidden = false
            configuration.title = #localize("archived_chats")
            configuration.image = UIImage(systemName: "chevron.forward")
            archivedChatsButton.isEnabled = true
        }
        else if !tableView.visibleCells.isEmpty {
            configuration.title = #localize("no_archived_chats")
            configuration.image = nil
            archivedChatsButton.isEnabled = false
            archivedChatsButton.isHidden = false
        }
        else {
            archivedChatsButton.isHidden = true
        }
        
        archivedChatsButton.configuration = configuration
    }
    
    public func removeSelectedConversation() {
        selectionManager.removeSelection()
    }
}

// MARK: - Notifications

extension ConversationListViewController {
    
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
            selector: #selector(changedManagedObjects),
            name: DatabaseContext.changedManagedObjects,
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
        UserSettings.shared().addObserver(
            self,
            forKeyPath: "blacklist",
            context: nil
        )
    }
    
    @objc private func unreadMessageCountChanged(_ notification: Notification) {
        let unread: Int = notification.userInfo?[kKeyUnread] as? Int ?? 0
        
        let selectedConversationUnreadCount = selectedConversation?.managedObjectContext?.performAndWait {
            selectedConversation?.unreadMessageCount.intValue
        }
                
        // To prevent short appearances of an unread count in the back button in the selected chat (with annoying
        // animations or breaking constraints in iOS 26+) we only update the unread count when there are not unread
        // messages in the selected chat or the selected chat is not the only one with unread messages
        guard selectedConversationUnreadCount == 0 || selectedConversationUnreadCount != unread else {
            DDLogNotice(
                "Selected conversation has no unread message or unread count only comes from the selected conversation"
            )
            return
        }
        
        setBackButton(unread: unread)
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
            refreshConversationsDelay?.invalidate()
            refreshConversationsDelay = Timer.scheduledTimer(
                timeInterval: TimeInterval(0.1),
                target: self,
                selector: #selector(refreshConversations),
                userInfo: nil,
                repeats: false
            )
        }
    }

    @objc private func refreshConversations() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshData()
            self?.notificationManager.updateUnreadMessagesCount()
        }
    }
    
    @objc private func colorThemeChanged() {
        Colors.update(searchBar: searchController.searchBar)
    }
    
    @objc private func updateDraftForCell() {
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
    
    /// Updates the Predicates to the default and refreshes the TableView
    @objc private func updatePredicates() {
        var newPredicate: NSPredicate
        let archivedPredicate = NSPredicate(format: "visibility != %d", ConversationEntity.Visibility.archived.rawValue)
        let privatePredicate = NSPredicate(format: "category != %d", ConversationEntity.Category.private.rawValue)
        let lastUpdateNotNil = NSPredicate(format: "lastUpdate != nil")
        
        if businessInjector.userSettings.hidePrivateChats {
            newPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                archivedPredicate,
                lastUpdateNotNil,
                privatePredicate,
            ])
        }
        else {
            newPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                archivedPredicate,
                lastUpdateNotNil,
            ])
        }
        
        if fetchedResultsController.fetchRequest.predicate != newPredicate {
            fetchedResultsController.fetchRequest.predicate = newPredicate
            refreshData()
        }
    }
    
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "blacklist" else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            
            for case let conversationCell as ConversationTableViewCell in self.tableView.visibleCells {
                conversationCell.updateCellTitle()
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConversationListViewController: NSFetchedResultsControllerDelegate {
    
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
            guard let indexPath = newIndexPath else {
                return
            }
            tableView.insertRows(at: [indexPath], with: .automatic)
            
        case .delete:
            guard let indexPath else {
                return
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
            
        case .move:
            guard let indexPath,
                  let newIndexPath else {
                return
            }
            tableView.moveRow(at: indexPath, to: newIndexPath)
            
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
