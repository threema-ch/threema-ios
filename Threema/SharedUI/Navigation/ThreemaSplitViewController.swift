import SwiftUI
import UIKit

final class ThreemaSplitViewController: UISplitViewController {

    private(set) lazy var threemaTabBarController = ThreemaTabBarController()
    private(set) lazy var tabBarContainer = TabBarContainerViewController(
        embeddedTabBarController: threemaTabBarController
    )
    lazy var navigationManager = ThreemaSplitViewNavigationManager()

    init() {
        super.init(style: .doubleColumn)

        // The `.compact` column is the view controller a `UISplitViewController` displays while it is
        // collapsed (compact width / iPhone). We install it up front so that, once the split view actually
        // collapses, it shows the tab bar rather than the secondary. NOTE: installing the column does NOT,
        // by itself, make the split view collapse on launch — the launch ordering must attach the
        // fully-configured split view to the window exactly once (see `AppCoordinator.start()` /
        // `RootCoordinator.goToApp`). On regular width the `.compact` column is ignored and
        // `placeTabBarContainer(forCompact:)` moves the same instance to `.primary` once the size class is
        // known.
        setViewController(tabBarContainer, for: .compact)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard (presentedViewController is PortraitNavigationController) == false else {
            return []
        }
        
        if isCollapsed {
            return .allButUpsideDown
        }
        else {
            return .all
        }
    }

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationManager.configure(
            with: self,
            tabBarController: threemaTabBarController
        )
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        presentsWithGesture = false
        
        displayModeButtonItem.customView = UIView()
        displayModeButtonItem.isEnabled = false
        displayModeButtonItem.isHidden = true
        displayModeButtonVisibility = .never

        placeTabBarContainer(forCompact: traitCollection.horizontalSizeClass == .compact)

        // The initial tab is selected programmatically before the manager is
        // configured (no delegate fires), so its router-managed coordinator was
        // never activated. Activate it now that the hierarchy is set up;
        // re-activation on later appearances is idempotent.
        navigationManager.restoreTabStack(for: threemaTabBarController.selectedThreemaTab)
    }

    override func willTransition(
        to newCollection: UITraitCollection,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.willTransition(to: newCollection, with: coordinator)
        placeTabBarContainer(forCompact: newCollection.horizontalSizeClass == .compact)
    }

    /// A column-based `UISplitViewController` only collapses on compact width when it has an
    /// explicit `.compact` column; otherwise it stays expanded in `.secondaryOnly` and shows
    /// the (empty) detail. The same `tabBarContainer` instance can't occupy two columns at
    /// once, so we move it: `.compact` when compact (collapsed → tab bar),
    /// `.primary` when regular (tab bar as the left column on iPad).
    private func placeTabBarContainer(forCompact: Bool) {
        let targetColumn: UISplitViewController.Column = forCompact ? .compact : .primary
        let otherColumn: UISplitViewController.Column = forCompact ? .primary : .compact
        guard viewController(for: targetColumn) !== tabBarContainer else {
            return
        }

        /// Never leave the same instance referenced by two columns.
        if viewController(for: otherColumn) === tabBarContainer {
            setViewController(nil, for: otherColumn)
        }

        setViewController(tabBarContainer, for: targetColumn)
    }

    // MARK: - Public functions

    func switchTabIfNeeded(to item: ThreemaTab) {
        guard threemaTabBarController.selectedIndex != item.rawValue else {
            return
        }

        navigationManager.storeCurrentTabStack()
        /// Non-animated: see `ThreemaSplitViewNavigationManager.tabBarController(_:shouldSelect:)`.
        UIView.performWithoutAnimation {
            threemaTabBarController.selectedIndex = item.rawValue
        }
        navigationManager.restoreTabStack(for: item)
    }
    
    func navigationController(
        for item: ThreemaTab
    ) -> UINavigationController? {
        if isCollapsed {
            threemaTabBarController.navigationController(
                for: item
            )
        }
        else {
            viewController(for: .secondary) as? UINavigationController
        }
    }

    func reset() {
        setViewController(nil, for: .compact)
        setViewController(nil, for: .primary)
        setViewController(nil, for: .secondary)
    }

    // MARK: - Show Overrides

    /// Routes detail content to the correct place depending on collapsed state.
    /// The column-based split VC does not reliably call the delegate's
    /// `show(_:sender:)` / `showDetail(_:sender:)` methods, so we override
    /// them directly.
    override func show(_ vc: UIViewController, sender: Any?) {
        navigationManager.showViewController(vc, in: self)
    }

    override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        navigationManager.showViewController(vc, in: self)
    }

    func isTopControllerChat(for contact: ContactEntity?) -> Bool {
        guard
            threemaTabBarController.selectedThreemaTab == .conversations,
            let contact,
            let navigationController = navigationController(for: .conversations),
            let chatViewController = navigationController.topViewController as? ChatViewController
        else {
            return false
        }
        
        return chatViewController.isChat(for: contact)
    }
}
