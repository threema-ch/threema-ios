#if DEBUG

    import UIKit

    /// Empty scene delegate for previews, playgrounds & tests
    ///
    /// The previews & playgrounds infrastructure provides its own hosting window, thus we don't create one here.
    final class TestApplicationSceneDelegate: UIResponder, UIWindowSceneDelegate {
        var window: UIWindow?
    }

#endif
