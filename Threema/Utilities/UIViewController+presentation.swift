import Foundation

extension UIViewController {
    /// This view controller is the root view of a modally presented navigation controller
    var isPresentedInModalAndRootView: Bool {
        presentingViewController != nil &&
            navigationController?.viewControllers.first == self
    }
}
