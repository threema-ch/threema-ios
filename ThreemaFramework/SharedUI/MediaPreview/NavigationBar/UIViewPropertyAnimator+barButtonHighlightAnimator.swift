import UIKit

extension UIViewPropertyAnimator {
    /// Animator for `view` imitating the behavior of a highlighted `UIBarButtonItem`
    ///
    /// The animator changed the `alpha` of the passed view.
    ///
    /// If you override the `isHighlighted` property it should look like that:
    /// ```
    /// override var isHighlighted: Bool {
    ///     didSet {
    ///         guard isHighlighted != oldValue else {
    ///             return
    ///         }
    ///
    ///         highlightAnimator.pauseAnimation()
    ///         if isHighlighted {
    ///             highlightAnimator.isReversed = false
    ///             highlightAnimator.startAnimation()
    ///         } else {
    ///             highlightAnimator.isReversed = true
    ///             highlightAnimator.startAnimation()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The animator never gets destroyed (because `pausesOnCompletion` is set to `true`).
    ///         Call `stopAnimation(_:)` during the destruction of the view holding the
    ///         `UIViewPropertyAnimator` reference (e.g. in `deinit`)
    ///
    /// - Parameter view: View that the animation should be applied to
    /// - Returns: Animator to be called when a view is highlighted
    public static func barButtonHighlightAnimator(for view: UIView) -> UIViewPropertyAnimator {
        // Configuration defined by observation (last update iOS 14.2)
        let highlightAnimationDuration: TimeInterval = 0.1
        let highlightAlpha: CGFloat = 0.3
        
        let animator = UIViewPropertyAnimator(duration: highlightAnimationDuration, curve: .linear, animations: {
            view.alpha = highlightAlpha
        })
        
        // Ensures our animator never gets destroyed, thus we need to do it ourself during `deinit`
        animator.pausesOnCompletion = true
  
        return animator
    }
}
