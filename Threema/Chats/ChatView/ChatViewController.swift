//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import DifferenceKit
import OSLog
import ThreemaFramework
import UIKit

// Used to instrument new ChatView (TODO: Remove before release)
class PointsOfInterestSignpost: NSObject {
    @objc static let log = OSLog(subsystem: "ch.threema.iapp.newChatView", category: .pointsOfInterest)
}

/// The chat view!
///
/// TODO: Describe "architecture/dependencies"
final class ChatViewController: ThemedViewController {
    
    // MARK: - Model

    /// Conversation shown in this chat view
    /// This should not be accessed outside of this class. It will be marked as private as soon as ChatViewControllerActions have been refactor to incorporate this.
    @available(
        iOS,
        deprecated: 0.0,
        message: "Must not be used outside of ChatViewController, except in the PPAssetsActionHelperDelegate extension and in MainTabBarController."
    )
    @objc let conversation: Conversation
    
    private let entityManager: EntityManager
    
    public lazy var photoBrowserWrapper = MWPhotoBrowserWrapper(
        for: conversation,
        in: self,
        entityManager: entityManager
    )
    
    // MARK: - UI
    
    // MARK: Header
    
    public lazy var chatViewActionsHelper = ChatViewControllerActionsHelper(
        conversation: self.conversation,
        chatViewController: self
    )
    
    private lazy var chatProfileView: ChatProfileView = {
        let profileView = ChatProfileView(for: conversation)
        profileView.delegate = self
        return profileView
    }()
    
    private lazy var callBarButtonItem = UIBarButtonItem(
        image: BundleUtil.imageNamed("ThreemaPhone"),
        style: .plain,
        target: self,
        action: #selector(startVoIPCall)
    )
    
    private lazy var ballotButton = BallotWithOpenCountButton(target: self, action: #selector(showBallots))
    
    // MARK: Table view
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        
        tableView.allowsSelection = false
        tableView.allowsMultipleSelection = false
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.separatorStyle = .none
        
        tableView.delegate = self
        
        return tableView
    }()
    
    private lazy var dataSource = ChatViewDataSource(
        for: conversation,
        in: tableView,
        delegate: self,
        chatViewTableViewCellDelegate: self,
        entityManager: entityManager,
        loadAround: chatScrollPositionProvider.chatScrollPosition(for: conversation)?.messageDate
    ) { [weak self] in
        // TODO: (IS-2014) Maybe don't show messages until restoration completes to disable flickering if restoration
        // fails and we load messages at the bottom
        self?.restoreScrollPosition()
    }
    
    private let chatScrollPositionProvider: ChatScrollPositionProvider
    
    // Cell height caching
    private let cellHeightCache = CellHeightCache()
    
    // MARK: Compose bar
    
    lazy var chatBarCoordinator = ChatBarCoordinator(
        conversation: conversation,
        chatViewControllerActionsHelper: chatViewActionsHelper,
        chatViewController: self
    )

    private var bottomComposeConstraint: NSLayoutConstraint?
    
    // MARK: Loading messages
    
    // TODO: (IOS-2014) Tweak these variables
    /// Threshold when to load more data at the top
    private let topOffsetThreshold: CGFloat = 1500
    /// Threshold when to load more data at the bottom
    private let bottomOffsetThreshold: CGFloat = 1500
    
    /// Threshold when `isAtBottomOfView` should report that we scrolled all the way to the bottom of the view
    private let isAtBottomOfViewThreshold: CGFloat = 10
    
    /// Are we scrolled to the newest message at the bottom and should we scroll down when the next snapshot is applied?
    private var shouldScrollToBottomAfterNextSnapshotApply = false
    
    /// Are we jumping to a message (this includes the bottom)
    ///
    /// Use `completeJumping()` to reset this value to `false`.
    private var isJumping = false
    
    // MARK: Experimenting and measuring
    
    // TODO: (IOS-2014) remove
    
    private var firstCellShown = false
    
    // MARK: - Lifecycle
    
    /// Create a new chat view
    /// - Parameters:
    ///   - conversation: Conversation to display in chat view
    ///   - entityManger: Entity manager to load messages
    init(
        for conversation: Conversation,
        entityManger: EntityManager = EntityManager(),
        chatScrollPositionProvider: ChatScrollPositionProvider = ChatScrollPosition.shared
    ) {
        self.conversation = conversation
        self.entityManager = entityManger
        self.chatScrollPositionProvider = chatScrollPositionProvider
        
        super.init(nibName: nil, bundle: nil)
        
        // Tab bar
        if UIDevice.current.userInterfaceIdiom == .pad {
            hidesBottomBarWhenPushed = false
        }
        else {
            hidesBottomBarWhenPushed = true
        }
    }
    
    /// Create a new chat view
    /// - Parameters:
    ///   - conversation: Conversation to display in chat view
    @objc convenience init(
        conversation: Conversation
    ) {
        self.init(for: conversation)
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Not supported")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // TODO: See `configureLayout`
    //    override func loadView() {
    //        // Do NOT call `super`!
    //        view = tableView
    //    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addObservers()
        addGestureRecognizers()
        
        configureNavigationBar()
        configureTableView()
        
        configureLayout()
        updateColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateContentInsets()
        chatBarCoordinator.updateSettings()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
        readUnreadMessages()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        chatBarCoordinator.saveDraft()
        chatBarCoordinator.sendTypingIndicator(startTyping: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        saveCurrentScrollPosition()
    }
    
    deinit {
        DDLogDebug("\(#function)")
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    private func addGestureRecognizers() {
        // TODO: Is this really needed?
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tapGesture.cancelsTouchesInView = true
        tableView.addGestureRecognizer(tapGesture)
    }
    
    private func configureLayout() {
        // TODO: Configure layout such that the table view scrolls behind the compose bar & we can set the table view
        // to be the view of the VC instead of another general view (see `loadView`)
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chatBarCoordinator.chatBarContainerView)
        chatBarCoordinator.chatBarContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        bottomComposeConstraint = chatBarCoordinator.chatBarContainerView.bottomAnchor
            .constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            chatBarCoordinator.chatBarContainerView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            chatBarCoordinator.chatBarContainerView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            bottomComposeConstraint!,
        ])
    }
    
    // MARK: - Overrides
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateChatProfileViewSettings()
    }
    
    override func viewDidLayoutSubviews() {
        updateContentInsets()
    }
    
    override func updateColors() {
        super.updateColors()
        
        for cell in tableView.visibleCells {
            if let chatViewBaseCell = cell as? ChatViewBaseTableViewCell {
                chatViewBaseCell.updateColors()
                continue
            }
            else if let systemMessageCell = cell as? ChatViewSystemMessageTableViewCell {
                systemMessageCell.updateColors()
            }
        }
        
        view.backgroundColor = .clear
        chatBarCoordinator.updateColors()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        cellHeightCache.clear()
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    // MARK: - Private Functions
    
    private func readUnreadMessages() {
        let conversationActions = ConversationActions(entityManager: entityManager)
        conversationActions.read(conversation)
    }
    
    // MARK: - Notifications
    
    @objc private func applicationDidEnterBackground() {
        saveCurrentScrollPosition()
    }
    
    @objc func hideKeyboard() {
        chatBarCoordinator.endEditing()
    }
    
    @objc func preferredContentSizeCategoryDidChange() {
        cellHeightCache.clear()
    }
    
    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        guard let bottomComposeConstraint = bottomComposeConstraint else {
            assertionFailure("Must have bottomComposeConstraint in order to react to keyboard show/hide notifications.")
            return
        }
        
        // This avoids updating the constraint when a modally presented shows the keyboard
        // We still want to update the constraint when PPAssetsActionController is presented.
        // See MR of IOS-2403 for a more detailed discussion.
        guard presentedViewController == nil || presentedViewController is PPAssetsActionController else {
            return
        }
        
        KeyboardConstraintHelper.updateLayoutForKeyboard(
            view: view,
            constraint: bottomComposeConstraint,
            notification: notification,
            action: {
                self.updateContentInsets()
                self.view.layoutIfNeeded()
                
                // It is unclear why this is needed but if we do not relayout the chatbar here, its height will not be updated.
                self.chatBarCoordinator.chatBarContainerView.setNeedsLayout()
                self.chatBarCoordinator.chatBarContainerView.layoutIfNeeded()
            },
            completion: nil
        )
    }
}

// MARK: - ChatProfileViewDelegate

extension ChatViewController: ChatProfileViewDelegate {
    // MARK: Chat Navigation Bar
    
    private func configureNavigationBar() {
        
        // Note: The back button is set in `ConversationsViewController` and cannot be overridden here
        
        // Configure chat profile view
        // See `ChatProfileView` why we choose this solution
        
        navigationItem.largeTitleDisplayMode = .never
        
        updateChatProfileViewSettings()
        navigationItem.titleView = chatProfileView
        
        // Configure right bar button item
        
        if conversation.isGroup() {
            updateOpenBallotsButton()
        }
        else {
            // Only show call icon if Threema calls are enabled and contact supports them
            if UserSettings.shared()?.enableThreemaCall == true,
               let contact = conversation.contact {
                let contactSet = Set<Contact>([contact])
                
                FeatureMask.check(Int(FEATURE_MASK_VOIP), forContacts: contactSet) { unsupportedContacts in
                    if unsupportedContacts?.isEmpty == true {
                        self.callBarButtonItem.accessibilityLabel = BundleUtil.localizedString(forKey: "call")
                        self.navigationItem.rightBarButtonItem = self.callBarButtonItem
                    }
                }
            }
        }
    }
    
    private func updateChatProfileViewSettings() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        
        let safeAreaAdjustedBounds = navigationBar.bounds.inset(by: navigationBar.safeAreaInsets)
        chatProfileView.safeAreaAdjustedNavigationBarWidth = safeAreaAdjustedBounds.width
    }
    
    /// Update open ballots button
    ///
    /// If count goes to 0 it disappears or if goes above 0 it (re)appears
    ///
    /// As it is complicated to observe ballot changes we just call this function on every instance creation of the view or new (ballot)
    /// message received.
    private func updateOpenBallotsButton() {
        guard conversation.isGroup() else {
            return
        }
        
        let numberOfOpenBallots = entityManager.entityFetcher.countOpenBallots(for: conversation)
        
        // Only show ballots icon if we have open polls
        if numberOfOpenBallots > 0 {
            ballotButton.openBallotsCount = UInt(numberOfOpenBallots)
            
            if navigationItem.rightBarButtonItems == nil {
                navigationItem.rightBarButtonItems = ballotButton.asRightBarButtonItems()
            }
        }
        else {
            navigationItem.rightBarButtonItems = nil
        }
    }
    
    /// `ChatProfileViewDelegate` method
    func chatProfileViewTapped(_ chatProfileView: ChatProfileView) {
        let detailsViewController: UIViewController
        
        if conversation.isGroup() {
            guard let group = GroupManager().getGroup(conversation: conversation) else {
                fatalError("No group conversation found for this conversation")
            }
            
            detailsViewController = GroupDetailsViewController(for: group, displayMode: .conversation)
        }
        else {
            detailsViewController = SingleDetailsViewController(for: conversation)
        }
        
        let navigationController = ModalNavigationController(rootViewController: detailsViewController)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.modalDelegate = self
        
        present(navigationController, animated: true)
    }
    
    /// Start VoIP call
    ///
    /// - Note: Only call this if you previously checked if `conversation.contact` supports calls
    @objc private func startVoIPCall() {
        
        guard let contact = conversation.contact else {
            DDLogError("Conversation.Contact is unexpectedly nil")
            return
        }
        // We assume that the contact supports calls
        let action = VoIPCallUserAction(
            action: .call,
            contactIdentity: contact.identity,
            callID: nil,
            completion: nil
        )
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @objc private func showBallots() {
        guard let ballotViewController = BallotListTableViewController.ballotListViewController(for: conversation)
        else {
            UIAlertTemplate.showAlert(owner: self, title: "Polls unavailable", message: nil)
            return
        }
        
        // Encapsulate the `BallotListTableViewController` inside a navigation controller for modal
        // presentation
        let navigationController = ThemedNavigationController(rootViewController: ballotViewController)
        present(navigationController, animated: true)
    }
}

// MARK: - Table View

extension ChatViewController {
    private func configureTableView() {
        // This needs to be done here and not in the lazy `tableView` initializer. Otherwise we get an infinite loop.
        tableView.dataSource = dataSource
        // TODO: This should be interactive. But then we need additional changes to the ChatBarView
        tableView.keyboardDismissMode = .onDrag
    }
    
    // MARK: Scroll
    
    private func scrollToBottom(animated: Bool) {
        // TODO: (IOS-2014) Should we check if we're already scrolling to the bottom here?
        
        guard let bottomIndexPath = dataSource.bottomIndexPath else {
            // Use scroll view API to go to bottom instead of table view if now index path is available
            DDLogVerbose("Fallback for scroll to bottom")
            let bottomContentOffset = tableView.contentSize.height
                - tableView.frame.height
                + tableView.adjustedContentInset.bottom
            
            tableView.setContentOffset(
                CGPoint(x: tableView.contentOffset.x, y: bottomContentOffset),
                animated: animated
            )
            
            return
        }
        
        DDLogVerbose("Scroll to bottom index path...")
        tableView.scrollToRow(at: bottomIndexPath, at: .bottom, animated: animated)
        
        // Continue scrolling to the bottom if a new index path showed up at the bottom
        // If loading new messages is faster than 400 ms this allows scrolling all the way to the bottom
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
            if let newBottomIndexPath = self.dataSource.bottomIndexPath,
               bottomIndexPath != newBottomIndexPath {
                DDLogVerbose("Continue scrolling to bottom...")
                self.scrollToBottom(animated: animated)
            }
        }
    }
    
    // MARK: Jump
    
    private func completeJumping() {
        // Wait a bit until scrolling should be somewhat completed
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
            self.isJumping = false
        }
    }
    
    private func jumpToBottom() {
        isJumping = true
        dataSource.loadNewestMessages().done {
            self.scrollToBottom(animated: true)
            self.completeJumping()
        }
    }
    
    private func jump(to messageID: Data) {
        guard let message = entityManager.entityFetcher.message(
            with: messageID,
            conversation: conversation
        ) else {
            DDLogWarn(
                "Unable to load message (\(messageID.hexString)) to jump to. It doesn't exist or is not in this conversation."
            )
            return
        }
        
        isJumping = true
        dataSource.loadMessages(around: message.date).done {
            if let indexPath = self.dataSource.indexPath(for: message.objectID) {
                self.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
            }
            
            self.completeJumping()
        }
    }
    
    // MARK: Bottom information
    
    /// We scrolled all the way to the bottom of the view
    ///
    /// - Note: This does not mean there are more messages that can be loaded at the bottom.
    private var isAtBottomOfView: Bool {
        let bottomOffset = insetAdjustedBottomOffset(for: tableView)
        
        // Add some threshold if we are really close to bottom
        if bottomOffset < isAtBottomOfViewThreshold {
            return true
        }
        
        return false
    }
    
    private func insetAdjustedBottomOffset(for scrollView: UIScrollView) -> CGFloat {
        let currentContentOffsetY = scrollView.contentOffset.y
        // Content offset is below the top adjusted content inset so we only need to adjust for the bottom inset
        let currentAdjustedHeight = scrollView.frame.height - scrollView.adjustedContentInset.bottom
        let currentContentHeight = scrollView.contentSize.height
        
        return currentContentHeight - (currentContentOffsetY + currentAdjustedHeight)
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
    
    // MARK: Cell height caching
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Cache height calculated by the system
        if let objectID = dataSource.itemIdentifier(for: indexPath) {
            cellHeightCache.storeCellHeight(cell.frame.height, for: objectID)
        }
        
        // TODO: Just for measuring speed. Remove after completion
        if !firstCellShown {
            os_signpost(.end, log: PointsOfInterestSignpost.log, name: "showChat")
            firstCellShown = true
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard ChatViewConfiguration.enableEstimatedCellHeightCaching else {
            return UITableView.automaticDimension
        }
        
        guard let objectID = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        
        // Try caches
        
        if let height = cellHeightCache.cellHeight(for: objectID) {
            return height
        }
        
        if let estimatedHeight = cellHeightCache.estimatedCellHeight(for: objectID) {
            return estimatedHeight
        }
        
        // Calculate estimated height
        
        guard let message = dataSource.message(for: objectID) else {
            return UITableView.automaticDimension
        }
        
        let tableViewWidth = tableView.frame.width
       
        // Used to solve breaking constraints before table view is visible
        if tableViewWidth == 0 {
            return UITableView.automaticDimension
        }
        
        let estimatedHeight = ChatViewCellSizeProvider.estimatedCellHeight(for: message, with: tableViewWidth)
        cellHeightCache.storeEstimatedCellHeight(estimatedHeight, for: objectID)
        
        return estimatedHeight
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard ChatViewConfiguration.enableCellHeightCaching else {
            return UITableView.automaticDimension
        }
        
        guard let objectID = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        
        if let size = cellHeightCache.cellHeight(for: objectID) {
            return size
        }
        
        // With no cached value we let the system do the correct calculation
        return UITableView.automaticDimension
    }
    
    // MARK: ContextMenu

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        
        // Check if cell conforms to `ContextMenuAction`
        guard let cell = tableView.cellForRow(at: indexPath) as? ContextMenuAction else {
            return nil
        }
        
        return cell.buildContextMenu(at: indexPath)
    }
    
    func tableView(
        _ tableView: UITableView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = tableView.cellForRow(at: indexPath) as? ChatViewBaseTableViewCell else {
            return nil
        }
        return makeUITargetedPreview(for: cell)
    }
    
    func tableView(
        _ tableView: UITableView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = tableView.cellForRow(at: indexPath) as? ChatViewBaseTableViewCell else {
            return nil
        }
        return makeUITargetedPreview(for: cell)
    }
    
    private func makeUITargetedPreview(for cell: ChatViewBaseTableViewCell) -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.visiblePath = cell.chatBubbleBorderPath
        parameters.backgroundColor = .clear
        
        return UITargetedPreview(view: cell.chatBubbleView, parameters: parameters)
    }
}

// MARK: - ChatViewDataSourceDelegate

extension ChatViewController: ChatViewDataSourceDelegate {
    func willApplySnapshot(currentDoesIncludeNewestMessage: Bool) {
        DDLogVerbose("willApplySnapshot")
        
        // Don't scroll to bottom if we jump from the bottom
        guard !isJumping else {
            shouldScrollToBottomAfterNextSnapshotApply = false
            return
        }
        
        // This might be called again before the previous snapshot was applied so we still want to
        // to scroll to the bottom.
        guard !shouldScrollToBottomAfterNextSnapshotApply else {
            return
        }
        
        shouldScrollToBottomAfterNextSnapshotApply = currentDoesIncludeNewestMessage && isAtBottomOfView
    }
    
    func didApplySnapshot() {
        DDLogVerbose("didApplySnapshot")
        
        if shouldScrollToBottomAfterNextSnapshotApply {
            scrollToBottom(animated: true)
        }
        
        shouldScrollToBottomAfterNextSnapshotApply = false
        
        readUnreadMessages()
    }
}

// MARK: - Scroll position restoration

private extension ChatViewController {
    /// Save current scroll position
    ///
    /// Store the offset from top of a visible cell from the content offset (positive if the cell top is in the visible area).
    private func saveCurrentScrollPosition() {
        chatScrollPositionProvider.removeSavedPosition(for: conversation)
        
        // Check if we are at the bottom of the view
        // We expect that when we scrolled to the bottom of the view that all messages (at the bottom) are loaded until
        // this point and we are at the last message. If this assumption fails we will restore at the bottom next time
        // the chat is opened.
        guard !isAtBottomOfView else {
            DDLogVerbose("We are at the bottom of the Table View")
            return
        }
        
        // Take a random visible cell that conforms to `ChatScrollPositionDataProvider`
        let matchingCell = tableView.visibleCells.first { $0 is ChatScrollPositionDataProvider }
        
        guard let cell = matchingCell as? ChatScrollPositionDataProvider else {
            assertionFailure("No visible ChatScrollPositionDataProvider found")
            return
        }
        
        // Gather all needed data
        let offsetFromTop = cell.minY - tableView.contentOffset.y
        
        guard let messageObjectID = cell.messageObjectID,
              let messageDate = cell.messageDate
        else {
            assertionFailure("Cell has no message information")
            return
        }
        
        chatScrollPositionProvider.save(
            ChatScrollPositionInfo(
                offsetFromTop: offsetFromTop,
                messageObjectIDURL: messageObjectID.uriRepresentation(),
                messageDate: messageDate
            ),
            for: conversation
        )
    }
    
    /// Restore scroll position
    ///
    /// Restore the content offset by taking the new cell top offset and subtracting the stored offset.
    /// If no previous position is available or anything fails we go to the bottom.
    private func restoreScrollPosition() {
        // Just before the the last call in this method completes (i.e. also closures)
        // `dataSource.initialSetupCompleted` should be set to `true` to complete the setup and allow loading of more
        // messages.
        
        guard let previousScrollPosition = chatScrollPositionProvider.chatScrollPosition(
            for: conversation
        ) else {
            DDLogVerbose("No previous scroll position. Scroll to bottom.")
            
            // The newest messages should be loaded so we just scroll to the bottom to optimize
            // performance.
            scrollToBottom(animated: false)
            dataSource.initialSetupCompleted = true
            return
        }
        
        // The correct set of messages should be loaded at this point
        
        // Exit function if some part of the restoration fails
        func restoreAtBottom() {
            DDLogVerbose("Restore at bottom")
            
            chatScrollPositionProvider.removeSavedPosition(for: conversation)
            
            // Ensure that we have the bottom data & then scroll to bottom
            dataSource.loadNewestMessages().done {
                self.scrollToBottom(animated: false)
                self.dataSource.initialSetupCompleted = true
            }
        }
        
        guard let messageObjectID = entityManager.managedObjectID(
            forURIRepresentation: previousScrollPosition.messageObjectIDURL
        ) else {
            DDLogWarn("Unable to restore message object ID")
            restoreAtBottom()
            return
        }
        
        guard let indexPath = dataSource.indexPath(for: messageObjectID) else {
            DDLogWarn("Message not found in data source")
            restoreAtBottom()
            return
        }
        
        // Needed to make the cell available in `cellForRow(at:)`
        tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        
        // Get cell to adjust offset accordingly
        guard let cell = tableView.cellForRow(at: indexPath) else {
            assertionFailure("Unable to find cell for scroll position restoration")
            restoreAtBottom()
            return
        }
        
        // This leads to a little change of offset if restoration happens in another orientation.
        // TODO: (IOS-2014) Is this still a problem? Should we accommodate for that?
        let newOffset = cell.frame.minY - previousScrollPosition.offsetFromTop
        tableView.contentOffset.y = newOffset
        
        chatScrollPositionProvider.removeSavedPosition(for: conversation)
        dataSource.initialSetupCompleted = true
    }
}

// MARK: - UIScrollViewDelegate

extension ChatViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Check if we should load more messages...
        
        // Wait for initial setup to complete
        guard dataSource.initialSetupCompleted else {
            return
        }
        
        // If we cannot load new messages just don't check if we should
        guard !dataSource.isLoadingNewMessages else {
            return
        }
        
        // Don't load more messages while were loading messages and scrolling to the jump position
        guard !isJumping else {
            return
        }
        
        // As we normally scroll from bottom to top we first check the top...
        
        // Not really needed, but allows for more consistency across all devices
        let insetAdjustedTopOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        
        if insetAdjustedTopOffset < topOffsetThreshold {
            dataSource.loadMessagesAtTop()
            return
        }
        
        // ...and then the bottom
        
        // Not really needed, but allows for more consistency across all devices
        let insetAdjustedBottomOffset = insetAdjustedBottomOffset(for: scrollView)
        
        if insetAdjustedBottomOffset < bottomOffsetThreshold {
            dataSource.loadMessagesAtBottom()
        }
    }
    
    // TODO: (IOS-2014) Maybe store scroll position after scrolling finished for a bit (and no new scrolling started).
    //                  Maybe with a timer.
    
    // Scroll to bottom when tapping on top (& scroll view is not at top)
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        jumpToBottom()
        return false
    }
    
    func updateContentInsets() {
        if !Thread.isMainThread {
            assertionFailure("Constraints must be updated on main thread")
        }
        
        view.layoutIfNeeded()
        
        let wasAtBottomOfView = isAtBottomOfView
        let oldYOffset = tableView.contentOffset.y
        
        let oldInsets = tableView.contentInset
        var newInsets = oldInsets
        
        newInsets.bottom = view.frame.maxY - chatBarCoordinator.chatBarContainerView.frame.minY - view.safeAreaInsets
            .bottom
        
        tableView.contentInset = newInsets
        tableView.scrollIndicatorInsets = newInsets
        
        if wasAtBottomOfView {
            scrollToBottom(animated: false)
        }
        else {
            let insetChange = newInsets.bottom - oldInsets.bottom
            let newYOffset = (oldYOffset + insetChange)
            
            tableView.setContentOffset(CGPoint(x: 0, y: newYOffset), animated: false)
        }
    }
}

// MARK: - ChatViewTableViewCellDelegate

extension ChatViewController: ChatViewTableViewCellDelegate {
    func clearCellHeightCache(for objectID: NSManagedObjectID) {
        cellHeightCache.clearCellHeightCache(for: objectID)
    }
    
    func show(identity: String) {
        guard let contact = BusinessInjector().entityManager.entityFetcher.contact(for: identity) else {
            DDLogError("Can't find contact for tapped mention")
            return
        }
        let detailsViewController = SingleDetailsViewController(for: contact)
        let navigationController = ThemedNavigationController(rootViewController: detailsViewController)
        navigationController.modalPresentationStyle = .formSheet
        
        present(navigationController, animated: true)
    }
    
    func didTap(message: BaseMessage?) {
        photoBrowserWrapper.openPhotoBrowser(for: message)
        // TODO: Remove with IOS-2466
    }
    
    func showQuoteView(message: QuoteMessage) {
        chatBarCoordinator.showQuoteView(for: message)
    }
}

// MARK: - ModalNavigationControllerDelegate

extension ChatViewController: ModalNavigationControllerDelegate {
    func willDismissModalNavigationController() {
        if conversation.willBeDeleted {
            navigationController?.popViewController(animated: true)
        }
    }
}
