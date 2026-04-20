#if DEBUG

    import UIKit

    extension UIView {

        /// Adds a colored border and background to the view for debugging purposes.
        ///
        /// This method is useful during development to visualize view boundaries and layouts.
        /// It applies a semi-transparent border and background color to make the view's frame visible.
        ///
        /// - Parameter color: The base color to use for the border and background. Default is `.blue`.
        ///                    The border will be 50% opaque and the background 10% opaque.
        public func mark(color: UIColor = .blue) {
            layer.borderColor = color.withAlphaComponent(0.5).cgColor
            layer.borderWidth = 0.2
            backgroundColor = color.withAlphaComponent(0.1)
        }
    }
#endif
