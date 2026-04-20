import SwiftUI
import UIKit

/// A SwiftUI wrapper that forces a specific interface style (e.g. Dark Mode)
/// for a view hierarchy, even when the app globally overrides the appearance
/// at the UIWindow level.
///
/// If the app sets: `window.overrideUserInterfaceStyle = .light`
/// then SwiftUI modifiers like `.preferredColorScheme(.dark)` are ignored.
///
/// This wrapper creates a new `UIHostingController` and applies:
/// `overrideUserInterfaceStyle = .dark`
/// at the UIKit level, which takes precedence over the window setting,
/// but only for its subtree.
struct DarkModeUIViewControllerRepresentable<Content: View>: UIViewControllerRepresentable {
    let rootView: Content

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let vc = UIHostingController(rootView: rootView)
        vc.overrideUserInterfaceStyle = .dark
        return vc
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        // no-op
    }
}
