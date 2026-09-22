import UIKit

final class ThreemaSplitViewNavigationManager: NSObject {
    
    // MARK: - Private properties

    private weak var splitViewController: ThreemaSplitViewController?
    private weak var tabBarController: ThreemaTabBarController?

    private var secondaryNavigationController: UINavigationController? {
        splitViewController?.viewController(for: .secondary) as? UINavigationController
    }

    /// Tabs whose navigation is driven by a `NavigationRouter` (path data) instead
    /// of stored view controller stacks. The manager calls the handle's hooks for
    /// these tabs and never touches their stacks itself.
    private var routerManagedTabHandles: [ThreemaTab: RouterManagedTabHandle] = [:]

    /// Tabs that were deactivated since their last activation, i.e. the ones the
    /// user actually left. Their passcode-protected destinations must
    /// re-authenticate before they are shown again; a tab that was never left
    /// keeps the authentication it already passed.
    private var tabsPendingReauthentication: Set<ThreemaTab> = []

    /// `true` between `shouldSelect` and `didSelect` when the user re-tapped the
    /// already selected tab.
    private var isReselectingCurrentTab = false
    
    /// `true` when the split view lays its columns out side by side (regular
    /// width) rather than the collapsed single-column (compact) layout. Mirrors
    /// the `traitCollection.horizontalSizeClass == .compact` check in
    /// `ThreemaSplitViewController.placeTabBarContainer(forCompact:)`.
    private var isRegularWidth: Bool {
        splitViewController?.traitCollection.horizontalSizeClass != .compact
    }

    // MARK: - Public methods
    
    func configure(
        with splitViewController: ThreemaSplitViewController,
        tabBarController: ThreemaTabBarController
    ) {
        self.splitViewController = splitViewController
        self.tabBarController = tabBarController
        
        splitViewController.delegate = self
        tabBarController.delegate = self
    }
    
    /// Programmatic tab switches (setting `selectedIndex`) don't trigger
    /// `UITabBarControllerDelegate`. Call these before/after changing
    /// `selectedIndex` to perform the same store/restore cycle the delegate would.
    func storeCurrentTabStack() {
        storeCurrentViewControllerStack()
    }

    func restoreTabStack(for tab: ThreemaTab) {
        restoreViewControllerStack(for: tab)
    }

    func registerRouterManagedTab(_ tab: ThreemaTab, handle: RouterManagedTabHandle) {
        routerManagedTabHandles[tab] = handle
    }

    /// Frees the inactive tabs' materialized screens (memory warning). The
    /// active tab's routers are bound and no-op.
    func releaseMaterializedScreens() {
        for handle in routerManagedTabHandles.values {
            handle.releaseMaterializedScreens()
        }
    }

    /// Routes a view controller to the correct navigation context.
    /// Called by `ThreemaSplitViewController.show(_:sender:)` and
    /// `showDetailViewController(_:sender:)` — the column-based split VC does
    /// not reliably call the delegate's `show`/`showDetail` methods, so the
    /// controller overrides them and routes here directly.
    func showViewController(
        _ vc: UIViewController,
        in splitViewController: UISplitViewController
    ) {
        if splitViewController.isCollapsed {
            guard let navigationController = tabBarController?.selectedViewController
                as? UINavigationController else {
                return
            }
            navigationController.pushViewController(vc, animated: true)
        }
        else {
            guard let navigationController = splitViewController.viewController(
                for: .secondary
            ) as? UINavigationController else {
                return
            }
            navigationController.setViewControllers([vc], animated: false)
        }
    }

    // MARK: - Private methods

    private func storeCurrentViewControllerStack() {
        guard let currentTab = tabBarController?.selectedThreemaTab else {
            return
        }

        // Router-managed tabs: unbind the router so it stops observing a navigation
        // controller another tab is about to use. Leaving the tab also invalidates
        // the authentication its protected destinations passed.
        if let handle = routerManagedTabHandles[currentTab] {
            handle.deactivate()
            tabsPendingReauthentication.insert(currentTab)
        }
    }
    
    private func restoreViewControllerStack(for tab: ThreemaTab) {
        guard let handle = routerManagedTabHandles[tab] else {
            return
        }

        // Returning to a tab must not silently re-show passcode-protected
        // screens — ask for the passcode again (a cancelled prompt clears them).
        // Collapse/expand transitions don't go through here, so they never
        // re-prompt.
        //
        // Only a tab the user actually left needs this. `restoreTabStack(for:)` is
        // also called from `viewIsAppearing`, which fires again whenever a
        // `.fullScreen` modal presented from inside the tab is dismissed (UIKit
        // forwards the appearance callbacks up the presenting containment chain).
        // The passcode settings screen presents the set/change/disable lock screen
        // exactly that way, so re-prompting unconditionally asks for the passcode
        // the user just created, on top of the screen they never left.
        if tabsPendingReauthentication.remove(tab) != nil {
            handle.reauthenticateProtectedDestinations()
        }

        // Bind to the regular (two-column) layout only in regular width. We key
        // this off the horizontal size class rather than `isCollapsed`: at launch
        // the split view is created collapsed on a compact-width iPhone without an
        // expanded to collapsed transition, so `isCollapsed` still reports its stale
        // `false` here (and again during `viewIsAppearing`) — which would bind the
        // router to the off-screen `.secondary` column, leaving tapped chats
        // invisible until a tab switch forces a rebind. `placeTabBarContainer`
        // already keys the tab bar's column off the same signal, so the two stay
        // consistent.
        if isRegularWidth,
           let secondaryNavigationController {
            handle.activateRegular(secondaryNavigationController)
        }
        else {
            handle.activateCompact()
        }
    }
}

// MARK: - UISplitViewControllerDelegate

extension ThreemaSplitViewNavigationManager: UISplitViewControllerDelegate {
    
    // MARK: - Collapse Handling
    
    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        // Clear the secondary column and re-bind the selected tab's router to the
        // tab's own navigation controller. It re-materializes the stack from its
        // path — no view controller transfer needed.
        if let tabBarController,
           let handle = routerManagedTabHandles[tabBarController.selectedThreemaTab] {
            if let secondaryNavigationController = svc.viewController(for: .secondary) as? UINavigationController {
                secondaryNavigationController.setViewControllers([], animated: false)
            }
            handle.activateCompact()
        }

        // When a `.compact` column is installed (the tab bar lives there on a compact-width launch /
        // portrait iPhone), the collapsed interface IS that column, and the split view proposes `.compact`.
        // Honor the proposal: overriding to `.primary` collapses onto the (empty) primary column and leaves
        // the stale secondary (logo) on screen — the empty-logo-on-launch bug. When there is NO `.compact`
        // column (e.g. collapsing back from a regular/expanded layout, where the tab bar has been moved into
        // `.primary`), collapse onto `.primary` so the tab bar becomes the top of the collapsed stack.
        if svc.viewController(for: .compact) != nil {
            return proposedTopColumn
        }
        return .primary
    }

    // MARK: - Expand Handling

    func splitViewController(
        _ svc: UISplitViewController,
        displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode
    ) -> UISplitViewController.DisplayMode {
        proposedDisplayMode
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        guard let tabBarController else {
            svc.setViewController(
                ThreemaLogoViewControllerFactory.threemaLogoNavigationController(),
                for: .secondary
            )
            return
        }

        // Unbind every router-managed tab before popping to root, so the pops are
        // not reconciled into their paths as user navigation.
        for tab in ThreemaTab.allCases {
            routerManagedTabHandles[tab]?.deactivate()
        }

        // Pop all tabs to root
        if let tabViewControllers = tabBarController.viewControllers {
            for tabViewController in tabViewControllers {
                (tabViewController as? UINavigationController)?
                    .popToRootViewController(animated: false)
            }
        }

        let selectedTab = tabBarController.selectedThreemaTab
        guard let handle = routerManagedTabHandles[selectedTab] else {
            svc.setViewController(
                ThreemaLogoViewControllerFactory.threemaLogoNavigationController(),
                for: .secondary
            )
            return
        }

        // Bind the router into the secondary navigation controller; it
        // materializes placeholder + path into it. Reuse an existing secondary
        // nav already in the view hierarchy — creating a new
        // UINavigationController and calling setViewController after the expand
        // completes does not reliably update the layout.
        if let existingSecondaryNavigationController = svc.viewController(for: .secondary)
            as? UINavigationController {
            handle.activateRegular(existingSecondaryNavigationController)
        }
        else {
            let secondaryNavigationController = UINavigationController()
            handle.activateRegular(secondaryNavigationController)
            svc.setViewController(secondaryNavigationController, for: .secondary)
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension ThreemaSplitViewNavigationManager: UITabBarControllerDelegate {
    
    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        // Re-tapping the selected tab is UIKit's built-in pop-to-root, not a tab
        // switch: the router must stay bound so it reconciles the pop into its
        // path. Unbinding here would let the rebind in `didSelect` re-apply the
        // stale path right after the pop (the just-popped screen comes back).
        isReselectingCurrentTab = viewController === tabBarController.selectedViewController
        guard !isReselectingCurrentTab else {
            return true
        }

        // Different tab: perform the switch ourselves, without animation, and tell UIKit not to.
        // iPadOS animates tab changes with a cross-fade that renders the tab content in a transition
        // context where Liquid Glass elements (such as the navigation bar search field) cannot sample
        // their backdrop and flash dark until the transition ends.
        storeCurrentViewControllerStack()

        /// Same-tab re-tap: let UIKit handle it (pop to root); `didSelect` reconciles the stored stack.
        guard viewController !== tabBarController.selectedViewController else {
            return true
        }

        /// Different tab: perform the switch ourselves, without animation, and tell UIKit not to.
        /// iPadOS animates tab changes with a cross-fade that renders the tab content in a transition
        /// context where Liquid Glass elements (such as the navigation bar search field) cannot sample
        /// their backdrop and flash dark until the transition ends.
        UIView.performWithoutAnimation {
            tabBarController.selectedViewController = viewController
        }

        // `didSelect` does not fire when `shouldSelect` returns `false`, so perform
        // the restore it would have done here.
        if let threemaTabBarController = tabBarController as? ThreemaTabBarController {
            restoreViewControllerStack(for: threemaTabBarController.selectedThreemaTab)
        }

        return false
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let tabBarController = tabBarController as? ThreemaTabBarController else {
            return
        }

        guard !isReselectingCurrentTab else {
            isReselectingCurrentTab = false
            return
        }

        restoreViewControllerStack(for: tabBarController.selectedThreemaTab)
    }
}
