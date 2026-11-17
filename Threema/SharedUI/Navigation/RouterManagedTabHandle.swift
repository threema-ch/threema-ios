import UIKit

/// The secondary column a tab renders its detail stack into while its split view is expanded (regular width).
///
/// The split view owns both objects; the placeholder is what the column shows while the tab's path is empty.
struct TabSecondaryColumn {
    let navigationController: UINavigationController
    let placeholderViewController: UIViewController
}

/// Bridge between a tab's split view / the tab bar controller and a tab coordinator whose navigation is driven
/// by a `NavigationRouter`.
///
/// The coordinator keeps its state as a value-typed path; the split view calls these hooks on appearance and
/// on collapse/expand transitions, the tab bar controller on tab switches and memory warnings, and the
/// coordinator re-materializes its stack from the path.
@MainActor
struct RouterManagedTabHandle {

    /// Unbind the router: its navigation controller is about to be mutated by someone else (e.g. popped to
    /// root before an expand). Path data survives; materialized screens may be reused on the next activation.
    let deactivate: () -> Void

    /// Bind the router to the tab's own navigation controller (collapsed width).
    let activateCompact: () -> Void

    /// Bind the router into the given secondary column (regular width). May be called before the column is
    /// on screen; the router materializes into it either way.
    let activateRegular: (TabSecondaryColumn) -> Void

    /// Re-request the passcode if the path contains passcode-protected destinations. Called when the user
    /// returns to a tab they had left (not on collapse/expand, and not when the tab merely re-appears). The
    /// protected screens stay in place behind the passcode prompt; cancelling the prompt removes them from
    /// the path.
    let reauthenticateProtectedDestinations: () -> Void

    /// Free the tab's materialized screens while it is inactive (memory warning). The next activation
    /// re-creates the screens from the path.
    let releaseMaterializedScreens: () -> Void
}
