import Coordinator
import Foundation
import ThreemaMacros
import UIKit

enum ThreemaTab: Int, CaseIterable {
    case contacts
    case conversations
    case profile
    case settings

    /// Stable `UITab` identifier. UIKit keys sidebar state and `tab(forIdentifier:)` lookups on it, so it must
    /// never change once shipped.
    var identifier: String {
        switch self {
        case .contacts:
            "ch.threema.tab.contacts"
        case .conversations:
            "ch.threema.tab.conversations"
        case .profile:
            "ch.threema.tab.profile"
        case .settings:
            "ch.threema.tab.settings"
        }
    }

    var title: String {
        switch self {
        case .contacts:
            #localize("contacts")
        case .conversations:
            #localize("chats_title")
        case .profile:
            #localize("myIdentity")
        case .settings:
            #localize("settings")
        }
    }

    /// Outline SF Symbol variants: the system switches to the filled variant for the selected tab.
    private var image: UIImage? {
        switch self {
        case .contacts:
            UIImage(systemName: "person.2")
        case .conversations:
            UIImage(systemName: "bubble.left.and.bubble.right")
        case .profile:
            UIImage(systemName: "person.circle")
        case .settings:
            UIImage(systemName: "gear")
        }
    }

    init?(identifier: String) {
        guard let tab = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = tab
    }

    init(_ destination: Destination.AppDestination) {
        switch destination {
        case .contacts:
            self = .contacts
        case .conversations:
            self = .conversations
        case .profile:
            self = .profile
        case .settings:
            self = .settings
        }
    }

    /// The `UITab` shown for this tab, displaying `viewController` when selected.
    ///
    /// Default placement: the iPad tab bar shows title and image, centered. Pinned placement would show the
    /// image only, at the trailing edge, which only reads well next to a sidebar carrying the titles.
    func makeTab(viewController: UIViewController) -> UITab {
        UITab(title: title, image: image, identifier: identifier) { _ in
            viewController
        }
    }
}

/// The app's root view controller: a `UITabBarController` with one `UITab` per `ThreemaTab`, each showing that
/// tab's `ThreemaTabSplitViewController`. On iPad the tab bar sits at the top of the scene (`mode = .tabBar`, no
/// sidebar: a tab's split view already has two columns); on iPhone it is the bottom tab bar.
///
/// Owns tab selection state: user taps and programmatic switches funnel through `TabSelectionState`, so passcode
/// re-authentication of a tab the user returns to runs exactly once per return and a memory warning only
/// releases inactive tabs. Navigation inside a tab is the tab's split view's business.
final class ThreemaTabBarController: UITabBarController {

    // MARK: - Properties

    var selectedThreemaTab: ThreemaTab {
        selectionState.selectedTab
    }

    private var selectionState = TabSelectionState(selectedTab: .conversations)
    private var routerManagedTabHandles: [ThreemaTab: RouterManagedTabHandle] = [:]

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        delegate = self
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard (presentedViewController is PortraitNavigationController) == false else {
            return []
        }

        if traitCollection.horizontalSizeClass == .compact {
            return .allButUpsideDown
        }
        else {
            return .all
        }
    }

    // MARK: - Configuration

    /// Installs one tab per `ThreemaTab` in tab order and selects `initialTab` without animation. Tabs without
    /// a view controller are skipped.
    func configureTabs(
        _ viewControllers: [ThreemaTab: UIViewController],
        initialTab: ThreemaTab = .conversations
    ) {
        tabs = ThreemaTab.allCases.compactMap { tab in
            viewControllers[tab].map { tab.makeTab(viewController: $0) }
        }

        selectionState = TabSelectionState(selectedTab: initialTab)
        if let initialUITab = tab(forIdentifier: initialTab.identifier) {
            UIView.performWithoutAnimation {
                selectedTab = initialUITab
            }
        }
    }

    private func configureAppearance() {
        // iPad: tab bar at the top of the scene. iPhone: bottom bar. The sidebar representation is not used: a
        // tab's split view already shows two columns, and a sidebar next to them makes three.
        mode = .tabBar

        if #available(iOS 26.0, *) {
            // The bar stays at full size while scrolling; the lists are short and a bar that shrinks to the
            // selected icon reads as the tab bar going away.
            tabBarMinimizeBehavior = .never
        }
    }

    // MARK: - Router-managed tabs

    func registerRouterManagedTab(_ tab: ThreemaTab, handle: RouterManagedTabHandle) {
        routerManagedTabHandles[tab] = handle
    }

    /// Frees the inactive tabs' materialized screens (memory warning); they are re-created from the tabs'
    /// paths on the next appearance. The selected tab keeps its screens.
    func releaseInactiveTabs() {
        for tab in selectionState.inactiveTabs {
            routerManagedTabHandles[tab]?.releaseMaterializedScreens()
        }
    }

    // MARK: - Selection

    /// Programmatic, non-animated switch. A no-op when `tab` is already selected.
    func select(_ tab: ThreemaTab) {
        guard let uiTab = self.tab(forIdentifier: tab.identifier) else {
            return
        }

        if selectedTab !== uiTab {
            UIView.performWithoutAnimation {
                selectedTab = uiTab
            }
        }
        handleSelection(of: tab)
    }

    func setBadge(_ value: String?, for tab: ThreemaTab) {
        self.tab(forIdentifier: tab.identifier)?.badgeValue = value
    }

    /// Drops every tab and handle (ID erase, relaunch into onboarding)
    func reset() {
        routerManagedTabHandles.removeAll()
        tabs = []
    }

    private func handleSelection(of tab: ThreemaTab) {
        switch selectionState.select(tab) {
        case .reselected:
            break

        case .switched:
            // The tab bar is hidden explicitly per tab (see `ThreemaTabSplitViewController`), so the entered
            // tab decides whether it stays hidden.
            (selectedViewController as? ThreemaTabSplitViewController)?.updateTabBarVisibility(animated: false)

            // Returning to a tab must not silently re-show passcode-protected screens. The handle decides
            // whether its path holds any; a cancelled prompt clears them.
            routerManagedTabHandles[tab]?.reauthenticateProtectedDestinations()
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension ThreemaTabBarController: UITabBarControllerDelegate {

    /// UIKit performs every user selection itself (including the pop-to-root of a re-tapped tab, which the
    /// tab's router reconciles); only the state follows here. Programmatic switches report here on OS versions
    /// that do so, and `handleSelection` acts once per actual switch either way.
    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelectTab selectedTab: UITab,
        previousTab: UITab?
    ) {
        guard let threemaTab = ThreemaTab(identifier: selectedTab.identifier) else {
            return
        }

        handleSelection(of: threemaTab)
    }

    /// Replaces UIKit's cross-fade between tabs with an in-place switch. The cross-fade renders the content in a
    /// transition context where Liquid Glass elements (such as the navigation bar search field) cannot sample
    /// their backdrop and flash dark until the transition ends.
    func tabBarController(
        _ tabBarController: UITabBarController,
        animationControllerForTransitionFrom fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        InstantTabTransition()
    }
}

// MARK: - InstantTabTransition

/// Puts the entering tab's view in place and completes at once
private final class InstantTabTransition: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        if let toViewController = transitionContext.viewController(forKey: .to),
           let toView = transitionContext.view(forKey: .to) {
            toView.frame = transitionContext.finalFrame(for: toViewController)
            transitionContext.containerView.addSubview(toView)
        }
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
}
