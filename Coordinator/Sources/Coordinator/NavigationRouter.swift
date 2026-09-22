import UIKit

/// Opaque handle for a screen builder registered on a `NavigationRouter`.
///
/// A child coordinator keeps its token and passes it to
/// `removeScreenBuilder(_:)` when it finishes, so its builder does not outlive
/// it. Identity-based: two tokens are never equal.
@MainActor
public final class ScreenBuilderToken {
    fileprivate init() { }
}

/// Receives notifications when the user changes the bound navigation stack directly
/// (back button, swipe-back, pop to root).
@MainActor
public protocol NavigationRouterDelegate: AnyObject {
    /// The user popped back. The router has already trimmed its `path`;
    /// the coordinator must sync its own typed state to the new path.
    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable])
}

/// Binds a value-typed navigation path to a `UINavigationController`.
///
/// The path is the single source of truth for what is on the stack:
/// - **State → UI:** `setPath(_:animated:)` derives the view controller stack from
///   the path — reusing already-materialized screens for unchanged destinations —
///   and applies the cheapest matching UIKit operation (push, pop, or replace).
///   Mutations requested during an active transition are queued and coalesced,
///   because UIKit silently drops stack mutations issued mid-transition.
/// - **UI → state:** user-initiated pops (back button, swipe-back — including
///   cancelled swipes — and pop-to-root) are reconciled back into the path via
///   `UINavigationControllerDelegate`, so the path can never go stale.
///
/// Destinations that can no longer be materialized (the factory returns `nil`,
/// e.g. because the backing entity was deleted) are dropped from the path together
/// with everything above them, instead of presenting dead screens.
///
/// The router owns the navigation controller's `delegate` slot while bound. Other
/// delegate-based behavior can be preserved through `forwardDelegate`.
///
/// - Important: While a router is bound, nothing else may mutate the navigation
///   controller's `viewControllers`.
@MainActor
public final class NavigationRouter: NSObject {

    /// How the root view controller of a binding behaves.
    public enum RootMode {
        /// The root is a real screen (e.g. the tab's list in collapsed width):
        /// path changes animate as pushes/pops and screens show a back button.
        case screen

        /// The root is an empty-state placeholder (e.g. the secondary column of
        /// a split view): it is only shown while the path is empty. The first
        /// path element becomes the actual root of the navigation stack — it
        /// appears in place instead of being pushed and has no back button.
        case placeholder
    }

    // MARK: - Public properties

    /// Single source of truth for the bound navigation stack, excluding the root
    /// screen. `path.last` is the currently shown destination.
    ///
    /// Elements must be unique: the same destination cannot appear twice, because a
    /// materialized screen cannot occupy two positions in a `UINavigationController`.
    public private(set) var path: [AnyHashable] = []

    public weak var delegate: NavigationRouterDelegate?

    /// Receives `UINavigationControllerDelegate` calls after the router handled
    /// them. Use this to keep existing delegate-based behavior (e.g. navigation bar
    /// content updates) while the router occupies the delegate slot.
    public weak var forwardDelegate: UINavigationControllerDelegate?

    /// `true` while the router is bound to a navigation controller.
    public var isBound: Bool {
        navigationController != nil
    }

    // MARK: - Private properties

    private weak var navigationController: UINavigationController?
    private var rootViewController: UIViewController?
    private var rootMode: RootMode = .screen
    private var makeViewController: ((AnyHashable) -> UIViewController?)?

    /// Builders registered by child coordinators for destinations this router's
    /// owner does not build itself. Consulted in registration order, after the
    /// primary `makeViewController`, when materializing a path element. Kept
    /// across unbind/rebind (a child outlives a tab deactivation), so they are
    /// only dropped by `removeScreenBuilder(_:)`.
    private var additionalScreenBuilders: [(token: ScreenBuilderToken, build: (AnyHashable) -> UIViewController?)] = []

    /// Screens currently materialized for path elements.
    private var materialized: [AnyHashable: UIViewController] = [:]

    /// `true` while an apply is queued behind an active transition. While set, a
    /// drain chain (`scheduleApply`) is alive; a duplicate chain after an
    /// unbind/rebind is harmless — whichever runs first applies and clears the
    /// flag, the rest exit on the cleared flag.
    private var needsApply = false
    /// Animation requested for the queued apply (last request wins).
    private var applyAnimated = false

    // MARK: - Binding

    /// Binds (or re-binds, after a split view collapse/expand) the router to the
    /// physical navigation controller, and materializes root + path into it.
    ///
    /// - Parameters:
    ///   - navigationController: The navigation controller to own. The router
    ///     becomes its delegate.
    ///   - rootViewController: The screen at the base of the stack. Not part of
    ///     `path`; an empty path shows only this screen.
    ///   - rootMode: Whether the root is a real screen or an empty-state
    ///     placeholder the first path element visually replaces.
    ///   - makeViewController: Creates the screen for a destination. Returning
    ///     `nil` marks the destination as unresolvable, truncating the path there.
    ///     Called once per destination; materialized screens are reused until the
    ///     destination leaves the path.
    public func bind(
        to navigationController: UINavigationController,
        rootViewController: UIViewController,
        rootMode: RootMode = .screen,
        makeViewController: @escaping (AnyHashable) -> UIViewController?
    ) {
        unbind()

        self.navigationController = navigationController
        self.rootViewController = rootViewController
        self.rootMode = rootMode
        self.makeViewController = makeViewController
        navigationController.delegate = self

        diagnose("bind to \(describe(navigationController)), root \(describe(rootViewController)), path \(path)")

        applyWhenReady(animated: false)
    }

    /// The screen currently materialized for `destination`, if it is part of the
    /// path. Useful to read screen state (e.g. the entity a detail screen shows)
    /// without keeping a second reference outside the router.
    public func materializedViewController(for destination: AnyHashable) -> UIViewController? {
        materialized[destination]
    }

    /// Drops the materialized screen for `destination` so the next apply builds a
    /// fresh one. Use when the same destination must be re-shown with new content
    /// (e.g. a chat that needs its compose state replaced).
    public func invalidateMaterializedScreen(for destination: AnyHashable) {
        materialized.removeValue(forKey: destination)
    }

    /// Drops all materialized screens so the next apply re-creates them from the
    /// path (e.g. to free memory after a memory warning). No-op while bound: the
    /// navigation controller retains the screens anyway — nothing would be freed —
    /// and dropping them would break the reconciliation of user pops.
    public func releaseMaterializedScreens() {
        guard !isBound else {
            return
        }
        diagnose("releaseMaterializedScreens (path \(path))")
        materialized.removeAll()
    }

    // MARK: - Screen builders

    /// Registers a builder for destinations the router's owner does not build
    /// itself, so a child coordinator can render its own screens into this
    /// router's shared path. The builder returns `nil` for destinations it does
    /// not own; builders are consulted in registration order after the primary
    /// `makeViewController`.
    ///
    /// - Returns: A token to pass to `removeScreenBuilder(_:)` when the child is
    ///   torn down.
    @discardableResult
    public func registerScreenBuilder(
        _ build: @escaping (AnyHashable) -> UIViewController?
    ) -> ScreenBuilderToken {
        let token = ScreenBuilderToken()
        additionalScreenBuilders.append((token, build))
        return token
    }

    /// Removes a previously registered screen builder. Screens already
    /// materialized by it stay on the stack until they leave the path.
    public func removeScreenBuilder(_ token: ScreenBuilderToken) {
        additionalScreenBuilders.removeAll { $0.token === token }
    }

    /// Resolves the screen for a destination: the owner's own builder first,
    /// then each registered child builder in order.
    private func resolveScreen(for destination: AnyHashable) -> UIViewController? {
        if let viewController = makeViewController?(destination) {
            return viewController
        }
        for entry in additionalScreenBuilders {
            if let viewController = entry.build(destination) {
                return viewController
            }
        }
        return nil
    }

    /// Detaches the router from its navigation controller without touching the
    /// path. Materialized screens are kept so a later `bind(to:...)` restores them.
    public func unbind() {
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
        navigationController = nil
        rootViewController = nil
        makeViewController = nil
        needsApply = false
    }

    // MARK: - State → UI

    /// Replaces the whole path. This is the only mutating entry point; expressing
    /// push/pop as `setPath` keeps deep links, resets, and single steps on one code
    /// path (transition-safe, coalesced).
    public func setPath(_ newPath: [AnyHashable], animated: Bool) {
        assert(
            Set(newPath).count == newPath.count,
            "Navigation path must not contain duplicate destinations"
        )

        path = newPath
        applyWhenReady(animated: animated)
    }

    private func applyWhenReady(animated: Bool) {
        guard let navigationController else {
            return
        }

        // UIKit silently ignores stack mutations while a transition is running
        // (e.g. during cold start when a split view collapse and the initial
        // appearance overlap; `transitionCoordinator` also reports ancestor
        // transitions such as a modal dismissing above the whole hierarchy).
        // Mark dirty and apply once the transition is gone. (Attaching a
        // completion to the running transition coordinator is NOT reliable:
        // `animate(alongsideTransition:)` can silently do nothing when the
        // transition is already underway.)
        if navigationController.transitionCoordinator != nil {
            applyAnimated = animated
            diagnose("apply deferred — transition in flight (path \(path))")
            if !needsApply {
                needsApply = true
                scheduleApply()
            }
        }
        else {
            needsApply = false
            applyNow(animated: animated)
        }
    }

    /// Applies a queued path change once no transition is in flight anymore, by
    /// re-checking every run-loop pass. UIKit transitions are run-loop-driven, so
    /// this fires right after the transition tears down — including transitions
    /// that never produce a callback on this navigation controller.
    /// (`RunLoop.perform`, not `DispatchQueue.main.async`: the latter cannot run
    /// while the main queue's current work item is still spinning the run loop.)
    private func scheduleApply() {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                guard
                    self.needsApply,
                    let navigationController = self.navigationController
                else {
                    return
                }

                guard navigationController.transitionCoordinator == nil else {
                    self.scheduleApply()
                    return
                }

                self.needsApply = false
                self.applyNow(animated: self.applyAnimated)
            }
        }
    }

    private func applyNow(animated: Bool) {
        guard
            let navigationController,
            let rootViewController,
            // Bound check: the primary builder is set by `bind` and cleared by
            // `unbind`. Resolution goes through `resolveScreen(for:)`.
            makeViewController != nil
        else {
            diagnose("applyNow skipped — not bound (path: \(path))")
            return
        }

        var pathViewControllers: [UIViewController] = []
        var newMaterialized: [AnyHashable: UIViewController] = [:]
        var materializedPath: [AnyHashable] = []

        for destination in path {
            let viewController: UIViewController

            if let existing = materialized[destination] {
                viewController = existing
            }
            else if let created = resolveScreen(for: destination) {
                viewController = created
            }
            else {
                // Self-heal: the destination can't be shown anymore (entity
                // deleted). Drop it and everything above it.
                break
            }

            pathViewControllers.append(viewController)
            newMaterialized[destination] = viewController
            materializedPath.append(destination)
        }

        if materializedPath.count < path.count {
            path = materializedPath
        }

        materialized = newMaterialized

        // In placeholder mode the placeholder is only part of the stack while the
        // path is empty: the first path element IS the navigation root, so it can
        // never show a back button leading to the placeholder.
        let stack = composedStack(
            rootViewController: rootViewController,
            pathViewControllers: pathViewControllers
        )

        let current = navigationController.viewControllers

        if stack == current {
            diagnose("applyNow no-op — stack already matches path \(path)")
            return
        }

        var animated = animated

        // Animated transitions on a navigation controller whose view is not in a
        // window never complete — UIKit never fires their delegate callbacks, the
        // transition coordinator stays alive, and every subsequent mutation would
        // be deferred forever behind it (e.g. a deep link applied during cold
        // start, before the first frame is rendered).
        if navigationController.viewIfLoaded?.window == nil {
            animated = false
        }

        if rootMode == .placeholder {
            // A change at the root of the stack (first path element appears, is
            // replaced, or is cleared back to the placeholder) appears in place —
            // like a detail column replacement — instead of animating as a
            // push/pop. Changes deeper in the path still animate.
            let commonPrefixCount = zip(stack, current).prefix { $0 == $1 }.count
            if commonPrefixCount == 0 {
                animated = false
            }
        }

        if stack.count == current.count + 1, Array(stack.dropLast()) == current {
            diagnose("applyNow push \(describe(stack.last)) onto \(describe(navigationController))")
            navigationController.pushViewController(stack[stack.count - 1], animated: animated)
        }
        else if stack.count < current.count, Array(current.prefix(stack.count)) == stack {
            diagnose("applyNow pop to \(describe(stack.last)) on \(describe(navigationController))")
            navigationController.popToViewController(stack[stack.count - 1], animated: animated)
        }
        else {
            diagnose(
                "applyNow replace on \(describe(navigationController)): \(current.map(describe)) → \(stack.map(describe))"
            )
            navigationController.setViewControllers(stack, animated: animated)
        }

        assertStackMatchesPath(afterAnimatedChange: animated)
    }

    /// The full view controller stack for the current mode: in `.screen` mode the
    /// root is always at the base; in `.placeholder` mode it is shown only while
    /// there is no path (the first path element is the actual root otherwise).
    private func composedStack(
        rootViewController: UIViewController,
        pathViewControllers: [UIViewController]
    ) -> [UIViewController] {
        if rootMode == .placeholder, !pathViewControllers.isEmpty {
            return pathViewControllers
        }
        return [rootViewController] + pathViewControllers
    }

    // MARK: - Diagnostics

    private func diagnose(_ message: @autoclosure () -> String) {
        #if DEBUG
            print("[NavigationRouter \(Unmanaged.passUnretained(self).toOpaque())] \(message())")
        #endif
    }

    private func describe(_ object: AnyObject?) -> String {
        guard let object else {
            return "nil"
        }
        return "\(type(of: object))(\(Unmanaged.passUnretained(object).toOpaque()))"
    }

    // MARK: - UI → State

    private func reconcile() {
        // A programmatic apply is queued; the visible stack is stale and will be
        // replaced when the transition settles. Reconciling now would trim the
        // just-set path against the outdated stack.
        guard !needsApply else {
            return
        }

        guard let navigationController else {
            return
        }

        let visible = navigationController.viewControllers

        // Only reconcile when the top of the stack is a screen the router knows
        // (a path screen or the root). A user pop always lands on one; interim
        // stacks reported while coalesced transitions settle — and screens pushed
        // by foreign code — do not, and must never trim the path.
        guard
            let topViewController = visible.last,
            topViewController === rootViewController
            || destination(for: topViewController) != nil
        else {
            diagnose("reconcile skipped — unknown top \(describe(visible.last))")
            return
        }

        let newPath = visible.compactMap {
            destination(for: $0)
        }

        // Growth and replacement are always router-initiated; only user pops
        // (a strict prefix of the current path) reconcile here.
        guard
            newPath.count < path.count,
            Array(path.prefix(newPath.count)) == newPath
        else {
            return
        }

        diagnose("reconcile user pop \(path) → \(newPath) on \(describe(navigationController))")

        path = newPath
        materialized = materialized.filter { destination, _ in
            newPath.contains(destination)
        }

        delegate?.router(self, didPopTo: newPath)
    }

    /// The destination whose materialized screen is `viewController`, if any.
    /// A linear scan — `materialized` is bounded by the path depth.
    private func destination(for viewController: UIViewController) -> AnyHashable? {
        materialized.first { $0.value === viewController }?.key
    }

    private func assertStackMatchesPath(afterAnimatedChange: Bool) {
        #if DEBUG
            guard
                let navigationController,
                let rootViewController,
                // During an animated change UIKit transiently reports a merged
                // array (the disappearing top view controller stays in
                // `viewControllers` until the transition settles), so the
                // invariant can only be checked after non-animated mutations
                // and outside of running transitions.
                !afterAnimatedChange,
                navigationController.transitionCoordinator == nil
            else {
                return
            }

            // Screens may push their own sub-screens onto the stack (they are
            // reconciled away once popped), so the derived stack must be a prefix
            // of the actual one — anything below it was mutated behind our back.
            let expected = composedStack(
                rootViewController: rootViewController,
                pathViewControllers: path.compactMap { materialized[$0] }
            )
            assert(
                Array(navigationController.viewControllers.prefix(expected.count)) == expected,
                """
                Navigation stack was mutated behind the router's back on \
                \(describe(navigationController)) — expected prefix \
                \(expected.map(describe)), actual \
                \(navigationController.viewControllers.map(describe)), path \(path)
                """
            )
        #endif
    }
}

// MARK: - UINavigationControllerDelegate

extension NavigationRouter: UINavigationControllerDelegate {

    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        forwardDelegate?.navigationController?(
            navigationController,
            willShow: viewController,
            animated: animated
        )
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        forwardDelegate?.navigationController?(
            navigationController,
            didShow: viewController,
            animated: animated
        )

        // A queued apply is drained by `scheduleApply` on the next run-loop pass
        // (once the transition that just ended is fully torn down). Never
        // reconcile the transient stack it was deferred behind.
        guard !needsApply else {
            return
        }

        // An interactive pop (swipe-back) reports `didShow` when the gesture
        // starts, not when it commits. Only reconcile once the interaction ends
        // uncancelled — otherwise a released swipe would corrupt the path.
        if let transitionCoordinator = navigationController.transitionCoordinator,
           transitionCoordinator.isInteractive {
            transitionCoordinator.notifyWhenInteractionChanges { context in
                MainActor.assumeIsolated {
                    guard !context.isCancelled else {
                        return
                    }
                    self.reconcile()
                }
            }
            return
        }

        reconcile()
    }
}
