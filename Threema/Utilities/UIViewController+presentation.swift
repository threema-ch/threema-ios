import Foundation

extension UIViewController {
    /// This view controller is the root view of a modally presented navigation controller
    var isPresentedInModalAndRootView: Bool {
        presentingViewController != nil &&
            navigationController?.viewControllers.first == self
    }

    /// Determines whether the view controller should be presented in a popover.
    ///
    /// Returns `true` when:
    /// - The horizontal size class is `.regular`, and
    /// - The controller is not a `UIImagePickerController`, or
    /// - The controller is a `UIImagePickerController` with `sourceType == .photoLibrary`.
    ///
    /// Returns `false` for compact horizontal size classes, or when
    /// the controller is a `UIImagePickerController` using a different source type.
    ///
    /// Use this method before configuring `modalPresentationStyle` to `.popover`.
    ///
    /// - Returns: A Boolean value indicating whether the controller
    ///   should be presented as a popover.
    func shouldPresentInPopover() -> Bool {
        if traitCollection.horizontalSizeClass == .regular {
            if let picker = self as? UIImagePickerController {
                return picker.sourceType == .photoLibrary
            }
            return true
        }
        return false
    }
}
