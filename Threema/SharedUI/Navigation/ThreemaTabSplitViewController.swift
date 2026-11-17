import UIKit

/// One tab's content: a two-column split view whose primary column is the tab coordinator's own navigation
/// controller (rooted in the tab's list) and whose secondary column is a navigation controller owned here,
/// rooted in a logo placeholder.
///
/// Owns the binding lifecycle of the tab's `NavigationRouter`s through `routerHandle`:
/// - appearance binds for the current layout, keyed off the horizontal size class (`isCollapsed` lags during
///   transitions),
/// - collapse unbinds and clears the secondary column before UIKit merges the columns, then re-materializes the
///   detail stack onto the primary column once the merge is done,
/// - expand unbinds, pops the primary column to its root and re-materializes the stack into the secondary column.
///
/// An appearance whose traits imply a collapse or expand that has not run yet (`isCollapsed` still disagrees
/// with the size class: a first appearance in compact width, or a width change that reached the tab off screen)
/// leaves the binding to that transition's hook, which runs after UIKit is done with the columns. The layout the
/// routers are bound for is tracked across the split view leaving the screen (the routers of an inactive tab
/// stay bound), but the next appearance binds again regardless: an inactive tab may have its screens released
/// (memory warning).
///
/// The routers do the moving instead of UIKit's column merge, so the navigation stacks are never mutated behind
/// the routers' backs.
///
/// Also hides the tab bar for screens that ask for it (`hidesBottomBarWhenPushed`, e.g. chats): UIKit only honors
/// that flag for a navigation controller that is a direct child of the tab bar controller, which the primary
/// column is not anymore. The routers forward the primary column's navigation callbacks here (the split view is
/// their `forwardDelegate`), and the visibility is re-derived on tab switches and collapse/expand.
final class ThreemaTabSplitViewController: UISplitViewController {

    private enum Layout {
        case compact
        case regular
    }

    // MARK: - Properties

    /// The tab this split view is the content of. Named apart from `UIViewController.tab` (the `UITab`, iOS 18).
    let threemaTab: ThreemaTab
    let primaryNavigationController: UINavigationController
    let secondaryNavigationController: UINavigationController
    let placeholderViewController: UIViewController

    /// Set by the tab coordinator before the split view first appears
    var routerHandle: RouterManagedTabHandle?

    /// Receives the navigation callbacks forwarded by the tab's routers after the tab bar visibility was
    /// updated (the coordinator keeps its status navigation bar content up to date through it).
    weak var navigationDelegate: UINavigationControllerDelegate?

    /// The layout the routers are bound for, `nil` while never bound (see the type documentation)
    private var boundLayout: Layout?

    /// Set when the split view leaves the screen: the next bind runs even for the layout already bound, since
    /// the tab's screens may have been released meanwhile.
    private var needsRebind = false

    /// `true` while the columns are collapsed into the primary column (compact width). Keyed off the size
    /// class rather than `isCollapsed`, which lags during transitions.
    var isCompactLayout: Bool {
        traitCollection.horizontalSizeClass == .compact
    }

    private var currentLayout: Layout {
        isCompactLayout ? .compact : .regular
    }

    var secondaryColumn: TabSecondaryColumn {
        TabSecondaryColumn(
            navigationController: secondaryNavigationController,
            placeholderViewController: placeholderViewController
        )
    }

    /// The navigation controller the tab's stack currently lives in
    var activeNavigationController: UINavigationController {
        isCompactLayout ? primaryNavigationController : secondaryNavigationController
    }

    /// Presenter for the tab's modals (passcode prompts, sheets): the active column, so a modal belongs to the
    /// column its screens are in. Falls back to this split view, then to its parent (the tab bar controller),
    /// while the column's view is not in a window yet (e.g. in the same turn as a programmatic tab switch), so
    /// a presentation never silently fails for lack of a window.
    var modalPresenter: UIViewController {
        let column = activeNavigationController
        if column.viewIfLoaded?.window != nil {
            return column
        }
        if viewIfLoaded?.window != nil {
            return self
        }
        return parent ?? self
    }

    // MARK: - Lifecycle

    init(
        tab: ThreemaTab,
        primaryNavigationController: UINavigationController,
        placeholderViewController: UIViewController = ThreemaLogoViewControllerFactory.threemaLogoViewController
    ) {
        self.threemaTab = tab
        self.primaryNavigationController = primaryNavigationController
        self.placeholderViewController = placeholderViewController
        self.secondaryNavigationController = ThemedNavigationController(rootViewController: placeholderViewController)
        super.init(style: .doubleColumn)

        setViewController(primaryNavigationController, for: .primary)
        setViewController(secondaryNavigationController, for: .secondary)
        delegate = self
        configureColumns()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        // Traits are final here, but a collapse or expand they imply runs in the layout pass that follows this
        // callback. Its hook binds once UIKit is done with the columns; binding earlier would race UIKit's
        // column merge (see `splitViewControllerDidCollapse`).
        guard isCollapsed == isCompactLayout else {
            return
        }

        bind(currentLayout)
        updateTabBarVisibility(animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // The next appearance binds again: the tab's screens may be released meanwhile (memory warning), and a
        // rebind with the screens intact is a no-op apply in the routers.
        needsRebind = true
    }

    // MARK: - Configuration

    private func configureColumns() {
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        presentsWithGesture = false
        displayModeButtonVisibility = .never
    }

    // MARK: - Binding

    /// Binds the routers for `layout`, unless they are already bound for it and no rebind is pending
    private func bind(_ layout: Layout) {
        guard let routerHandle, boundLayout != layout || needsRebind else {
            return
        }

        boundLayout = layout
        needsRebind = false
        switch layout {
        case .compact:
            routerHandle.activateCompact()
        case .regular:
            routerHandle.activateRegular(secondaryColumn)
        }
    }

    // MARK: - Tab bar visibility

    /// Hides the tab bar while the collapsed primary column shows a screen that asks for it
    /// (`hidesBottomBarWhenPushed`, kept hidden by screens pushed on top of it, like UIKit does), shows it
    /// otherwise. Expanded layouts never hide it.
    func updateTabBarVisibility(animated: Bool) {
        // Every tab's split view receives size transitions and collapse/expand, but the tab bar is shared: only
        // the selected tab decides, or an inactive tab finishing its transition last shows the bar again.
        guard let tabBarController, tabBarController.selectedViewController === self else {
            return
        }

        let hidden = isCompactLayout
            && primaryNavigationController.viewControllers.contains(where: \.hidesBottomBarWhenPushed)
        guard tabBarController.isTabBarHidden != hidden else {
            return
        }

        tabBarController.setTabBarHidden(hidden, animated: animated)
    }

    /// Puts the secondary column back to the placeholder. Called on collapse (the stack moves to the primary
    /// column) and when the tab's screens are released.
    func resetSecondaryColumn() {
        guard secondaryNavigationController.viewControllers != [placeholderViewController] else {
            return
        }
        secondaryNavigationController.setViewControllers([placeholderViewController], animated: false)
    }

    // MARK: - Show overrides

    /// Legacy callers reach the split view through the responder chain (`show(_:sender:)` from a screen without
    /// a navigation controller). Route them to the column the tab's stack lives in.
    override func show(_ vc: UIViewController, sender: Any?) {
        showInActiveColumn(vc)
    }

    override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        showInActiveColumn(vc)
    }

    private func showInActiveColumn(_ viewController: UIViewController) {
        if isCompactLayout {
            primaryNavigationController.pushViewController(viewController, animated: true)
        }
        else {
            secondaryNavigationController.setViewControllers([viewController], animated: false)
        }
    }
}

// MARK: - UISplitViewControllerDelegate

extension ThreemaTabSplitViewController: UISplitViewControllerDelegate {

    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        // Unbind before clearing the secondary column: a router still bound to it would reconcile the reset
        // as a user pop and drop the detail from the path. The primary column always holds the list, so
        // collapsing onto it never shows an empty column; the detail stack is re-materialized on top of it in
        // `splitViewControllerDidCollapse`. A compact first appearance arrives here unbound (or already bound
        // for compact width by `viewIsAppearing`) and has nothing to unbind.
        if boundLayout == .regular {
            routerHandle?.deactivate()
            boundLayout = nil
        }
        resetSecondaryColumn()
        return .primary
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        // Bind only after UIKit is done with the columns: a stack change made from the collapsing hook competes
        // with UIKit's own collapse of the primary column, which can leave the primary column at the list.
        bind(.compact)
        updateTabBarVisibility(animated: false)
    }

    func splitViewController(
        _ svc: UISplitViewController,
        displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode
    ) -> UISplitViewController.DisplayMode {
        proposedDisplayMode
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        guard let routerHandle else {
            return
        }

        // Unbind before popping so the pop is not reconciled into the path as user navigation, then
        // materialize the path into the secondary column.
        routerHandle.deactivate()
        boundLayout = nil
        primaryNavigationController.popToRootViewController(animated: false)
        bind(.regular)
        updateTabBarVisibility(animated: false)
    }
}

// MARK: - UINavigationControllerDelegate

extension ThreemaTabSplitViewController: UINavigationControllerDelegate {

    /// Forwarded by the tab's routers (which own the delegate slot while bound). Only the primary column
    /// drives the tab bar; the secondary column exists in expanded layouts, where the bar never hides.
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        if navigationController === primaryNavigationController {
            updateTabBarVisibility(animated: animated)

            // A cancelled interactive pop (released swipe-back) shows the previous screen again without
            // another `willShow`; re-derive the visibility from the stack UIKit restored.
            _ = navigationController.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
                guard context.isCancelled else {
                    return
                }
                self?.updateTabBarVisibility(animated: true)
            }
        }

        navigationDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        if navigationController === primaryNavigationController {
            updateTabBarVisibility(animated: animated)
        }

        navigationDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }
}
