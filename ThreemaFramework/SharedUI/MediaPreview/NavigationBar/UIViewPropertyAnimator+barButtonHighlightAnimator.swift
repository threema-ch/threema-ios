//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import UIKit

public extension UIViewPropertyAnimator {
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
    static func barButtonHighlightAnimator(for view: UIView) -> UIViewPropertyAnimator {
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
