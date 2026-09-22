import CocoaLumberjackSwift
import Coordinator
import CoreData
import Foundation
import ThreemaMacros

final class ConversationListCoordinator: NSObject, Coordinator, ChatViewControllerConversationDeletedDelegate {

    // MARK: Internal destination

    enum InternalDestination: Hashable {
        case conversation(NSManagedObjectID)
        case archivedConversationList
    }

    // MARK: - Coordinator

    var childCoordinators = [any Coordinator]()
    var rootViewController: UIViewController {
        rootNavigationController
    }

    private let router = NavigationRouter()

    /// Regular width only: renders primary-column destinations (the archived
    /// list) on top of the conversation list in the primary column, while
    /// `router` renders conversations in the secondary column. Holds an empty
    /// path in collapsed width.
    private let primaryRouter = NavigationRouter()

    /// `true` while bound for regular width, where the path is split across the
    /// two columns (see `rendersInPrimaryColumn`).
    private var isRegularBound = false

    private let conversationListViewControllerFactory: ConversationListViewControllerFactory
    private lazy var conversationListViewController: ConversationListViewController =
        conversationListViewControllerFactory.make(with: self)

    private lazy var rootNavigationController = StatusNavigationController()

    private weak var presentingViewController: ThreemaSplitViewController?
    private let viewControllerForDestination: (
        InternalDestination,
        ShowConversationInformation?
    ) -> UIViewController?
    private let isPasscodeRequired: () -> Bool
    private lazy var passcodeRouter: any PasscodeRouterProtocol = PasscodeRouter(
        lockScreen: LockScreen(isLockScreenController: false),
        isPasscodeRequired: { [weak self] in
            self?.isPasscodeRequired() == true
        }(),
        rootViewController: { [weak self] in
            guard let viewController = self?.presentingViewController?.viewControllers.last else {
                fatalError("ThreemaSplitViewController is missing a view controller.")
            }

            return viewController
        }()
    )

    /// Per-show chat configuration (precomposed text, image, scroll target).
    /// Set right before the path changes and consumed when the router
    /// materializes the chat screen.
    private var pendingInformation: ShowConversationInformation?

    var selectedConversation: ConversationEntity? {
        conversationListViewController.selectedConversation
    }

    /// The chat screen currently materialized for the path, if any.
    private var shownChatViewController: ChatViewController? {
        for destination in path.reversed() {
            if case .conversation = destination,
               let chatViewController = router.materializedViewController(
                   for: AnyHashable(destination)
               ) as? ChatViewController {
                return chatViewController
            }
        }
        return nil
    }

    private var archivedListViewController: ArchivedConversationListViewController? {
        let destination = AnyHashable(InternalDestination.archivedConversationList)
        let viewController = primaryRouter.materializedViewController(for: destination)
            ?? router.materializedViewController(for: destination)
        return viewController as? ArchivedConversationListViewController
    }

    init(
        presentingViewController: ThreemaSplitViewController,
        conversationListViewControllerFactory: ConversationListViewControllerFactory,
        viewControllerForDestination: @escaping (
            InternalDestination,
            ShowConversationInformation?
        ) -> UIViewController?,
        isPasscodeRequired: @autoclosure @escaping () -> Bool
    ) {
        self.presentingViewController = presentingViewController
        self.conversationListViewControllerFactory = conversationListViewControllerFactory
        self.viewControllerForDestination = viewControllerForDestination
        self.isPasscodeRequired = isPasscodeRequired
        super.init()

        router.delegate = self
        router.forwardDelegate = self
        primaryRouter.delegate = self
        primaryRouter.forwardDelegate = self
    }

    /// `.archivedConversationList` is a list-type destination: in regular width
    /// it renders in the primary column (pushed onto the conversation list),
    /// while conversations render in the secondary column.
    private static func rendersInPrimaryColumn(_ destination: InternalDestination) -> Bool {
        destination == .archivedConversationList
    }

    // MARK: - Presentation

    func start() {
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [conversationListViewController],
            animated: false
        )
    }

    func finish() {
        primaryRouter.unbind()
        router.unbind()
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    func show(conversation: ConversationEntity, information: ShowConversationInformation? = nil) {
        let destination = InternalDestination.conversation(conversation.objectID)
        let target: [InternalDestination] =
            conversation.conversationVisibility == .archived
                ? [.archivedConversationList, destination]
                : [destination]

        // Already showing this chat, and nothing forces a reopen (which is needed
        // to update the chat bar with precomposed text, images, …).
        guard path != target || information?.forceReopenChat == true else {
            return
        }

        if information?.forceReopenChat == true {
            router.invalidateMaterializedScreen(for: AnyHashable(destination))
        }

        pendingInformation = information

        if conversation.conversationCategory == .private {
            showPrivateChat(target: target)
        }
        else {
            setPath(target, animated: true)
        }
    }

    func showArchivedConversationList() {
        // Regular width: keep an open conversation in the path — it stays
        // visible in the secondary column until another conversation is
        // selected. In compact width the archived list always replaces the
        // whole stack.
        let openConversations = isRegularBound
            ? path.filter {
                if case .conversation = $0 {
                    return true
                }
                return false
            }
            : []
        setPath([.archivedConversationList] + openConversations, animated: true)
    }

    func resetSelection() {
        setPath([], animated: false)
    }

    // MARK: - Private chats

    private func showPrivateChat(target: [InternalDestination]) {
        /// If we restored from safe and no password is set, we inform the user that he needs to set one and present
        /// them the set password screen
        if isPasscodeRequired() == false {
            UIAlertTemplate.showAlert(
                owner: rootNavigationController,
                title: #localize("privateChat_alert_title"),
                message: String.localizedStringWithFormat(
                    #localize("privateChat_setup_alert_message"),
                    TargetManager.localizedAppName
                ),
                titleOk: #localize("privateChat_code_alert_confirm"),
                actionOk: { [weak self] _ in
                    self?.authenticateThenShow(target)
                }
            )
        }
        else {
            authenticateThenShow(target)
        }
    }

    /// Guard-then-mutate: the path only changes after authentication succeeded,
    /// so cancelling requires no rollback.
    private func authenticateThenShow(_ target: [InternalDestination]) {
        passcodeRouter.requireAuthenticationIfNeeded(
            style: .currentContext,
            onCancel: { [weak self] in
                // The path never changed — just clear the row highlight from the tap.
                self?.conversationListViewController.removeSelectedConversation()
                self?.conversationListViewController.setSelection(for: nil)
                self?.archivedListViewController?.removeSelectedConversation()
                self?.archivedListViewController?.setSelection(for: nil)
            },
            onSuccess: { [weak self] in
                self?.setPath(target, animated: true)
            }
        )
    }

    private func dismissPasscodeIfNeeded() {
        guard
            presentingViewController?.isCollapsed == false,
            selectedConversation?.conversationCategory == .private
        else {
            return
        }

        passcodeRouter.rootViewController().presentedViewController?
            .dismiss(animated: false)
        resetSelection()
    }

    // MARK: - Router binding

    /// Hooks for `ThreemaSplitViewNavigationManager` to activate/deactivate this
    /// tab's router when tab selection or the size class changes.
    var routerHandle: RouterManagedTabHandle {
        RouterManagedTabHandle(
            deactivate: { [weak self] in
                self?.primaryRouter.unbind()
                self?.router.unbind()
            },
            activateCompact: { [weak self] in
                self?.bindCompact()
            },
            activateRegular: { [weak self] navigationController in
                self?.bindRegular(into: navigationController)
            },
            reauthenticateProtectedDestinations: { [weak self] in
                guard
                    let self,
                    shownChatViewController?.conversation.conversationCategory == .private
                else {
                    return
                }
                // The private chat stays in place behind the prompt; cancelling
                // closes it but keeps the list part of the path (e.g. the
                // archived list). (With no passcode set this succeeds
                // immediately.)
                passcodeRouter.requireAuthenticationIfNeeded(
                    style: .currentContext,
                    onCancel: { [weak self] in
                        guard let self else {
                            return
                        }
                        let trimmed = path.filter {
                            if case .conversation = $0 {
                                return false
                            }
                            return true
                        }
                        setPath(trimmed, animated: false)
                    },
                    onSuccess: { }
                )
            },
            releaseMaterializedScreens: { [weak self] in
                guard
                    let self,
                    !router.isBound,
                    !primaryRouter.isBound
                else {
                    return
                }

                // Keep a private chat materialized: the re-authentication on
                // tab return derives the privacy from the materialized screen —
                // releasing it would re-show the chat without a passcode prompt.
                guard shownChatViewController?.conversation.conversationCategory != .private else {
                    return
                }

                router.releaseMaterializedScreens()
                primaryRouter.releaseMaterializedScreens()
                // The tab's own navigation controller retains the compact stack
                // even while inactive — reset it to the root; the next
                // activation re-materializes the stack from the path.
                rootNavigationController.setViewControllers(
                    [conversationListViewController],
                    animated: false
                )
            }
        )
    }

    /// Collapsed width: the whole stack lives in the tab's own navigation
    /// controller, rooted in the conversation list.
    private func bindCompact() {
        // Merge the two columns' paths back into the single compact stack
        // (primary-column destinations, e.g. the archived list, stay in front).
        let combined = path
        isRegularBound = false

        // Unbind before re-distributing the paths — a router can still be bound
        // here (collapse activates without a prior deactivate), and setting a
        // path on a bound router would materialize it into the old column.
        primaryRouter.unbind()
        router.unbind()

        primaryRouter.setPath([], animated: false)
        router.setPath(combined.map { AnyHashable($0) }, animated: false)

        router.bind(
            to: rootNavigationController,
            rootViewController: conversationListViewController
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// Regular width: the path is split across the columns. List-type
    /// destinations (the archived list) stay in the primary column on top of the
    /// conversation list; conversations render in the secondary column, rooted in
    /// a placeholder. An empty path shows just list and placeholder.
    private func bindRegular(into navigationController: UINavigationController) {
        let combined = path
        isRegularBound = true

        // Unbind before re-distributing the paths — a router can still be bound
        // here (repeated activation), and setting a path on a bound router would
        // materialize it into the old column.
        primaryRouter.unbind()
        router.unbind()

        primaryRouter.setPath(
            combined.filter(Self.rendersInPrimaryColumn).map { AnyHashable($0) },
            animated: false
        )
        router.setPath(
            combined.filter { !Self.rendersInPrimaryColumn($0) }.map { AnyHashable($0) },
            animated: false
        )

        primaryRouter.bind(
            to: rootNavigationController,
            rootViewController: conversationListViewController
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        router.bind(
            to: navigationController,
            rootViewController: ThreemaLogoViewController(rootView: ThreemaLogoView()),
            rootMode: .placeholder
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// While the collapse/expand transition that triggered a (re)bind is running,
    /// `isCollapsed` still reports the old value and the appearance callbacks
    /// fired during it clear the list selection. Re-derive the selection once the
    /// transition has settled.
    private func scheduleSelectionSync() {
        DispatchQueue.main.async { [weak self] in
            self?.syncSelection()
        }
    }

    private func makeScreen(_ destination: AnyHashable) -> UIViewController? {
        guard let destination = destination as? InternalDestination else {
            return nil
        }

        switch destination {
        case .conversation:
            // Consume the per-show configuration when the chat screen is actually
            // materialized — which can be later than `setPath` (e.g. a cold-start
            // deep link stores the path before the router is first bound).
            let information = pendingInformation
            pendingInformation = nil
            return viewControllerForDestination(destination, information)

        case .archivedConversationList:
            return viewControllerForDestination(destination, nil)
        }
    }

    // MARK: - Selection sync

    private func syncSelection() {
        // Never force-load the list view here: a cold-start deep link runs before
        // the view hierarchy exists, and touching the table view then lays it out
        // outside a window with a zero-sized frame — which can spin the layout
        // engine forever. The selection is re-derived on appearance anyway
        // (`ConversationSelectionManager.handleViewWillAppear`).
        guard conversationListViewController.isViewLoaded else {
            return
        }

        if presentingViewController?.isCollapsed == false {
            let conversation = shownChatViewController?.conversation
            conversationListViewController.selectionManager.allowSelectionSetting = true
            conversationListViewController.setSelection(for: conversation)
            archivedListViewController?.setSelection(for: conversation)
        }
        else {
            conversationListViewController.removeSelectedConversation()
        }
    }
}

// MARK: - PathCoordinator

extension ConversationListCoordinator: PathCoordinator {

    /// Derived from the routers — there is no separate state to keep in sync.
    /// In regular width the path is split across the columns; primary-column
    /// destinations (the archived list) always precede the conversations.
    var path: [InternalDestination] {
        (primaryRouter.path + router.path).compactMap { $0 as? InternalDestination }
    }

    func setPath(_ path: [InternalDestination], animated: Bool) {
        if isRegularBound {
            primaryRouter.setPath(
                path.filter(Self.rendersInPrimaryColumn).map { AnyHashable($0) },
                animated: animated
            )
            router.setPath(
                path.filter { !Self.rendersInPrimaryColumn($0) }.map { AnyHashable($0) },
                animated: animated
            )
        }
        else {
            router.setPath(path.map { AnyHashable($0) }, animated: animated)
        }
        syncSelection()
    }
}

// MARK: - NavigationRouterDelegate

extension ConversationListCoordinator: NavigationRouterDelegate {

    /// The user popped (back button, swipe, tab re-tap pop-to-root): the path is
    /// already trimmed, only the list selection needs a refresh.
    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable]) {
        syncSelection()
    }
}

// MARK: - UINavigationControllerDelegate

extension ConversationListCoordinator: UINavigationControllerDelegate {

    /// Forwarded by the router (which owns the delegate slot while bound) to keep
    /// the status navigation bar content up to date.
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        (navigationController as? StatusNavigationController)?.updateNavigationBarContent()
    }
}

// MARK: - ConversationListViewControllerDelegate

extension ConversationListCoordinator: ConversationListViewControllerDelegate {
    func didSelectConversation(conversation: ConversationEntity) {
        if conversation.conversationVisibility == .archived {
            conversationListViewController.selectionManager.removeSelection()
        }

        show(conversation: conversation)
    }

    func archivedConversationListTriggered() {
        showArchivedConversationList()
    }

    func willAppear() {
        syncSelection()
    }

    func willDisappear() {
        dismissPasscodeIfNeeded()
    }

    // MARK: - ChatViewControllerConversationDeletedDelegate

    func chatViewControllerConversationWasDeleted(
        _ chatViewController: ChatViewController
    ) {
        // Dismiss anything presented on top (e.g. single/group details, share sheets)
        chatViewController.presentedViewController?.dismiss(animated: false)

        if presentingViewController?.isCollapsed == false {
            // iPadOS (expanded): clear coordinator state and reset the secondary column.
            resetSelection()
        }
        else {
            // iOS (collapsed): pop from the nav stack
            chatViewController.navigationController?
                .popViewController(animated: true)
        }
    }
}
