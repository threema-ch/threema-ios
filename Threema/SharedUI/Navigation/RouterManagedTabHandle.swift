import UIKit

/// Bridge between `ThreemaSplitViewNavigationManager` and a tab coordinator whose
/// navigation is driven by a `NavigationRouter`.
///
/// The coordinator keeps its state as a value-typed path; the manager calls these
/// hooks on tab switches and collapse/expand transitions, and the coordinator
/// re-materializes its stack from the path.
@MainActor
struct RouterManagedTabHandle {

    /// Unbind the router: the tab became inactive or its rendering surface is
    /// about to be reused by another tab. Path data survives; materialized
    /// screens may be reused on the next activation. Leaving the tab also
    /// invalidates the authentication of its protected destinations, so the next
    /// activation calls ``reauthenticateProtectedDestinations``.
    let deactivate: () -> Void

    /// Bind the router to the tab's own navigation controller (collapsed width).
    let activateCompact: () -> Void

    /// Bind the router into the given secondary-column navigation controller
    /// (regular width). May be called before the controller is installed in the
    /// split view — the router materializes into it either way.
    let activateRegular: (UINavigationController) -> Void

    /// Re-request the passcode if the path contains passcode-protected
    /// destinations. Called when the user returns to a tab they had left, i.e.
    /// once per preceding ``deactivate`` (not on collapse/expand, and not when the
    /// tab merely re-appears). The protected screens stay in place behind the
    /// passcode prompt; cancelling the prompt removes them from the path.
    let reauthenticateProtectedDestinations: () -> Void

    /// Free the tab's materialized screens while it is inactive (memory
    /// warning). No-op for the active tab; the next activation re-creates the
    /// screens from the path.
    let releaseMaterializedScreens: () -> Void
}
