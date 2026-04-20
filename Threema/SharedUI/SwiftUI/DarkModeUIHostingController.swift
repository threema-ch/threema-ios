import SwiftUI
import UIKit

/// A `UIHostingController` subclass that automatically forces Dark Mode
/// for its SwiftUI content, regardless of the app's global `UIWindow`
/// appearance setting.
///
/// ## Purpose
/// In apps that globally force a light or dark interface style using
/// `window.overrideUserInterfaceStyle`, SwiftUI's `.preferredColorScheme`
/// may be ignored. `DarkModeUIHostingController` ensures that the hosted
/// SwiftUI view hierarchy is always rendered in Dark Mode by applying
/// `overrideUserInterfaceStyle = .dark` at the UIKit level.
///
final class DarkModeUIHostingController<Content: View>: UIHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        self.overrideUserInterfaceStyle = .dark
    }

    @objc dynamic required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.overrideUserInterfaceStyle = .dark
    }
}
