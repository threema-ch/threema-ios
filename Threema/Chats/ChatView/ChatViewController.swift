//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import Combine
import GroupCalls
import OSLog
import ThreemaFramework
import UIKit
import WebRTC

/// The chat view!
///
/// TODO: Describe "architecture/dependencies"
///
/// For the view hierarchy see `configureLayout()`
final class ChatViewController: ThemedViewController {
    
    var willMoveToNonNilWindow = false {
        didSet {
            if willMoveToNonNilWindow {
                _ = unreadMessagesSnapshot.tick(willStayAtBottomOfView: isAtBottomOfView)
            }
        }
    }
    
    // MARK: - Internal
    
    /// Used to determine whether ChatTextView is currently resetting the keyboard
    /// Resetting the keyboard may cause animations to be cancelled which is not great when new messages are added
    var isResettingKeyboard = false
    
    /// True if the last time `willEnterForeground` was called the window of `view` was nil and we have not yet executed
    /// the checks for the unread message line.
    /// False otherwise; will be set to false after executing the checks for the unread message line.
    /// Part of the workaround for the passcode lock screen. See `ChatViewTableView` for additional info
    var didEnterForegroundWithNilWindow = false
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Model
    
    /// Conversation shown in this chat view
    ///
    /// This should not be accessed outside of this class. It will be marked as private as soon as
    /// ChatViewControllerActions have been refactor to incorporate this.
    @available(
        iOS,
        deprecated: 0.0,
        message: "Must not be used outside of ChatViewController, except in the PPAssetsActionHelperDelegate extension and in MainTabBarController."
    )
    @objc let conversation: Conversation
    
    private let businessInjector: BusinessInjectorProtocol
    private let entityManager: EntityManager
    
    // MARK: - Debug
    
    private let initTime = CACurrentMediaTime()
    
    private var scrollPositionRestoreFinished = false
    
    // MARK: - UI
    
    /// A serial queue used for queueing scrollToRow when initiating scroll to bottom from `didApplySnapshot`.
    /// The queue is needed since we're need to wait until snapshot apply is done before actually programmatically
    /// scrolling.
    private let scrollToQueue = DispatchQueue(label: "ch.threema.chatView.scrollQueue", qos: .userInteractive)
    
    /// Scroll state used to update contentOffset between `willApplySnapshot(currentDoesIncludeNewestMessage:)` and
    /// `didApplySnapshot(delegateScrollCompletion:)`
    private var currentScrollState: ChatViewScrollState?
    
    /// Mode the chat view user interface is in
    enum UserInterfaceMode {
        /// Default chat view
        case `default`
        
        /// Chat search
        case search
        
        /// Multiselect
        case multiselect
        
        /// Preview of chat with no chat bar
        ///
        /// This is intended for non-interactive use. E.g. long-press previews
        case preview
    }
    
    var userInterfaceMode: UserInterfaceMode = .default {
        didSet {
            updateNavigationItem()

            switch userInterfaceMode {
            case .default:
                hideToolbar(animated: true)
                showScrollToBottomButtonAndChatBar()
                
                tableView.setEditing(false, animated: true)
                dataSource.deselectAllMessages()
                
                updateContentInsets()
                enableKeyboardDismissGestureRecognizer()
                
                NSLayoutConstraint.deactivate(multiselectScrollToBottomButtonConstraints)
                NSLayoutConstraint.activate(defaultScrollToBottomButtonConstraints)
                
                // When we start in `preview` mode the messages are not marked as read
                // so we should retry now
                DispatchQueue.global(qos: .userInteractive).async {
                    self.unreadMessagesSnapshot.synchronousReconfiguration()
                }
                
            case .search:
                // The toolbar hiding and showing will be handled by the search functionality
                hideScrollToBottomButtonAndChatBar()
                
                tableView.setEditing(false, animated: true)
                dataSource.deselectAllMessages()

                updateContentInsets()
                enableKeyboardDismissGestureRecognizer()

                NSLayoutConstraint.deactivate(defaultScrollToBottomButtonConstraints)
                NSLayoutConstraint.activate(multiselectScrollToBottomButtonConstraints)
                
            case .multiselect:
                hideToolbar(animated: true)
                hideScrollToBottomButtonAndChatBar()
                
                tableView.setEditing(true, animated: true)
                dataSource.deselectAllMessages()
                
                updateContentInsets()
                disableKeyboardDismissGestureRecognizer()
                
                NSLayoutConstraint.deactivate(defaultScrollToBottomButtonConstraints)
                NSLayoutConstraint.activate(multiselectScrollToBottomButtonConstraints)
                
            case .preview:
                hideToolbar(animated: true)
                hideScrollToBottomButtonAndChatBar()
                
                tableView.setEditing(false, animated: true)
                dataSource.deselectAllMessages()
                
                updateContentInsets()
                disableKeyboardDismissGestureRecognizer()
                
                NSLayoutConstraint.deactivate(defaultScrollToBottomButtonConstraints)
                NSLayoutConstraint.activate(multiselectScrollToBottomButtonConstraints)
            }
        }
    }
    
    var cellInteractionEnabled: Bool {
        userInterfaceMode == .default
    }
    
    /// Provides the background image for the chat view
    private lazy var backgroundView: UIImageView = {
        let backgroundView = UIImageView(frame: .infinite)
        
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        
        return backgroundView
    }()
    
    weak var selectedTextView: MessageTextView?
    
    var contextMenuActionsQueue = [() -> Void]()
    
    // MARK: Header
    
    public lazy var chatViewActionsHelper = ChatViewControllerActionsHelper(
        conversation: self.conversation,
        chatViewController: self
    )
    
    private lazy var chatProfileView = ChatProfileView(
        for: conversation,
        entityManager: entityManager
    ) { [weak self] in
        self?.chatProfileViewTapped()
    }
    
    private lazy var deleteBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: BundleUtil.localizedString(forKey: "messages_delete_all_button"),
            style: .plain,
            target: self,
            action: #selector(showDeleteMessagesAlert)
        )
        button.tintColor = Colors.red
        return button
    }()
    
    private lazy var cancelBarButton = UIBarButtonItem(
        title: BundleUtil.localizedString(forKey: "cancel"),
        style: .done,
        target: self,
        action: #selector(endMultiselect)
    )
    
    private lazy var callBarButtonItem = UIBarButtonItem(
        image: BundleUtil.imageNamed(ChatViewConfiguration.Profile.callSymbolName),
        style: .plain,
        target: self,
        action: #selector(startVoIPCall)
    )
    
    private lazy var ballotBarButton = BallotWithOpenCountButton { [weak self] _ in
        self?.showBallots()
    }
    
    private lazy var groupCallBannerView: GroupCallBannerView = {
        let bannerView = GroupCallBannerView(delegate: self)
        
        bannerView.isHidden = true
        bannerView.translatesAutoresizingMaskIntoConstraints = false
                
        return bannerView
    }()
    
    // MARK: Table view
    
    private lazy var tableView: ChatViewTableView = {
        let tableView = ChatViewTableView(frame: .zero, style: .plain)
        
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        
        // Remove any section header padding
        tableView.sectionHeaderTopPadding = 0
                
        tableView.alpha = 0.0
        
        // This fixes an issue, where voice over selected a random cell after scrolling to bottom when opening the chat
        // view the first time.
        // We set the animations to true again, after we set the alpha back to 1.0
        if UIAccessibility.isVoiceOverRunning {
            UIView.setAnimationsEnabled(false)
        }

        // This also enables programmatic selection
        // Manual selection only allowed in multiselect mode which is ensured by implementing
        // `tableView(_:willSelectRowAt:)`
        tableView.allowsSelection = true
        
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.separatorStyle = .none
        
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.delegate = self
        
        tableView.chatViewDelegate = self
        
        return tableView
    }()
    
    private lazy var dataSource = ChatViewDataSource(
        for: conversation,
        in: tableView,
        delegate: self,
        chatViewTableViewCellDelegate: chatViewTableViewCellDelegate,
        chatViewTableViewVoiceMessageCellDelegate: chatViewTableViewVoiceMessageCellDelegate,
        entityManager: entityManager,
        loadAround: { [weak self] in
            self?.chatViewDataSourceLoadAround()
        },
        afterFirstSnapshotApply: { [weak self] in
            self?.chatViewDataSourceAfterFirstSnapshotApply()
        },
        unreadMessagesSnapshot: unreadMessagesSnapshot
    )
    
    /// Coordinates the number of unread messages that should be displayed and whether the unread message line should be
    /// shown at all
    /// The chatViewDataSource uses this through its delegate to check whether a new snapshot should include the unread
    /// message line or not.
    ///
    /// The unread message line is displayed if the chat is opened and there are unread messages in it or
    /// if the scroll position is not at the very bottom and new messages are received.
    /// It is hidden if the user manually scrolls to the bottom of the chat view either through the scroll to bottom
    /// button or by dragging the scrollView.
    private lazy var unreadMessagesSnapshot = UnreadMessagesStateManager(
        conversation: self.conversation,
        businessInjector: self.businessInjector,
        unreadMessagesStateManagerDelegate: self
    )
    
    private let chatScrollPositionProvider: ChatScrollPositionProvider
    
    private lazy var chatSearchController = ChatSearchController(for: conversation, delegate: self)
    
    private lazy var chatViewTableViewCellDelegate = ChatViewTableViewCellDelegate(
        chatViewController: self,
        tableView: tableView,
        entityManager: entityManager
    )
    
    private lazy var chatViewTableViewVoiceMessageCellDelegate =
        ChatViewTableViewVoiceMessageCellDelegate(chatViewController: self)
    
    // Cell height caching
    private let cellHeightCache = CellHeightCache()
    
    private lazy var scrollToTopHelperView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.contentOffset.y = 1
        scrollView.contentSize.height = view.bounds.height + 1
        
        scrollView.delegate = self
        
        return scrollView
    }()
    
    // MARK: Compose bar
    
    lazy var chatBarCoordinator = ChatBarCoordinator(
        conversation: conversation,
        chatViewControllerActionsHelper: chatViewActionsHelper,
        chatViewController: self,
        chatBarCoordinatorDelegate: self,
        chatViewTableViewVoiceMessageCellDelegate: chatViewTableViewVoiceMessageCellDelegate,
        showConversationInformation: showConversationInformation
    )
    
    private var showConversationInformation: ShowConversationInformation?

    private lazy var scrollToBottomButton = ScrollToBottomView(
        unreadMessagesSnapshot: unreadMessagesSnapshot
    ) { [weak self] in
        guard let self else {
            return
        }
        
        // We cannot do a layout pass during scrolling (otherwise scrolling might be stopped when updating content
        // insets). Thus we do one now
        self.view.layoutIfNeeded()
        
        // If the unread message line is currently visible, we scroll to the very bottom of the view
        let unreadMessageLineVisible = !self.tableView.visibleCells
            .filter { $0 is ChatViewUnreadMessageLineCell }
            .isEmpty
        if unreadMessageLineVisible {
            self.jumpToBottom()
            return
        }
        
        let snapshot = self.dataSource.snapshot()
        
        guard let newestUnreadMessageObjectID = self.unreadMessagesSnapshot.unreadMessagesState?
            .oldestConsecutiveUnreadMessage else {
            self.jumpToBottom()
            return
        }
        
        let itemIdentifiersInScreenOrder = snapshot.itemIdentifiers
        
        // We either scroll to the previously newest unread message or the unread message line
        for item in itemIdentifiersInScreenOrder {
            if case let ChatViewDataSource.CellType.message(objectID: objectID) = item,
               objectID == newestUnreadMessageObjectID {
                self.jumpToBottom()
                break
            }
            if case let ChatViewDataSource.CellType.unreadLine(state: state) = item {
                guard let newestUnreadMessageObjectID = state.oldestConsecutiveUnreadMessage else {
                    
                    self.jumpToBottom()
                    return
                }
                guard let message = self.entityManager.entityFetcher
                    .existingObject(with: newestUnreadMessageObjectID) as? BaseMessage else {
                    
                    self.jumpToBottom()
                    return
                }
                
                self.jump(toUnreadMessage: message.id) { _ in
                    if self.isAtBottomOfView {
                        self.userIsAtBottomOfTableView = true
                    }
                }
                break
            }
        }
    }
    
    private lazy var bottomComposeConstraint = view.keyboardLayoutGuide.topAnchor
        .constraint(equalTo: chatBarCoordinator.chatBarContainerView.bottomAnchor)
    
    private lazy var topComposeConstraint = chatBarCoordinator.chatBarContainerView.topAnchor.constraint(
        greaterThanOrEqualTo: tableView.topAnchor,
        constant: ChatViewConfiguration.ChatBar.tableViewChatBarMinSpacing
    )
    
    private lazy var defaultScrollToBottomButtonConstraints: [NSLayoutConstraint] = {
        [
            scrollToBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollToBottomButton.bottomAnchor.constraint(
                equalTo: chatBarCoordinator.chatBarContainerView.topAnchor,
                constant: -ChatViewConfiguration.ScrollToBottomButton.distanceToChatBar
            ),
        ]
    }()
    
    private lazy var multiselectScrollToBottomButtonConstraints: [NSLayoutConstraint] = {
        [
            scrollToBottomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollToBottomButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ]
    }()
    
    // MARK: Loading messages
    
    // TODO: (IOS-2014) Tweak these variables
    /// Threshold when to load more data at the top
    private let topOffsetThreshold: CGFloat = 1500
    /// Threshold when to load more data at the bottom
    private let bottomOffsetThreshold: CGFloat = 1500
    
    /// Threshold when `isAtBottomOfView` should report that we scrolled all the way to the bottom of the view
    private let isAtBottomOfViewThreshold: CGFloat = 25 + ChatViewConfiguration.bottomInset
    
    /// Completion handler to be called after scrolling did end. Updated by `didApplySnapshot`
    private var scrollCompletion: (() -> Void)?
    
    /// Will cancel `willEnterForegroundCompletion` if it isn't executed before the timer finishes
    private var willEnterForeGroundCompletionTimer: Timer?
    
    /// Upon reentering foreground we might want to scroll the unread message line but it might not be loaded
    ///
    /// This allows us to add a task which is then executed either immediately if the unread message line is already
    /// showing or on next `didApplySnapshot`.
    private var willEnterForegroundCompletion: (((() -> Void)?) -> Void)? {
        didSet {
            if willEnterForegroundCompletion == nil {
                willEnterForeGroundCompletionTimer?.invalidate()
                willEnterForeGroundCompletionTimer = nil
            }
            else {
                willEnterForeGroundCompletionTimer = Timer.scheduledTimer(
                    withTimeInterval: ChatViewConfiguration.UnreadMessageLine.completionTimeout,
                    repeats: false
                ) { _ in
                    self.willEnterForegroundCompletion = nil
                }
            }
        }
    }
    
    /// Are we scrolled to the newest message at the bottom and should we scroll down when the next snapshot is applied?
    private var shouldScrollToBottomAfterNextSnapshotApply = false
    
    /// Are we jumping to a message (this includes the bottom)
    ///
    /// Use `completeJumping()` to reset this value to `false`.
    private var isJumping = false
    
    private var isScrolling = false
    /// This is true while we are programmatically scrolling to bottom or when the scrolling was cancelled and we are
    /// not scrolling anymore
    /// Before setting `isProgrammaticallyScrollingToBottom` `isScrolling` must always been set to true
    private var isProgrammaticallyScrollingToBottom = false {
        didSet {
            if ChatViewConfiguration.strictMode, isProgrammaticallyScrollingToBottom, !isScrolling {
                fatalError("Consistency error for scrolling variables")
            }
        }
    }
    
    /// When the keyboard was shown before the ContextMenu opened, we need to block inset updates. Otherwise the layout
    /// will break when we enter the multi select mode through it.
    private var insetUpdatesBlockedByContextMenu = false
    
    /// True between `willApplySnapshot` and `didApplySnapshot`
    private var isApplyingSnapshot = false
    
    /// These are used to determine whether it is safe to load new messages.
    /// During dragging adding new table view cells might throw of the scroll position.
    private var isDragging = false
    /// During an in-progress load request new load requests should not be issued
    private var isLoading = false
    
    private var isUserInteractiveScroll = false
    
    private var isApplicationInForeground = true
    var willDisappear = false {
        didSet {
            DDLogVerbose("\(#function) willDisappear \(willDisappear)")
        }
    }
    
    private var userIsAtBottomOfTableView = false {
        didSet {
            self.unreadMessagesSnapshot.userIsAtBottomOfTableView = userIsAtBottomOfTableView
            DDLogVerbose("userIsAtBottomOfTableView \(userIsAtBottomOfTableView)")
        }
    }
    
    // MARK: - Gesture recognizer
    
    lazy var keyboardDismissGesture: UITapGestureRecognizer = {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapOnChatView))
        tapGesture.cancelsTouchesInView = true
        return tapGesture
    }()
    
    // MARK: Experimenting and measuring
    
    // TODO: (IOS-2014) remove
    
    private var firstCellShown = false
    
    // MARK: - GroupCalls
    
    private lazy var groupCallGroupModel: GroupCallsThreemaGroupModel? = {
        guard let group = GroupManager().getGroup(conversation: conversation) else {
            return nil
        }
        
        let groupCreatorID: String = group.groupCreatorIdentity
        let groupCreatorNickname: String? = group.groupCreatorNickname
        let groupID = group.groupID
        let members = group.members.compactMap { try? ThreemaID(id: $0.identity, nickname: $0.publicNickname) }
        
        return GroupCallsThreemaGroupModel(
            creator: try! ThreemaID(id: groupCreatorID, nickname: groupCreatorNickname),
            groupID: groupID,
            groupName: group.name ?? "",
            members: Set(members)
        )
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new chat view
    /// - Parameters:
    ///   - conversation: Conversation to display in chat view
    ///   - businessInjector: Business injector to load messages
    init(
        for conversation: Conversation,
        businessInjector: BusinessInjectorProtocol = BusinessInjector(),
        chatScrollPositionProvider: ChatScrollPositionProvider = ChatScrollPosition.shared,
        showConversationInformation: ShowConversationInformation? = nil
    ) {
        self.conversation = conversation
        self.businessInjector = businessInjector
        self.entityManager = businessInjector.entityManager
        self.chatScrollPositionProvider = chatScrollPositionProvider
        self.showConversationInformation = showConversationInformation
        
        super.init(nibName: nil, bundle: nil)
        
        // Tab bar
        if UIDevice.current.userInterfaceIdiom == .pad {
            hidesBottomBarWhenPushed = false
        }
        else {
            hidesBottomBarWhenPushed = true
        }
        
        // Configure tableView as early as possible to allow background fetching to take full effect
        configureTableView()
    }
    
    /// Create a new chat view
    /// - Parameters:
    ///   - conversation: Conversation to display in chat view
    ///   - showConversationInformation: ShowConversationInformation used for precomposing content
    @objc convenience init(
        conversation: Conversation,
        showConversationInformation: ShowConversationInformation?
    ) {
        self.init(for: conversation, showConversationInformation: showConversationInformation)
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
        
        DDLogVerbose("\(#function)")
        
        addObservers()
        tableView.addGestureRecognizer(keyboardDismissGesture)
        
        configureLayout()
        configureNavigationItem()
        configureToolbar()
        
        // No need to call `updateColors()` here as `ThemedViewController.viewWillAppear()` will call it, too.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DDLogVerbose("\(#function)")
        
        chatBarCoordinator.updateSettings()
        
        // This and the opposite in `viewWillDisappear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DDLogVerbose("\(#function)")
        
        willDisappear = false
        
        tableView.flashScrollIndicators()
        
        let endTime = CACurrentMediaTime()
        DDLogVerbose("ChatViewController duration init to viewDidAppear \(endTime - initTime) s")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DDLogVerbose("\(#function)")
        
        willDisappear = true
        scrollCompletion?()
        scrollCompletion = nil
        
        chatBarCoordinator.saveDraft()
        chatBarCoordinator.sendTypingIndicator(startTyping: false)
                
        // This and the opposite in `viewWillAppear` is needed to make a search controller work that is added in a
        // child view controller using the same navigation bar. See ChatSearchController for details.
        definesPresentationContext = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        DDLogVerbose("\(#function)")
        
        chatViewTableViewVoiceMessageCellDelegate.pausePlaying()
        
        saveCurrentScrollPosition()

        if shouldMarkMessagesAsRead {
            unreadMessagesSnapshot.resetState()
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        // stop playing and do a cleanup if user switch to overview
        if parent == nil {
            chatViewTableViewVoiceMessageCellDelegate.didDisappear = true
            chatViewTableViewVoiceMessageCellDelegate.stopPlayingAndDoCleanup(cancel: true)
        }
    }
    
    deinit {
        DDLogVerbose("\(#function)")
        
        NotificationCenter.default.removeObserver(self)
        
        DispatchQueue.global().async {
            /// Clean up temporary files that might be leftover from playing voice messages
            FileUtility.cleanTemporaryDirectory()
        }
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
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateContentInsetsForce),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateContentInsetsForce),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wallpaperChanged),
            name: NSNotification.Name(rawValue: kNotificationWallpaperChanged),
            object: nil
        )
        
        if ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls {
            // This will be automatically removed on deinit
            startGroupCallObserver()
        }
    }
    
    private func startGroupCallObserver() {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            return
        }
        
        Task {
            if let groupCallGroupModel,
               await GlobalGroupCallsManagerSingleton.shared.groupCallManager
               .viewModel(for: groupCallGroupModel) != nil {
                self.callCreatedByUsOrRemote()
            }
            
            await GlobalGroupCallsManagerSingleton.shared.groupCallManager
                .globalGroupCallObserver.publisher.pub
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global())
                .receive(on: DispatchQueue.main)
                .filter { [weak self] in self?.currentConversationIsEqualTo(group: $0.groupID, $0.creator.id) ?? false }
                .sink(receiveValue: { [weak self] _ in
                    DDLogVerbose("[GroupCall] Update Conversation Cell for Call")
                    self?.callCreatedByUsOrRemote()
                }).store(in: &cancellables)
        }
    }
    
    private func enableKeyboardDismissGestureRecognizer() {
        keyboardDismissGesture.isEnabled = true
    }
    
    private func disableKeyboardDismissGestureRecognizer() {
        keyboardDismissGesture.isEnabled = false
    }
    
    private func configureLayout() {
        // # View hierarchy
        //
        // The main `view` of the VC hosts all views. From back to front:
        // - Background view *
        // - Table view
        // - Chat bar
        // - Scroll to bottom button
        //
        // This is chosen on purpose, because the loading & layout (with scrolling to the correct position) of the
        // table view normally takes longer than the start of the transition to the VC. This allows us to load and show
        // all other views before the table view is ready. Thus a user could already start writing a message after the
        // transition completes, but before the table view is ready for interaction. If the table view would be the
        // main view of the VC the animation would be choppy.
        //
        // * this is preferred over `tableView.backgroundView` as this would not show the background until the table
        //   view is loaded and setting it the scroll position to infinity leads to weird background layout.
        
        view.addSubview(backgroundView)
        view.addSubview(tableView)
        view.addSubview(chatBarCoordinator.chatBarContainerView)
        view.addSubview(scrollToBottomButton)
        view.addSubview(groupCallBannerView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        chatBarCoordinator.chatBarContainerView.translatesAutoresizingMaskIntoConstraints = false
        chatBarCoordinator.chatBarContainerView.keyboardLayoutGuide.followsUndockedKeyboard = false
        scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            chatBarCoordinator.chatBarContainerView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            chatBarCoordinator.chatBarContainerView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            bottomComposeConstraint,
            topComposeConstraint,
            
            view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: groupCallBannerView.topAnchor, constant: -10),
            view.leadingAnchor.constraint(equalTo: groupCallBannerView.leadingAnchor, constant: -10),
            view.trailingAnchor.constraint(equalTo: groupCallBannerView.trailingAnchor, constant: 10),
        ])
                
        if UIDevice.current.userInterfaceIdiom == .pad {
            // This removes a small gap that would open up between the chat bar and the keyboard accessory view if an
            // iPad is used with an external keyboard
            NSLayoutConstraint.activate([
                chatBarCoordinator.chatBarContainerView.blurEffectView.bottomAnchor
                    .constraint(equalTo: view.bottomAnchor),
            ])
        }
        
        NSLayoutConstraint.activate(defaultScrollToBottomButtonConstraints)
                
        wallpaperChanged()
    }
    
    // MARK: - Public functions
    
    @objc func isRecording() -> Bool {
        chatBarCoordinator.isRecording
    }
    
    @objc func isPlayingAudioMessage() -> Bool {
        chatViewTableViewVoiceMessageCellDelegate.isMessageCurrentlyPlaying(nil)
    }
    
    // MARK: - Overrides
    
    override func viewWillLayoutSubviews() {
        DDLogVerbose("\(#function)")
        super.viewWillLayoutSubviews()
        updateChatProfileViewSettings()
    }
    
    override func viewDidLayoutSubviews() {
        DDLogVerbose("\(#function)")
        super.viewDidLayoutSubviews()
        
        // Scrolling gets stopped if we update the insets during it
        if !isScrolling {
            updateContentInsets()
        }
        
        // Scrolling might get stopped during layout updates
        // If we were programmatically scrolling to bottom before the update continue or start scrolling again
        if isProgrammaticallyScrollingToBottom {
            scrollToBottom(animated: true)
        }
        
        /// This immediately starts loading cells at the very bottom even before we call `didApplySnapshot`.
        /// As a nice side-effect to preloading the cells at the bottom of the view; we also get the effect that cells
        /// only appear after the scroll position has been correctly set.
        ///
        /// Unfortunately this loads cells at the bottom even when restoring the scroll position later somewhere else in
        /// the chat view, these cells are never displayed and thus go to waste.
        /// Calling `setContentOffset` and setting the content offset immediately to the approximately correct value of
        /// the scroll position still gives a jumpy animation on slow devices.
        /// We thus accept this limitation and waste a few cells on each scroll position restore.
        ///
        /// This workaround is also present in `updateContentInsets(force:retry:)`
        if !dataSource.initialSetupCompleted, tableView.contentSize.height > 0 {
            tableView.setContentOffset(
                CGPoint(x: 0, y: CGFLOAT_MAX),
                animated: false
            )
        }
    }
    
    override func updateColors() {
        super.updateColors()
        
        chatProfileView.updateColors()
        
        for cell in tableView.visibleCells {
            if let chatViewBaseCell = cell as? ChatViewBaseTableViewCell {
                chatViewBaseCell.updateColors()
                continue
            }
            else if let systemMessageCell = cell as? ChatViewSystemMessageTableViewCell {
                systemMessageCell.updateColors()
            }
            else if let workConsumerSystemMessageCell = cell as? ChatViewWorkConsumerInfoSystemMessageTableViewCell {
                workConsumerSystemMessageCell.updateColors()
            }
            else if let unreadMessageCell = cell as? ChatViewUnreadMessageLineCell {
                unreadMessageCell.updateColors()
            }
        }
        
        chatBarCoordinator.updateColors()
        
        scrollToBottomButton.updateColors()
        
        // We don't want a transparent navigation bar appearance if we are in the process of restoring the scroll
        // position as this leads to a weird transition when the chat view is pushed in.
        // Thus we don't use one at all.
        navigationItem.scrollEdgeAppearance = Colors.defaultNavigationBarAppearance()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        cellHeightCache.clear()
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    // MARK: - Notifications
    
    @objc private func applicationDidEnterBackground() {
        DDLogVerbose("\(#function)")
        
        saveCurrentScrollPosition()
        
        if shouldMarkMessagesAsRead {
            unreadMessagesSnapshot.resetState()
            dataSource.removeUnreadMessageLine()
        }
        
        chatBarCoordinator.saveDraft()
        
        isApplicationInForeground = false
    }
    
    @objc private func applicationWillEnterForeground() {
        isApplicationInForeground = true
        /// Part of the workaround for the passcode lock screen. See `ChatViewTableView` for additional info
        didEnterForegroundWithNilWindow = view.window == nil
        
        userIsAtBottomOfTableView = isAtBottomOfView
        
        /// Part of the workaround for the passcode lock screen. See `ChatViewTableView` for additional info
        if !didEnterForegroundWithNilWindow {
            jumpToUnreadMessage()
        }
    }
    
    @objc func didTapOnChatView() {
        hideKeyboard()
        
        selectedTextView?.resetTextSelection()
    }
    
    func hideKeyboard() {
        chatBarCoordinator.endEditing()
    }
    
    @objc func preferredContentSizeCategoryDidChange() {
        cellHeightCache.clear()
    }

    @objc func wallpaperChanged() {
        let wallpaperStore = businessInjector.settingsStore.wallpaperStore
        // If we use the default item, we have to create the pattern and apply it as color
        if !wallpaperStore.hasCustomWallpaper(for: conversation.objectID),
           wallpaperStore.defaultIsThreemaWallpaper() {
            backgroundView.image = nil
            backgroundView
                .backgroundColor = UIColor(patternImage: businessInjector.settingsStore.wallpaperStore.defaultWallPaper)
        }
        else {
            backgroundView.backgroundColor = nil
            backgroundView.image = wallpaperStore.wallpaper(for: conversation.objectID)
        }
    }
}

// MARK: - Navigation Item

extension ChatViewController {
    
    private func configureNavigationItem() {
        
        // Note: The back button is set in `ConversationsViewController` and cannot be overridden here
        
        // Configure chat profile view
        // See `ChatProfileView` why we choose this solution
        
        navigationItem.largeTitleDisplayMode = .never
        
        updateNavigationItem()
    }
    
    private func updateNavigationItem() {
        switch userInterfaceMode {
        case .default:
            updateChatProfileViewSettings()
            
            navigationItem.titleView = chatProfileView
            
            navigationItem.hidesBackButton = false
            
            navigationItem.leftBarButtonItem = nil
            
            navigationItem.rightBarButtonItems = nil
            
            if conversation.isGroup() {
                if ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls {
                    // TODO: IOS-3745 This should be somewhat dynamic
                    // TODO: IOS-3745 This should show the correct icon
                    callBarButtonItem.accessibilityLabel = BundleUtil.localizedString(forKey: "call")
                    callBarButtonItem.accessibilityIdentifier = "ChatViewControllerCallBarButtonItem"
                    navigationItem.rightBarButtonItem = callBarButtonItem
                }
                else {
                    updateOpenBallotsButton()
                }
            }
            // Only show call icon if Threema calls are enabled and contact supports them
            else if UserSettings.shared()?.enableThreemaCall == true,
                    let contact = conversation.contact {
                let contactSet = Set<ContactEntity>([contact])

                FeatureMask.check(Int(FEATURE_MASK_VOIP), forContacts: contactSet) { unsupportedContacts in
                    if unsupportedContacts?.isEmpty == true ||
                        ProcessInfoHelper.isRunningForScreenshots {
                        self.callBarButtonItem.accessibilityLabel = BundleUtil.localizedString(forKey: "call")
                        self.callBarButtonItem.accessibilityIdentifier = "ChatViewControllerCallBarButtonItem"
                        self.navigationItem.rightBarButtonItem = self.callBarButtonItem
                    }
                }
            }
            
        case .search:
            navigationItem.titleView = chatSearchController.searchBar
            
            navigationItem.hidesBackButton = true
            
            navigationItem.leftBarButtonItem = nil

            navigationItem.rightBarButtonItems = nil
            
        case .multiselect:
            navigationItem.titleView = nil
            
            navigationItem.hidesBackButton = true
            
            navigationItem.leftBarButtonItem = deleteBarButton
            updateSelectionTitle()
            
            navigationItem.rightBarButtonItems = nil
            navigationItem.rightBarButtonItem = cancelBarButton
            
        case .preview:
            navigationItem.titleView = nil
            
            navigationItem.hidesBackButton = true
            
            navigationItem.leftBarButtonItems = nil

            navigationItem.rightBarButtonItems = nil
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
    /// As it is complicated to observe ballot changes we just call this function on every instance creation of the view
    /// or new (ballot) message received.
    private func updateOpenBallotsButton() {
        
        guard conversation.isGroup(), userInterfaceMode == .default else {
            return
        }
        
        let numberOfOpenBallots = entityManager.entityFetcher.countOpenBallots(for: conversation)
        
        // Only show ballots icon if we have open polls
        if numberOfOpenBallots > 0 {
            ballotBarButton.openBallotsCount = UInt(numberOfOpenBallots)
            
            if navigationItem.rightBarButtonItems == nil {
                navigationItem.rightBarButtonItems = ballotBarButton.rightBarButtonItems
            }
        }
    }
    
    private func updateGroupCallBanner() {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            return
        }
        
        Task.detached { [weak self] in
            guard let self else {
                return
            }
            
            guard let groupCallGroupModel = await self.groupCallGroupModel else {
                return
            }
            
            let msToWait = 500
            
            if #available(iOS 16.0, *) {
                try? await Task.sleep(for: .milliseconds(msToWait))
            }
            else {
                try? await Task.sleep(nanoseconds: UInt64(msToWait) * 1000 * 1000)
                // Fallback on earlier versions
            }
        }
    }
    
    /// `ChatProfileViewDelegate` method
    func chatProfileViewTapped() {
        let detailsViewController: UIViewController
        
        if conversation.isGroup() {
            guard let group = GroupManager().getGroup(conversation: conversation) else {
                fatalError("No group conversation found for this conversation")
            }
            
            detailsViewController = GroupDetailsViewController(for: group, displayMode: .conversation, delegate: self)
        }
        else {
            detailsViewController = SingleDetailsViewController(for: conversation, delegate: self)
        }
        
        let navigationController = ModalNavigationController(rootViewController: detailsViewController)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.modalDelegate = self
        
        present(navigationController, animated: true)
    }
    
    /// Start VoIP call
    ///
    /// - Note: Only call this if you previously checked if `conversation.contact` supports calls
    @objc func startVoIPCall() {
        if conversation.isGroup() {
            startGroupCall()
        }
        else {
            startOneToOneCall()
        }
    }
    
    private func startGroupCall() {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            assertionFailure()
            return
        }
            
        Task { @MainActor in
            do {
                let viewModel = try await GlobalGroupCallsManagerSingleton.shared.startGroupCall(
                    in: conversation,
                    with: MyIdentityStore.shared().identity
                )
                await GlobalGroupCallsManagerSingleton.shared.groupCallManager.set(uiDelegate: self)
                let groupCallViewController = GlobalGroupCallsManagerSingleton.shared
                    .groupCallViewController(for: viewModel)
                self.present(groupCallViewController, animated: true)
            }
            catch {
                // TODO: IOS-3743 Graceful Error Handling
                let contr = UIAlertController(title: "Call Failed", message: "F", preferredStyle: .alert)
                contr.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(contr, animated: true)
            }
        }
    }
    
    private func startOneToOneCall() {
        chatViewTableViewVoiceMessageCellDelegate.pausePlaying()
        
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
            UIAlertTemplate.showAlert(
                owner: self,
                title: BundleUtil.localizedString(forKey: "ballot_load_error"),
                message: nil
            )
            return
        }
        
        // Encapsulate the `BallotListTableViewController` inside a navigation controller for modal
        // presentation
        let navigationController = ThemedNavigationController(rootViewController: ballotViewController)
        present(navigationController, animated: true)
    }
    
    @objc private func showDeleteMessagesAlert() {
        let alertTitle: String
        var alertMessage: String?
        
        if dataSource.hasSelectedObjectIDs() {
            alertTitle = BundleUtil.localizedString(forKey: "messages_delete_selected_confirm")
        }
        else {
            alertTitle = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_title")
            alertMessage = BundleUtil.localizedString(forKey: "messages_delete_all_confirm_message")
        }
        
        UIAlertTemplate.showDestructiveAlert(
            owner: self,
            title: alertTitle,
            message: alertMessage,
            titleDestructive: BundleUtil.localizedString(forKey: "delete")
        ) { _ in
            
            if self.dataSource.hasSelectedObjectIDs() {
                self.dataSource.deleteSelectedMessages()
            }
            else {
                self.dataSource.deleteAllMessages()
            }
            self.endMultiselect()
        }
    }
    
    func playNextMessageIfPossible(from message: NSManagedObjectID) {
        guard let indexPath = dataSource.indexPath(for: .message(objectID: message)) else {
            DDLogError("\(#function) could not find indexPath for message")
            return
        }
            
        var nextMessageIndexPath: IndexPath?
            
        let nextMessageOffset = 1
            
        if indexPath.section < tableView.numberOfSections,
           indexPath.row + nextMessageOffset < tableView.numberOfRows(inSection: indexPath.section) {
            nextMessageIndexPath = IndexPath(row: indexPath.row + nextMessageOffset, section: indexPath.section)
        }
        else if indexPath.section + 1 < tableView.numberOfSections,
                tableView.numberOfRows(inSection: indexPath.section + nextMessageOffset) > 0 {
            nextMessageIndexPath = IndexPath(row: 0, section: indexPath.section + nextMessageOffset)
        }
            
        guard let nextMessageIndexPath,
              let cell = tableView.cellForRow(at: nextMessageIndexPath) as? ChatViewVoiceMessageTableViewCell else {
            return
        }
            
        let scrollPosition: UITableView.ScrollPosition = .top
            
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
            self.contentSizeChangeSafeScrollToRow(at: nextMessageIndexPath, at: scrollPosition, animated: true)
            // Loading will be handled by `UIScrollViewDelegate`
                
            cell.downloadAndPlay()
        }
    }
    
    override func accessibilityPerformMagicTap() -> Bool {
        chatViewTableViewVoiceMessageCellDelegate.stopPlayingAndDoCleanup(cancel: true)
        return true
    }
}

// MARK: - Table View

extension ChatViewController {
    private func configureTableView() {
        // This needs to be done here and not in the lazy `tableView` initializer. Otherwise we get an infinite loop.
        tableView.dataSource = dataSource
        
        // Add reusable section header
        tableView.registerHeaderFooter(ChatViewSectionTableViewHeaderView.self)
    }
    
    // MARK: Scroll
    
    /// Scrolls to the bottom of the tableView
    ///
    /// *The animation and the scroll may be cancelled if the tableView is updated with new data, the view layouts its
    /// subviews in an unfortunate way or the contentOffset is changed. The caller must make sure that the animation
    /// isn't cancelled by such updates.*
    ///
    /// Use `jumpToBottom` if the messages at the bottom are not guaranteed to be already loaded.
    ///
    /// See `dataSource.apply` for more information about the current implementation of locking updates.
    /// - Parameter animated: Whether scrolling is animated or not
    private func scrollToBottom(animated: Bool, force: Bool = false) {
        DDLogVerbose("\(#function)")
        
        // Do not cancel user scroll
        guard ((!isUserInteractiveScroll && !isAtBottomOfView) || !dataSource.initialSetupCompleted) || force else {
            DDLogVerbose("\(#function) do not cancel user interactive scroll")
            return
        }
        
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
        
        DDLogVerbose("Scroll to bottom index path \(bottomIndexPath) ...")
        
        let scrollPosition: UITableView.ScrollPosition = .bottom
        if ChatViewConfiguration.ScrollCompletionBehavior.useCustomViewAnimationBlock {
            if animated {
                scrollToBottomWithCustomAnimation(bottomIndexPath)
            }
            else {
                contentSizeChangeSafeScrollToRow(at: bottomIndexPath, at: scrollPosition, animated: false)
            }
        }
        else {
            contentSizeChangeSafeScrollToRow(at: bottomIndexPath, at: scrollPosition, animated: animated)
        }
    }
    
    /// Helper function for `scrollToBottom(animated: Bool)`
    /// - Parameter bottomIndexPath: indexPath to scroll to
    private func scrollToBottomWithCustomAnimation(_ bottomIndexPath: IndexPath) {
        UIView.animate(
            withDuration: ChatViewConfiguration.ScrollCompletionBehavior.animationDuration,
            delay: 0.0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            let scrollPosition: UITableView.ScrollPosition = .bottom
            self.contentSizeChangeSafeScrollToRow(at: bottomIndexPath, at: scrollPosition, animated: false)
        } completion: { _ in
            defer {
                self.scrollViewDidEndScrolling()
            }
            
            if !self.isUserInteractiveScroll, !self.isAtBottomOfView,
               bottomIndexPath == self.dataSource.bottomIndexPath {
                let msg = "After scrolling to bottom we are not at the bottom of the view"
                if ChatViewConfiguration.strictMode {
                    fatalError(msg)
                }
                else {
                    DDLogError(msg)
                    assertionFailure(msg)
                }
            }
        }
    }
    
    /// Calls `tableView.scrollToRow(at:at:animated:)` but protects against scrolling being not successful due to
    /// changing cell sizes after scrolling
    ///
    /// In general you will not need this. Use `jump(to:animated:highlight:))` or `scrollToBottom(animated:)` instead.
    ///
    /// For more information see comment below
    ///
    /// - Parameters:
    ///   - indexPath: Identifies the row to scroll to
    ///   - scrollPosition: final scroll position
    ///   - animated: whether to animate the scrolling or not
    private func contentSizeChangeSafeScrollToRow(
        at indexPath: IndexPath,
        at scrollPosition: UITableView.ScrollPosition,
        animated: Bool
    ) {
        guard tableView.numberOfSections > indexPath.section,
              tableView.numberOfRows(inSection: indexPath.section) > indexPath.row else {
            DDLogError("You may not scroll to this row")
            return
        }
        
        let scrollToIndexPathIsVisible = tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false
        
        // This is not ideal since we might still jump a bit after the first scroll (see below)
        // But if the first scroll is successful the second one might not do anything at all and
        // we'll miss the chance to update our alpha.
        scrollPositionRestoreFinished = true
        
        tableView.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
        
        // At this point we are at the correct contentOffset for showing the cell at the very bottom
        // however the tableView might change its contentSize due to newly rendered cells whose exact height
        // (which was previously determined as automatic) is only now known causing the new contentOffset to be
        // incorrect
        //
        // To alleviate this issue we do another layout pass on tableView (which in general should do nothing) and
        // scroll to bottom again.
        //
        // This is especially noticeable because when opening chat view at the very bottom, the
        // bottommost cell will be slightly cut
        // off if this layout pass isn't present.
        tableView.layoutIfNeeded()
        
        // If we are already approximately at `indexPath` (i.e. it is visible on screen) we might loose the correct
        // scroll position for unknown reasons.
        // `setContentOffset` called from UITableView `scrollToRow` is incorrect on the second invocation of
        // `scrollToRow`. It is unclear why but causes the scroll position to jump up by ca. 400 points. This avoids
        // this issue.
        guard scrollToIndexPathIsVisible else {
            tableView.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
            return
        }
    }

    // MARK: Jump
    
    /// Jumps to the given messageID, the jump can either scroll in an animated way or be abrupt and highlight the
    /// jumped to cell for a short amount of time (will set highlight and unset highlight after a short time interval).
    /// - Parameters:
    ///   - messageID: A valid messageID
    ///   - animated: whether the jump is scrolled/animated
    ///   - highlight: whether the cell should be highlighted for a short amount of time after jumping has been
    ///                approximately completed
    func jump(to messageID: Data, animated: Bool, highlight: Bool = false) {
        jump(to: messageID, animated: animated) { message in
            guard highlight else {
                return
            }
            
            guard let message else {
                DDLogError("Message was unexpectedly nil")
                return
            }
            
            guard !self.dataSource.isSelected(objectID: message.objectID) else {
                DDLogWarn("Message is already selected so we don't highlight")
                return
            }
            
            DispatchQueue.main.asyncAfter(
                deadline: .now() + ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightDelayAfterScroll
            ) { [weak self] in
                
                guard let indexPath = self?.dataSource
                    .indexPath(for: ChatViewDataSource.CellType.message(objectID: message.objectID)) else {
                    DDLogWarn("Couldn't get indexPath")
                    return
                }
                
                guard let cell = self?.tableView.cellForRow(at: indexPath) as? ChatViewBaseTableViewCell
                else {
                    DDLogWarn("Couldn't get cell")
                    return
                }
                cell.blinkCell(
                    duration: ChatViewConfiguration.ChatBubble.HighlightedAnimation
                        .highlightedDurationLong
                )
            }
        }
    }
    
    func jumpToAndSelect(_ messageObjectID: NSManagedObjectID) {
        isJumping = true
        
        guard let message = entityManager.entityFetcher.existingObject(with: messageObjectID) as? BaseMessage else {
            DDLogWarn(
                "Unable to load message (\(messageObjectID.uriRepresentation())) to jump to."
            )
            return
        }
        
        guard let messageDate = message.date else {
            DDLogWarn("Unable to load date for message (\(messageObjectID.uriRepresentation())) to jump to.")
            return
        }
        
        dataSource.loadMessages(around: messageDate).done { [weak self] in
            guard let indexPath = self?.dataSource.indexPath(
                for: ChatViewDataSource.CellType.message(objectID: message.objectID)
            ) else {
                DDLogWarn("Couldn't get indexPath")
                return
            }
            // This was copied from jump(to messageID:)
            // TODO: This is a workaround that will be resolved with IOS-2720
            DispatchQueue.main.async {
                self?.dataSource.deselectAllMessages()
                self?.dataSource.didSelectRow(at: indexPath)
                
                // If scrollPosition is set to `.none` it will not scroll
                self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
            }
        }
        .ensure {
            self.completeJumping()
        }
        .catch { error in
            DDLogWarn("Unable to load messages for jumpToAndSelect: \(error)")
        }
    }
    
    private func completeJumping(to message: BaseMessage? = nil, completion: ((BaseMessage?) -> Void)? = nil) {
        // Wait a bit until scrolling should be somewhat completed
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
            self.isJumping = false
            completion?(message)
        }
    }
    
    private func jumpToTop() {
        isJumping = true
        dataSource.loadOldestMessages().ensure {
            self.view.layoutIfNeeded()
            
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            
            self.completeJumping { _ in
                self.userIsAtBottomOfTableView = self.isAtBottomOfView
            }
        }
        .catch { error in
            DDLogWarn("Unable to load messages for jumpToTop: \(error)")
        }
    }
    
    private func jumpToBottom() {
        isJumping = true
        dataSource.loadNewestMessages().ensure {
            self.view.layoutIfNeeded()
            self.isScrolling = true
            self.scrollToBottom(animated: true, force: true)
            self.completeJumping { _ in
                self.userIsAtBottomOfTableView = true
            }
        }
        .catch { error in
            DDLogWarn("Unable to load messages for jumpToBottom: \(error)")
        }
    }
    
    private func jump(toUnreadMessage unreadMessageMessageID: Data, completion: ((BaseMessage?) -> Void)? = nil) {
        dataSource.initialSetupCompleted = true
        let position: UITableView.ScrollPosition = .top
        jump(to: unreadMessageMessageID, at: position, completion: { baseMessage in
            completion?(baseMessage)
            self.userIsAtBottomOfTableView = self.isAtBottomOfView
        })
    }
    
    private func jumpContentLoadUnsafe(to unreadMessageMessageObjectID: NSManagedObjectID, animated: Bool = false) {
        isJumping = true
        defer { completeJumping() }
        
        let scrollPosition: UITableView.ScrollPosition = .top
        
        if let indexPath = dataSource
            .indexPath(for: ChatViewDataSource.CellType.message(objectID: unreadMessageMessageObjectID)) {
            contentSizeChangeSafeScrollToRow(at: indexPath, at: scrollPosition, animated: animated)
        }
        else {
            DDLogError("\(#function): Timing Error. Message was not yet applied")
        }
    }
    
    private func jump(
        to messageID: Data,
        at scrollPosition: UITableView.ScrollPosition = .middle,
        animated: Bool = false,
        completion: ((BaseMessage?) -> Void)? = nil,
        onError: (() -> Void)? = nil
    ) {
        guard let message = entityManager.entityFetcher.message(
            with: messageID,
            conversation: conversation
        ) else {
            DDLogWarn(
                "Unable to load message (\(messageID.hexString)) to jump to. It doesn't exist or is not in this conversation."
            )
            return
        }
        
        jump(to: message, at: scrollPosition, animated: animated, completion: completion, onError: onError)
    }
    
    private func jump(
        to message: BaseMessage,
        at scrollPosition: UITableView.ScrollPosition = .middle,
        animated: Bool,
        completion: ((BaseMessage?) -> Void)?,
        onError: (() -> Void)? = nil
    ) {
        isJumping = true
        
        guard let messageDate = message.date else {
            DDLogWarn("Unable to load date for message (\(message.objectID.uriRepresentation())) to jump to.")
            return
        }
        
        dataSource.loadMessages(around: messageDate).done {
            // TODO: This is a workaround that will be resolved with IOS-2720
            // With a one second delay we aim to be more sure that the loaded messages have been actually applied in
            // the tableView
            DispatchQueue.main.async {
                if let indexPath = self.dataSource
                    .indexPath(for: ChatViewDataSource.CellType.message(objectID: message.objectID)) {
                    self.contentSizeChangeSafeScrollToRow(at: indexPath, at: scrollPosition, animated: animated)
                    self.completeJumping(to: message, completion: completion)
                }
                else {
                    DDLogError("Timing Error: Message was not yet applied")
                    self.isJumping = false
                    onError?()
                }
            }
        }.catch { _ in
            DDLogError("Initial loading was cancelled")
        }
    }
    
    private func jumpToUnreadMessage() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            // `synchronousReconfiguration` may not run on the main thread
            unreadMessagesSnapshot.synchronousReconfiguration()
            
            entityManager.performBlock {
                if let newestUnreadMessage = self.unreadMessagesSnapshot.unreadMessagesState?
                    .oldestConsecutiveUnreadMessage,
                    let message = self.entityManager.entityFetcher
                    .getManagedObject(by: newestUnreadMessage) as? BaseMessage,
                    let messageID = message.id {
                    // We either succeed right away or do this on the next snapshot apply
                    DDLogVerbose("willEnterForegroundCompletion setup")
                    self.willEnterForegroundCompletion = { completion in
                        self.jump(to: messageID, animated: true, completion: { _ in
                            completion?()
                        })
                    }
                    
                    self.jump(to: messageID, animated: true) { _ in
                        self.willEnterForegroundCompletion = nil
                    }
                }
            }
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
        #if DEBUG
            if !dataSource.initialSetupCompleted {
                DDLogWarn(
                    "Initial setup was not yet completed `insetAdjustedBottomOffset` might return unreliable results."
                )
            }
        #endif
        
        let currentContentOffsetY = scrollView.contentOffset.y
        // Content offset is below the top adjusted content inset so we only need to adjust for the bottom inset
        let currentAdjustedHeight = scrollView.frame.height - scrollView.adjustedContentInset.bottom
        let currentContentHeight = scrollView.contentSize.height

        return currentContentHeight - (currentContentOffsetY + currentAdjustedHeight)
    }
    
    // MARK: Scroll to bottom button & chat bar and Toolbar
    
    private func showScrollToBottomButtonAndChatBar() {
        
        chatBarCoordinator.showChatBar()
        updateContentInsets()
        
        scrollToBottomButton.isHidden = false
    }
    
    private func hideScrollToBottomButtonAndChatBar() {
        updateContentInsets(force: true)
        chatBarCoordinator.hideChatBar()
        scrollToBottomButton.isHidden = true
    }
    
    private func configureToolbar() {
        // This is needed for search results. Otherwise the toolbar has no background
        let defaultAppearance = UIToolbarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        navigationController?.toolbar.scrollEdgeAppearance = defaultAppearance
    }
    
    private func showToolbar(animated: Bool) {
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    
    private func hideToolbar(animated: Bool) {
        navigationController?.setToolbarHidden(true, animated: animated)
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
    
    // MARK: Section headers
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard dataSource.snapshot().sectionIdentifiers.count > section else {
            return nil
        }
        
        let headerView: ChatViewSectionTableViewHeaderView? = tableView.dequeueHeaderFooter()
        headerView?.title = dataSource.snapshot().sectionIdentifiers[section]
        
        return headerView
    }
    
    // MARK: Cell height caching
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Cache height calculated by the system, select if table view is editing and cell was selected before
        if let cellType = dataSource.itemIdentifier(for: indexPath),
           case let ChatViewDataSource.CellType.message(objectID: objectID) = cellType {
            cellHeightCache.storeCellHeight(cell.frame.height, for: objectID)
            
            if userInterfaceMode == .multiselect,
               dataSource.isSelected(objectID: objectID) {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }
        }
        
        if !firstCellShown {
            firstCellShown = true
            let endTime = CACurrentMediaTime()
            DDLogVerbose("ChatViewController duration init to first cell shown \(endTime - initTime) s")
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let cellType = dataSource.itemIdentifier(for: indexPath),
              case let ChatViewDataSource.CellType.message(objectID: objectID) = cellType else {
            return UITableView.automaticDimension
        }
        
        // Try caches
        
        if let height = cellHeightCache.cellHeight(for: objectID) {
            return height
        }
        
        guard ChatViewConfiguration.enableEstimatedCellHeightCaching else {
            return UITableView.automaticDimension
        }
        
        guard dataSource.initialSetupCompleted else {
            return UITableView.automaticDimension
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
        
        let neighbors = ChatViewDataSource.neighbors(of: objectID, in: tableView)
        
        let estimatedHeight = ChatViewCellSizeProvider.estimatedCellHeight(
            for: message,
            with: neighbors,
            and: tableViewWidth
        )
        cellHeightCache.storeEstimatedCellHeight(estimatedHeight, for: objectID)
        
        return estimatedHeight
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard ChatViewConfiguration.enableCellHeightCaching else {
            return UITableView.automaticDimension
        }
        
        guard let cell = dataSource.itemIdentifier(for: indexPath),
              case let ChatViewDataSource.CellType.message(objectID: objectID) = cell else {
            return UITableView.automaticDimension
        }
        
        if let size = cellHeightCache.cellHeight(for: objectID) {
            return size
        }
        
        // With no cached value we let the system do the correct calculation
        return UITableView.automaticDimension
    }
    
    // MARK: - Multi-Select
    
    public func startMultiselect(with messageObjectID: NSManagedObjectID) {
        userInterfaceMode = .multiselect
        
        guard let indexPath = dataSource.indexPath(for: .message(objectID: messageObjectID)) else {
            DDLogWarn("No index path found for selected cell")
            return
        }
        
        dataSource.didSelectRow(at: indexPath)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        updateSelectionTitle()
    }
    
    @objc func endMultiselect() {
        userInterfaceMode = .default
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        // This is needed so a cell cannot be accidentally selected by tapping in another mode than multiselect as long
        // as `tableView.allowsSelection` is enabled.
        
        guard userInterfaceMode == .multiselect else {
            return nil
        }
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dataSource.didSelectRow(at: indexPath)
        updateSelectionTitle()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        dataSource.didDeselectRow(at: indexPath)
        updateSelectionTitle()
    }
    
    private func updateSelectionTitle() {
        
        guard dataSource.hasSelectedObjectIDs() else {
            deleteBarButton.title = BundleUtil.localizedString(forKey: "messages_delete_all_button")
            return
        }
        
        let count = dataSource.selectedObjectIDsCount()
        deleteBarButton.title = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "delete_n"),
            count
        )
    }
    
    // MARK: ContextMenu
    
    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        
        guard userInterfaceMode == .default else {
            return nil
        }
        
        // Check if cell conforms to `ChatViewMessageAction`
        guard let cell = tableView.cellForRow(at: indexPath) as? ChatViewMessageAction else {
            return nil
        }
        
        return cell.buildContextMenu(at: indexPath)
    }
    
    func tableView(
        _ tableView: UITableView,
        willDisplayContextMenu configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        
        if chatBarCoordinator.chatBar.isTextViewFirstResponder {
            insetUpdatesBlockedByContextMenu = true
        }
        
        UIView.animate(withDuration: ChatViewConfiguration.contextMenuBackgroundShowHideAnimationDuration) {
            self.hideScrollToBottomButtonAndChatBar()
            self.chatBarCoordinator.chatBar.resignFirstResponder()
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        willEndContextMenuInteraction configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        
        // Show keyboard again if it was before, and if there is no modal presented
        if insetUpdatesBlockedByContextMenu {
            if presentedViewController == nil {
                chatBarCoordinator.chatBar.becomeFirstResponder()
            }
            insetUpdatesBlockedByContextMenu = false
        }
        
        animator?.addCompletion {
            while !self.contextMenuActionsQueue.isEmpty {
                self.contextMenuActionsQueue.removeFirst()()
            }
        }
        
        UIView.animate(withDuration: ChatViewConfiguration.contextMenuBackgroundShowHideAnimationDuration) {
            if self.userInterfaceMode != .multiselect {
                self.showScrollToBottomButtonAndChatBar()
            }
            else {
                self.chatBarCoordinator.chatBar.resignFirstResponder()
                self.updateContentInsets()
            }
        }
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
    
    private func makeUITargetedPreview(for cell: ChatViewBaseTableViewCell) -> UITargetedPreview? {
        let parameters = UIPreviewParameters()
        parameters.visiblePath = cell.chatBubbleBorderPath
        parameters.shadowPath = cell.chatBubbleBorderPath
        parameters.backgroundColor = .clear
        
        // This translates the shadow of the preview from an offset to the position of `chatBubbleView`.
        // It's very unclear why this is necessary, but it looks like the shadow's position is relative to the visible
        // path causing it to be offset by the cell offset from the leftmost position.
        // This is particularly noticeable for incoming messages.
        let translate = CGAffineTransform(
            translationX: -cell.chatBubbleBorderPath.bounds.minX,
            y: -cell.chatBubbleBorderPath.bounds.minY
        )
        parameters.shadowPath?.apply(translate)
        
        guard cell.contentView.window != nil else {
            return nil
        }
        return UITargetedPreview(view: cell.contentView, parameters: parameters)
    }
}

// MARK: - ChatViewDataSourceDelegate

extension ChatViewController: ChatViewDataSourceDelegate {
    func willApplySnapshot(currentDoesIncludeNewestMessage: Bool) -> (() -> Void)? {
        DDLogVerbose("willApplySnapshot")
        
        isApplyingSnapshot = true
        
        // Don't scroll to bottom if we jump from the bottom
        guard !isJumping else {
            shouldScrollToBottomAfterNextSnapshotApply = false
            return nil
        }
        
        // When entering a chat after tapping on a notification we might show the passcode lock screen first. In that
        // case our own view has the correct size but the tableView below isn't correctly sized.
        // Note that despite this, just calling `layoutIfNeeded` on `tableView` is **not** enough.
        // This will cause a crash because the tableView to attempt to initialize an ordered set with capacity
        // 18446744073709551615, causing a crash with the following error:
        // -[__NSPlaceholderOrderedSet initWithCapacity:]: capacity (18446744073709551615) is ridiculous'
        //
        // In the regular case this shouldn't change anything because we're not animating at this point and the layout
        // should be stable.
        view.layoutIfNeeded()
                
        shouldScrollToBottomAfterNextSnapshotApply = currentDoesIncludeNewestMessage && isAtBottomOfView
            && dataSource.initialSetupCompleted && isApplicationInForeground
        
        let visibleAndScrolledToBottom = shouldScrollToBottomAfterNextSnapshotApply && shouldMarkMessagesAsRead
        
        _ = unreadMessagesSnapshot.tick(willStayAtBottomOfView: visibleAndScrolledToBottom)
        
        guard shouldScrollToBottomAfterNextSnapshotApply else {
            return nil
        }
        
        return { [weak self] in
            guard let self else {
                return
            }
            
            guard !self.isUserInteractiveScroll, !self.isDragging else {
                // The user is interacting with the chat, don't auto scroll
                //
                // In theory the user could have scrolled and stop between the call to
                // `willApplySnapshot(currentDoesincludeNewestMessage:)` and the closure call
                // but we assume that this doesn't happen in practice since snapshot apply
                // is reasonably fast (a few hundred ms).
                return
            }
            
            self.scrollToBottom(animated: true, force: true)
        }
    }
    
    func didApplySnapshot(delegateScrollCompletion: @escaping (() -> Void)) {
        DDLogVerbose("\(#function)")
        
        defer {
            isApplyingSnapshot = false
        }
        
        /// #  Scroll Behaviour
        /// ## Determining whether we can scroll after knowing whether we should
        ///
        /// `shouldScrollToBottomAfterNextSnapshotApply` cannot actually determine whether we are able to scroll here.
        /// Determining the ability to scroll is important for the `scrollCompletion` callback because it is only called
        /// if we actually scroll and not if we request to scroll with `scrollToBottom` but do not scroll because we are
        /// still at the bottom
        ///
        /// If we indeed need to scroll then the offset to the bottom has changed enough after applying the last
        /// snapshot (i.e. between `willApplySnapshot` and `didApplySnapshot`) such that we are not at the bottom
        /// anymore (as a new cell has been added).
        /// We use this to determine whether we will scroll on calling `scrollToBottom` and only scroll in that case.
        let hasNewlyAddedCellsInThisSnapshot = !isAtBottomOfView && willEnterForegroundCompletion == nil
                        
        if let willEnterForegroundCompletion {
            DDLogVerbose("\(#function) willEnterForegroundCompletion != nil")
            willEnterForegroundCompletion {
                self.willEnterForegroundCompletion = nil
            }
        }
        else {
            DDLogVerbose("\(#function) willEnterForegroundCompletion == nil")
        }
        
        if shouldScrollToBottomAfterNextSnapshotApply,
           hasNewlyAddedCellsInThisSnapshot,
           !isUserInteractiveScroll {
            DDLogVerbose("\(#function) Scrolling animated")
            
            DDLogVerbose("[ChatViewDataSourceDelegate] \(#function)  Scrolling animated")
            view.layoutIfNeeded()
            scrollToQueue.async { [self] in
                
                if dataSource.initialSetupCompleted {
                    DDLogVerbose("\(#function) dataSource.snapshotApplyLock.lock()")
                    dataSource.snapshotApplyLock.lock()
                }
                
                DispatchQueue.main.async {
                    if self.scrollCompletion != nil, ChatViewConfiguration.strictMode {
                        fatalError("\(#function) Cancelling previous scroll completion")
                    }
                    self.scrollCompletion = { [weak self] in
                        delegateScrollCompletion()
                        self?.scrollToQueue.sync {
                            self?.dataSource.snapshotApplyLock.unlock()
                        }
                    }
                    self.isScrolling = true
                    self.isProgrammaticallyScrollingToBottom = true
                    
                    self.scrollToBottom(animated: true, force: true)
                }
            }
        }
        else {
            DDLogVerbose("\(#function) DataSource hasn't added new messages we are not requesting to scroll")
            delegateScrollCompletion()
            if scrollCompletion != nil, ChatViewConfiguration.strictMode {
                fatalError("\(#function) Previous scroll is still pending")
            }
            scrollCompletion = nil
        }
        
        if conversation.isGroup() {
            updateOpenBallotsButton()
            updateGroupCallBanner()
        }
    }
    
    func lastMessageChanged(messageIdentifier: NSManagedObjectID) {
        DDLogVerbose("\(#function)")
        DispatchQueue.main.async {
            guard let message = self.entityManager.entityFetcher.getManagedObject(
                by: messageIdentifier
            ) as? BaseMessage,
                message.isOwnMessage else {
                return
            }
            
            self.unreadMessagesSnapshot.resetState()
        }
    }
    
    func willDeleteMessage(with objectID: NSManagedObjectID) {
        // Keep track of deleted messages
        dataSource.deletedMessagesObjectIDs.insert(objectID)
    }
    
    func didDeleteMessages() {
        unreadMessagesSnapshot.resetState()
        
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(ChatViewConfiguration.UnreadMessageLine.timeBeforeDisappear)
        ) {
            self.dataSource.removeUnreadMessageLine()
        }
    }
}

// MARK: - Scroll position restoration

extension ChatViewController {
    /// Save current scroll position
    ///
    /// Store the offset from top of a visible cell from the content offset (positive if the cell top is in the visible
    /// area).
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
        
        defer {
            // There will be no scroll completion callback if we are already at the bottom of the view
            self.tableView.alpha = 1.0
            if UIAccessibility.isVoiceOverRunning {
                UIView.setAnimationsEnabled(true)
            }
        }
        
        guard let previousScrollPosition = chatScrollPositionProvider.chatScrollPosition(
            for: conversation
        ) else {
            DDLogVerbose("No previous scroll position. Scroll to bottom.")
            
            guard tableView.numberOfSections > 0 else {
                dataSource.initialSetupCompleted = true
                return
            }
            
            // The newest messages should be loaded so we just scroll to the bottom to optimize
            // performance.
            view.layoutIfNeeded()
            isScrolling = true
            scrollToBottom(animated: false)
            dataSource.initialSetupCompleted = true
            userIsAtBottomOfTableView = true
            
            if isAtBottomOfView {
                // There will be no scroll completion callback if we are already at the bottom of the view
                tableView.alpha = 1.0
                if UIAccessibility.isVoiceOverRunning {
                    UIView.setAnimationsEnabled(true)
                }
            }
            
            return
        }
        
        // The correct set of messages should be loaded at this point
        
        // Exit function if some part of the restoration fails
        func restoreAtBottom() {
            DDLogVerbose("Restore at bottom")
            
            chatScrollPositionProvider.removeSavedPosition(for: conversation)
            
            // Ensure that we have the bottom data & then scroll to bottom
            dataSource.loadNewestMessages().done {
                self.view.layoutIfNeeded()
                self.isScrolling = true
                self.scrollToBottom(animated: false)
                self.dataSource.initialSetupCompleted = true
                self.userIsAtBottomOfTableView = true
                
                if self.isAtBottomOfView {
                    // There will be no scroll completion callback if we are already at the bottom of the view
                    self.tableView.alpha = 1.0
                    if UIAccessibility.isVoiceOverRunning {
                        UIView.setAnimationsEnabled(true)
                    }
                }
                
            }.catch { err in
                DDLogError("Could not load messages at bottom due to an error: \(err.localizedDescription)")
                assertionFailure()
            }
        }
        
        guard let messageObjectID = entityManager.managedObjectID(
            forURIRepresentation: previousScrollPosition.messageObjectIDURL
        ) else {
            DDLogWarn("Unable to restore message object ID")
            restoreAtBottom()
            userIsAtBottomOfTableView = true
            return
        }
        
        guard let indexPath = dataSource.indexPath(for: ChatViewDataSource.CellType.message(objectID: messageObjectID))
        else {
            DDLogWarn("Message not found in data source")
            restoreAtBottom()
            userIsAtBottomOfTableView = true
            return
        }
        
        // Needed to make the cell available in `cellForRow(at:)`
        view.layoutIfNeeded()
        tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        
        scrollPositionRestoreFinished = true
        
        tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        
        // Get cell to adjust offset accordingly
        guard let cell = tableView.cellForRow(at: indexPath) else {
            assertionFailure("Unable to find cell for scroll position restoration")
            restoreAtBottom()
            userIsAtBottomOfTableView = true
            return
        }
        
        // This leads to a little change of offset if restoration happens in another orientation.
        // TODO: (IOS-2014) Is this still a problem? Should we accommodate for that?
        // TODO: Also go through the protocol for correct behavior
        let newOffset = cell.frame.minY - previousScrollPosition.offsetFromTop
        tableView.contentOffset.y = newOffset
        
        chatScrollPositionProvider.removeSavedPosition(for: conversation)
        dataSource.initialSetupCompleted = true
        
        userIsAtBottomOfTableView = isAtBottomOfView
    }
}

// MARK: - Group Call Helpers

extension ChatViewController {
    // TODO: IOS-3728 Move to conversation
    /// Checks whether the current conversation is the group conversation with given groupID and creator
    /// - Parameters:
    ///   - groupID:
    ///   - creator:
    /// - Returns:
    private func currentConversationIsEqualTo(group groupID: Data, _ creator: String) -> Bool {
        
        guard conversation.isGroup() else {
            return false
        }
    
        guard conversation.groupID == groupID else {
            return false
        }
    
        if let id = conversation.contact?.identity, id != creator {
            return false
        }
    
        if conversation.contact == nil, businessInjector.myIdentityStore.identity != creator {
            return false
        }
        
        return true
    }
    
    private func callCreatedByUsOrRemote() {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            return
        }
        
        guard let groupCallGroupModel else {
            return
        }
        Task {
            let viewModel = await GlobalGroupCallsManagerSingleton.shared.groupCallManager
                .viewModel(for: groupCallGroupModel)
            
            if let item = await viewModel?.buttonBannerObserver.getCurrentItem() {
                self.groupCallBannerView.updateBannerState(state: item)
            }
            
            viewModel?.buttonBannerObserver.publisher.pub.sink { newState in
                self.groupCallBannerView.updateBannerState(state: newState)
            }
            .store(in: &cancellables)
        }
    }
}

// MARK: - UIScrollViewDelegate

extension ChatViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DDLogVerbose("\(#function)")
        // Check if we should load more messages...
        
        DDLogVerbose("\(#function) \(scrollView.contentOffset.y)")
        
        if scrollPositionRestoreFinished {
            tableView.alpha = 1.0
            if UIAccessibility.isVoiceOverRunning {
                UIView.setAnimationsEnabled(true)
            }
        }
        
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
        
        // Do not reload on dragging as this might throw the scroll position off
        // `scrollViewWillEndDragging` does an additional call to us to make sure we load messages after dragging.
        guard !isDragging else {
            return
        }
        
        // Do not load new messages if our last load request was not yet fulfilled by an applied snapshot
        guard !isLoading else {
            return
        }
        
        // As we normally scroll from bottom to top we first check the top...
        
        // Not really needed, but allows for more consistency across all devices
        let insetAdjustedTopOffset: CGFloat = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        
        // If we are at the very bottom we never want to load messages at the top since we have chosen
        // `topOffsetThreshold` and the number of messages that are loaded appropriately.
        if insetAdjustedTopOffset < topOffsetThreshold, !isAtBottomOfView {
            isLoading = true
            
            // Needed for the WORKAROUND after loading is completed
            let currentHeight = scrollView.contentSize.height
            // If offset is less than 0 due to elasticity of the scroll view, assume 0
            let initialContentOffSet = max(tableView.contentOffset.y, 0)
            
            dataSource.loadMessagesAtTop().done {
                DDLogVerbose("loadMessagesAtTop completed")
            }
            .ensure {
                // `contentSize` may not be up to date immediately; we reschedule this for a later point
                DispatchQueue.main.async {
                    // WORKAROUND (IOS-2865)
                    // This resets the scroll position to something (currently 100) below the very top of the tableView
                    // before the last snapshot apply as long as there where some new messages loaded (the content size
                    // increases).
                    // This is useful if we managed to scroll to the top without loading older messages. Without this
                    // workaround the new messages would then be added at the bottom instead of the top of the exiting
                    // messages in the view and so we basically skip all the newly loaded messaged from scrolling past
                    // and just jump to the top again. This leads to loading ALL messages at the top (or a memory
                    // overflow)
                    // WARN: This most likely only works due to accidental scheduling.
                    //
                    // In fact it causes the scroll position to be way off. This might be due to a miscalculation when
                    // calculating `newOffset` but we don't change that until we need it.
                    
                    guard initialContentOffSet < 100 else {
                        // We're not high up enough for incorrect cell insertion, don't reset scroll position
                        return
                    }
                    
                    let heightDiff = self.tableView.contentSize.height - currentHeight
                    
                    // Do not add the offset when all messages are loaded otherwise we cannot scroll all the way
                    // to the top.
                    guard heightDiff > 0 else {
                        return
                    }
                    
                    let newOffset = initialContentOffSet + heightDiff - scrollView.adjustedContentInset.top
                    self.tableView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
                }
                
                self.isLoading = false
            }
            .catch { error in
                DDLogError("An error occurred when loading messages at top: \(error.localizedDescription)")
            }
            
            return
        }
        
        // ...and then the bottom
        
        // Not really needed, but allows for more consistency across all devices
        let insetAdjustedBottomOffset = insetAdjustedBottomOffset(for: scrollView)
        
        if insetAdjustedBottomOffset < bottomOffsetThreshold {
            isLoading = true
            
            // Needed for the WORKAROUND after loading is completed
            let currentHeight = scrollView.contentSize.height
            // If offset is less than 0 due to elasticity of the scroll view, assume 0
            let initialContentOffSet = max(tableView.contentOffset.y, 0)
            
            dataSource.loadMessagesAtBottom().done { _ in
                DDLogVerbose("loadMessagesAtBottom completed")
            }.ensure {
                self.isLoading = false
            }
            .catch { error in
                DDLogError("An error occurred when loading messages at bottom: \(error.localizedDescription)")
            }
            
            return
        }
        
        // Check whether we're at the bottom of the view
        if dataSource.initialSetupCompleted {
            if isAtBottomOfView {
                userIsAtBottomOfTableView = true
            }
            else {
                userIsAtBottomOfTableView = false
            }
        }
    }
    
    // The functions below are used to detect when the scroll view is scrolling, we must not update content insets
    // during this.
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        DDLogVerbose("[UIScrollViewDelegate] \(#function)")
        isScrolling = true
        isDragging = true
        isUserInteractiveScroll = true
        isProgrammaticallyScrollingToBottom = false
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        DDLogVerbose("[UIScrollViewDelegate] \(#function)")
        /// Do one last call to didScroll to make sure we are loading messages if we're supposed to.
        scrollViewDidScroll(scrollView)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        DDLogVerbose("[UIScrollViewDelegate] \(#function)")
        isDragging = false
        
        if !decelerate {
            scrollViewDidEndScrolling()
        }
        
        if dataSource.initialSetupCompleted {
            if isAtBottomOfView {
                userIsAtBottomOfTableView = true
            }
            else {
                userIsAtBottomOfTableView = false
            }
        }
        
        scrollViewDidScroll(scrollView)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidEndScrolling()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        DDLogVerbose("[UIScrollViewDelegate] \(#function)")
        scrollViewDidEndScrolling()
    }
    
    /// This isn't a delegate method
    func scrollViewDidEndScrolling() {
        DDLogVerbose("[UIScrollViewDelegate] \(#function)")
        isProgrammaticallyScrollingToBottom = false
        isScrolling = false
        
        if dataSource.initialSetupCompleted {
            if isAtBottomOfView {
                userIsAtBottomOfTableView = true
            }
            else {
                userIsAtBottomOfTableView = false
            }
        }
        
        isUserInteractiveScroll = isDragging
        
        // We do this immediately after scrolling is done to avoid cells resizing themselves in the meantime causing
        // animation glitches
        updateContentInsets()
        
        // We keep a slight delay before unlocking the lock and calling scrollCompletion
        // This isn't strictly necessary but feels like it could solve some of our issues
        let delay = ChatViewConfiguration.ScrollCompletionBehavior.completionBlockCallDelay
        let deadline: DispatchTime = .now() + .milliseconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            self.scrollCompletion?()
            self.scrollCompletion = nil
        }
    }
    
    // TODO: (IOS-2014) Maybe store scroll position after scrolling finished for a bit (and no new scrolling started).
    //                  Maybe with a timer.
    
    // Scroll to bottom when tapping on top (& scroll view is not at top)
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        jumpToTop()
        return false
    }
    
    override func viewSafeAreaInsetsDidChange() {
        DDLogVerbose("\(view.safeAreaInsets)")
        
        // This fixes an issue where the offset was reported wrongly after a half dismiss swipe causing the chat bar to
        // have incorrect height.
        DispatchQueue.main.async {
            self.updateContentInsets(force: true)
        }
    }

    @objc func updateContentInsetsForce() {
        updateContentInsets(force: true)
    }
    
    func updateContentInsets(force: Bool = false, retry: Bool = true) {
        DDLogVerbose("\(#function)")
        guard !insetUpdatesBlockedByContextMenu else {
            DDLogVerbose("\(#function) Do not run updateContentInsets as we're showing the context menu")
            return
        }
        
        guard !isScrolling || (force && !isResettingKeyboard) else {
            DDLogVerbose("\(#function) Do not run updateContentInsets as we're scrolling")
            if retry {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.updateContentInsets(retry: false)
                }
            }
            return
        }
        
        guard !isJumping || force else {
            DDLogVerbose("\(#function) Do not run updateContentInsets as we're jumping")
            return
        }
        
        if !Thread.isMainThread {
            assertionFailure("Constraints must be updated on main thread")
        }
        
        view.layoutIfNeeded()
        
        let wasAtBottomOfView = isAtBottomOfView
        let oldYOffset = tableView.contentOffset.y
        
        let oldInset = tableView.contentInset
        
        var newContentInset = oldInset
        var newScrollbarIndicatorInset = oldInset
        
        // Tweak the insets
        
        if userInterfaceMode == .default {
            let newBottomInset: CGFloat = view.frame.maxY
                - chatBarCoordinator.chatBarContainerView.frame.minY
                - tableView.safeAreaInsets.bottom
            
            // We need some extra space to the chat bar for the content/chat bubbles to compensate for the missing
            // spacing from the top of the next bubble.
            if conversation.isGroup() {
                if conversation.lastMessage?.isOwnMessage ?? false {
                    newContentInset.bottom = newBottomInset + ChatViewConfiguration.bottomInset
                }
                else {
                    newContentInset.bottom = newBottomInset + ChatViewConfiguration.groupBottomInset
                }
            }
            else {
                newContentInset.bottom = newBottomInset + ChatViewConfiguration.bottomInset
            }
            
            // We just use the default inset for the scroll bars
            newScrollbarIndicatorInset.bottom = newBottomInset
        }
        else {
            if conversation.isGroup() {
                newContentInset.bottom = ChatViewConfiguration.groupBottomInset
            }
            else {
                newContentInset.bottom = ChatViewConfiguration.bottomInset
            }

            newScrollbarIndicatorInset.bottom = 0.0
        }
        
        // Also (and always) tweak the top inset. (This also influences the sticky section header inset.)
        newContentInset.top = ChatViewConfiguration.topInset
        
        guard !dataSource.initialSetupCompleted || tableView.contentInset != newContentInset else {
            DDLogVerbose("\(#function) Do not update content insets because they haven't changed")
            return
        }
        
        DDLogVerbose("\(#function) will updateContentInsets to \(newContentInset)")
        
        // Apply the insets if they changed
        if tableView.contentInset != newContentInset {
            tableView.contentInset = newContentInset
            DDLogVerbose("\(#function) did updateContentInsets to \(tableView.contentInset)")
        }
        if tableView.scrollIndicatorInsets != newScrollbarIndicatorInset {
            tableView.scrollIndicatorInsets = newScrollbarIndicatorInset
            DDLogVerbose("\(#function) did updateScrollbarIndicatorInsets")
        }
        
        if wasAtBottomOfView {
            DDLogVerbose("\(#function) wasAtBottomOfView")
            if dataSource.initialSetupCompleted {
                // Do not scroll to bottom before initial scroll position was set and `initialSetupCompleted` was set
                // in `restoreScrollPosition`.
                scrollToBottom(animated: false, force: true)
            }
            else if tableView.contentSize.height > 0 {
                // This replicates the workaround in `viewDidLayoutSubviews`
                tableView.setContentOffset(
                    CGPoint(x: 0, y: CGFLOAT_MAX),
                    animated: false
                )
            }
        }
        else {
            DDLogVerbose("\(#function) !wasAtBottomOfView")
            var insetChange = newContentInset.bottom - oldInset.bottom
            var newYOffset = (oldYOffset + insetChange)

            if tableView.contentOffset.y != newYOffset {
                tableView.setContentOffset(CGPoint(x: 0, y: newYOffset), animated: false)
                DDLogVerbose("\(#function) did updateContentInsets was at bottom.")
            }
        }
    }
}

// MARK: - ModalNavigationControllerDelegate

extension ChatViewController: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        if conversation.willBeDeleted {
            navigationController?.popViewController(animated: true)
        }
        
        chatBarCoordinator.updateSettings()
    }
}

// MARK: - DetailsDelegate

extension ChatViewController: DetailsDelegate {
    func detailsDidDisappear() {
        if userInterfaceMode == .search {
            chatSearchController.activateSearch()
        }
    }
    
    func showChatSearch() {
        userInterfaceMode = .search
    }
    
    func willDeleteMessages(with objectIDs: [NSManagedObjectID]) {
        dataSource.deletedMessagesObjectIDs = dataSource.deletedMessagesObjectIDs.union(objectIDs)
    }
    
    func willDeleteAllMessages() {
        dataSource.willDeleteAllMessages()
    }
}

// MARK: - ChatSearchControllerDelegate

extension ChatViewController: ChatSearchControllerDelegate {
    func chatSearchController(
        select messageObjectID: NSManagedObjectID,
        highlighting searchText: String,
        in filteredSearchResults: [NSManagedObjectID]
    ) {
        var indexPaths = [IndexPath]()
        
        for section in 0..<tableView.numberOfSections {
            for row in 0..<tableView.numberOfRows(inSection: section) {
                indexPaths.append(IndexPath(row: row, section: section))
            }
        }
        
        chatViewTableViewCellDelegate.currentSearchText = searchText
        
        dataSource.reconfigure(filteredSearchResults)
        
        jumpToAndSelect(messageObjectID)
    }
    
    func chatSearchController(removeSelectionFrom messageObjectID: NSManagedObjectID) {
        guard let indexPath = dataSource.indexPath(for: ChatViewDataSource.CellType.message(objectID: messageObjectID))
        else {
            DDLogVerbose("No index path found to remove selection from")
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func chatSearchController(showToolbarWith barButtonItems: [UIBarButtonItem], animated: Bool) {
        setToolbarItems(barButtonItems, animated: animated)
        showToolbar(animated: animated)
    }
    
    func chatSearchController(updateToolbarWith barButtonItems: [UIBarButtonItem]) {
        // If animated is true the text blinks when switching between results
        setToolbarItems(barButtonItems, animated: false)
    }
    
    func chatSearchControllerHideToolbar(animated: Bool) {
        hideToolbar(animated: animated)
        setToolbarItems(nil, animated: animated)
    }
    
    func chatSearchControllerHideSearch() {
        chatViewTableViewCellDelegate.currentSearchText = nil
        
        dataSource.reconfigure()
        
        userInterfaceMode = .default
    }
}

// MARK: - Helper functions for ChatViewDataSource initialization

// The compiler posts weird errors if something is wrong in the closures directly put into the initializer
// Thus we move these closures into their own functions
extension ChatViewController {
    private func chatViewDataSourceAfterFirstSnapshotApply() {
        // TODO: (IOS-2014) Maybe don't show messages until restoration completes to disable flickering if restoration
        // fails and we load messages at the bottom
        if let newestUnreadMessage = unreadMessagesSnapshot.unreadMessagesState?.oldestConsecutiveUnreadMessage {
            jumpContentLoadUnsafe(to: newestUnreadMessage)
            dataSource.initialSetupCompleted = true
            tableView.alpha = 1.0
            if UIAccessibility.isVoiceOverRunning {
                UIView.setAnimationsEnabled(true)
            }
        }
        else {
            restoreScrollPosition()
        }
        
        let endTime = CACurrentMediaTime()
        DDLogVerbose("ChatViewController duration init to dataSource ready \(endTime - initTime)")
    }
    
    private func chatViewDataSourceLoadAround() -> Date? {
        if let newestUnreadMessage = unreadMessagesSnapshot.unreadMessagesState?.oldestConsecutiveUnreadMessage,
           let message = entityManager.entityFetcher
           .getManagedObject(by: newestUnreadMessage) as? BaseMessage {
            return message.date
        }
        else {
            return chatScrollPositionProvider.chatScrollPosition(for: conversation)?.messageDate
        }
    }
}

// MARK: - ChatBarCoordinatorDelegate

extension ChatViewController: ChatBarCoordinatorDelegate {
    func didDismissQuoteView() {
        updateContentInsets(force: true)
    }
}

// MARK: - ChatViewTableViewDelegate

extension ChatViewController: ChatViewTableViewDelegate {
    func willMove(toWindow newWindow: UIWindow?) {
        /// Part of the workaround for the passcode lock screen. See `ChatViewTableView` for additional infos
        if newWindow != nil, didEnterForegroundWithNilWindow {
            jumpToUnreadMessage()
            didEnterForegroundWithNilWindow = false
        }
    }
}

// MARK: - UnreadMessagesStateManagerDelegate

extension ChatViewController: UnreadMessagesStateManagerDelegate {
    
    var shouldMarkMessagesAsRead: Bool {
        assert(Thread.isMainThread)
        
        // Part of the workaround for the passcode lock screen. See `ChatViewTableView` for additional info
        guard view.window != nil || willMoveToNonNilWindow else {
            return false
        }
        
        guard userInterfaceMode != .preview else {
            return false
        }
        
        return true
    }
}

// MARK: - GroupCallBannerButtonViewDelegate

extension ChatViewController: GroupCallBannerButtonViewDelegate {
    func joinCall() async {
        guard let groupCallGroupModel else {
            DDLogError("[GroupCall] Could not get GroupCallGroupModel")
            return
        }
        
        guard let viewModel = await GlobalGroupCallsManagerSingleton.shared.groupCallManager
            .joinCall(in: groupCallGroupModel, intent: .join).1 else {
            DDLogError("[GroupCall] Could not get view model")
            return
        }
        
        await GlobalGroupCallsManagerSingleton.shared.groupCallManager.set(uiDelegate: self)
        let groupCallViewController = GlobalGroupCallsManagerSingleton.shared
            .groupCallViewController(for: viewModel)
        present(groupCallViewController, animated: true)
    }
}

// MARK: - GroupCallManagerUIDelegate

extension ChatViewController: GroupCallManagerUIDelegate {
    @MainActor
    func showViewController(for viewModel: GroupCalls.GroupCallViewModel) {
        let groupCallViewController = GlobalGroupCallsManagerSingleton.shared
            .groupCallViewController(for: viewModel)
        present(groupCallViewController, animated: true)
    }
}
