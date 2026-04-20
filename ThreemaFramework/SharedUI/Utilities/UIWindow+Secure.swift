import ObjectiveC
import SwiftUI
import UIKit

extension UIWindow {

    // MARK: - Private types

    private class SecureTextField: UITextField {
        override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
            UIScreen.main.bounds
        }
    }

    // MARK: - Private properties

    private static var isSecureKey: UInt8 = 0
    private static var observationKey: UInt8 = 1

    /// Tracks whether this specific window instance has already been secured.
    /// Using an associated object (rather than a static flag) ensures the state
    /// is tied to each `UIWindow` instance individually — so repeated calls on
    /// the same window are safely ignored, while a newly created replacement
    /// window starts unsecured and can be secured fresh.
    private var isSecure: Bool {
        get { objc_getAssociatedObject(self, &Self.isSecureKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.isSecureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Public methods

    @objc public func makeSecure() {
        guard TargetManager.isBusinessApp, MDMSetup().disableScreenshots(), !isSecure else {
            return
        }

        isSecure = true

        let field = SecureTextField()
        field.isSecureTextEntry = true

        let hostingController = UIHostingController(rootView: ScreenshotPreventionView())
        hostingController.view.backgroundColor = .clear

        field.leftView = hostingController.view
        field.leftViewMode = .always
        field.semanticContentAttribute = .forceLeftToRight

        addSubview(field)
        layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.last?.addSublayer(layer)

        /// layoutSubviews and bounds KVO on UIWindow are not reliably called on rotation
        /// in iOS 26+. Observing the scene's effectiveGeometry fires when the scene
        /// resizes/rotates and is the modern replacement.
        let observation = windowScene?.observe(\.effectiveGeometry) { [weak field] _, _ in
            field?.setNeedsLayout()
            field?.layoutIfNeeded()
        }
        objc_setAssociatedObject(self, &Self.observationKey, observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
