import UIKit

/// A `Coordinator` whose navigation surface is described by a value-typed path.
///
/// `path.last` is the currently shown destination; an empty path means only the
/// root screen is visible. There is no separate "current destination" to keep in
/// sync and nothing to reset by hand — resetting is `setPath([])`, and user pops
/// flow back into the path through the coordinator's `NavigationRouter`.
///
/// Implementations own a `NavigationRouter` and must:
/// - forward `setPath` to the router (type-erasing destinations to `AnyHashable`),
/// - update `path` from `NavigationRouterDelegate.router(_:didPopTo:)`.
@MainActor
public protocol PathCoordinator: Coordinator {
    associatedtype Destination: Hashable

    /// Value-typed navigation stack, root excluded. Single source of truth.
    var path: [Destination] { get }

    /// Replaces the whole stack. Reset ≡ `setPath([])`; deep links pass the
    /// complete stack in one call.
    func setPath(_ path: [Destination], animated: Bool)
}

extension PathCoordinator {

    /// The destination currently on top, or `nil` when only the root is visible.
    public var currentDestination: Destination? {
        path.last
    }

    /// Pushes a destination on top of the current path.
    /// Showing the destination that is already on top is a no-op.
    public func push(_ destination: Destination, animated: Bool = true) {
        guard path.last != destination else {
            return
        }
        setPath(path + [destination], animated: animated)
    }

    /// Pops the top destination, if any.
    public func pop(animated: Bool = true) {
        guard !path.isEmpty else {
            return
        }
        setPath(Array(path.dropLast()), animated: animated)
    }

    /// Pops everything back to the root screen.
    public func popToRoot(animated: Bool = true) {
        setPath([], animated: animated)
    }
}
