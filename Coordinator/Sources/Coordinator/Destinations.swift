import Foundation
import UIKit

/// Destinations to be shown from anywhere in the app.
///
/// This is the vocabulary for *cross-surface* navigation (notifications, intents,
/// URLs, screens deep-linking into another tab). Per-tab path elements are the tab
/// coordinators' typed destination enums, erased to `AnyHashable` at this level;
/// each tab coordinator narrows them back to its own `Destination` type.
public enum Destination: Hashable {
    /// Show a tab, replacing its navigation stack with `path`.
    /// An empty path pops the tab to its root.
    case app(AppDestination, path: [AnyHashable])

    /// Each case represents one of our tabs.
    public enum AppDestination: Hashable {
        case contacts
        case conversations
        case profile
        case settings
    }
}

extension Destination {
    /// Show a tab at its root.
    public static func app(_ tab: AppDestination) -> Destination {
        .app(tab, path: [])
    }
}

/// Style describing how a view controller should be shown
public indirect enum CoordinatorNavigationStyle {
    case show
    case modal(style: UIModalPresentationStyle = .automatic, transition: UIModalTransitionStyle = .coverVertical)
    case passcode(style: CoordinatorNavigationStyle)
}
