import UIKit

/// The narrow surface a *child* coordinator uses to contribute screens to a
/// parent's shared navigation path.
///
/// Why a child can't just own its own router: a `NavigationRouter` takes over
/// its `UINavigationController`'s delegate slot and forbids anyone else from
/// mutating that stack, so two routers cannot drive one navigation controller.
/// A child therefore renders into the parent's single path instead — it
/// registers a builder for its own destination type and pushes type-erased
/// destinations. Each destination stays a first-class path element, so back,
/// swipe-back, pop-to-root, deep links and self-healing all keep working across
/// the boundary.
///
/// A child depends only on this protocol, never on the concrete parent — coupling
/// stays one-directional and minimal. A router-owning coordinator vends one with
/// `RouterPathHost(router:)`.
@MainActor
public protocol PathHost: AnyObject {

    /// Registers how to build screens for the child's own destinations. The
    /// builder returns `nil` for anything it does not own, so the host stays
    /// agnostic of concrete child types.
    ///
    /// - Returns: A token to pass to `removeScreenBuilder(_:)` on teardown.
    @discardableResult
    func registerScreenBuilder(
        _ build: @escaping (AnyHashable) -> UIViewController?
    ) -> ScreenBuilderToken

    /// Removes a builder registered with `registerScreenBuilder(_:)`.
    func removeScreenBuilder(_ token: ScreenBuilderToken)

    /// Pushes a type-erased destination onto the shared path. Showing the
    /// destination already on top is a no-op.
    func push(_ destination: AnyHashable, animated: Bool)

    /// Pops the top of the shared path, whoever owns it.
    func pop(animated: Bool)
}

/// The `PathHost` a router-owning coordinator hands to its children: a thin
/// adapter over its `NavigationRouter`.
///
/// It is a separate object (not the coordinator itself) on purpose: it keeps the
/// erased `push`/`pop` off the coordinator's own typed `PathCoordinator` API —
/// which already has same-named members — and hands children exactly the four
/// calls they need, nothing more.
@MainActor
public final class RouterPathHost: PathHost {

    private let router: NavigationRouter

    public init(router: NavigationRouter) {
        self.router = router
    }

    @discardableResult
    public func registerScreenBuilder(
        _ build: @escaping (AnyHashable) -> UIViewController?
    ) -> ScreenBuilderToken {
        router.registerScreenBuilder(build)
    }

    public func removeScreenBuilder(_ token: ScreenBuilderToken) {
        router.removeScreenBuilder(token)
    }

    public func push(_ destination: AnyHashable, animated: Bool) {
        guard router.path.last != destination else {
            return
        }
        router.setPath(router.path + [destination], animated: animated)
    }

    public func pop(animated: Bool) {
        guard !router.path.isEmpty else {
            return
        }
        router.setPath(Array(router.path.dropLast()), animated: animated)
    }
}
