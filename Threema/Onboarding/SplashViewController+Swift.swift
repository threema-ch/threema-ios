import Foundation
import ThreemaFramework
import UIKit

extension UIViewController {
    /// The view controller currently visible on top of this view controller, e.g. the modally
    /// presented setup wizard, or `self` if nothing is presented.
    ///
    /// The splash view controller's own view is covered by the full screen setup wizard for the
    /// whole second half of onboarding. Progress HUDs added to it are invisible and alerts
    /// presented on it are dropped by UIKit, thus both have to go on the topmost view controller.
    var topmostPresentedViewController: UIViewController {
        var topmost: UIViewController = self

        while let presented = topmost.presentedViewController, !presented.isBeingDismissed {
            topmost = presented
        }

        return topmost
    }
}
