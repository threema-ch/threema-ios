import ThreemaFramework
import UIKit

/// Dedicated window for call UI.
///
/// Shown when the call view is presented, hidden when the call is minimized (the call view is
/// dismissed but the call continues). The coordinator manages the window's visibility.
final class CallWindow: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)

        makeSecure(showsPreventionView: false)
        windowLevel = WindowLevel.call
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}
