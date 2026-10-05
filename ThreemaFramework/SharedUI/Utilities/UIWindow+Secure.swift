import ObjectiveC
import SwiftUI
import UIKit

extension UIWindow {

    // MARK: - Types

    private class SecureTextField: UITextField {
        override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
            UIScreen.main.bounds
        }
    }

    /// Keeps a window alive until every view it is attached to has finished deallocating.
    ///
    /// Views of the secure field can outlive `removeSecure()`: the running Core Animation transaction retains
    /// detached layer trees until it commits, and those release their views in the commit's autorelease pool. Their
    /// deallocation still reaches the window (e.g. `_UIHostingView.deinit`), so the window must outlive them.
    ///
    /// Attached as associated object, which is released only after the owning view's `dealloc` has run.
    final class WindowLifetime {
        let window: UIWindow

        init(_ window: UIWindow) {
            self.window = window
        }

        deinit {
            // This runs inside the last view's deallocation, possibly in the middle of a transaction commit.
            // Deallocating the window there is not something UIKit expects, so release it on a later turn.
            let window = window
            DispatchQueue.main.async {
                withExtendedLifetime(window) { }
            }
        }
    }

    // MARK: - Private properties

    private static var isSecureKey: UInt8 = 0
    private static var observationKey: UInt8 = 1
    private static var secureFieldKey: UInt8 = 2
    private static var windowLifetimeKey: UInt8 = 3

    /// Tracks whether this specific window instance has already been secured.
    /// Using an associated object (rather than a static flag) ensures the state
    /// is tied to each `UIWindow` instance individually — so repeated calls on
    /// the same window are safely ignored, while a newly created replacement
    /// window starts unsecured and can be secured fresh.
    private var isSecure: Bool {
        get { objc_getAssociatedObject(self, &Self.isSecureKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.isSecureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The secure text field added by `makeSecure(showsPreventionView:)`, needed to revert it in `removeSecure()`.
    var secureField: UITextField? {
        get { objc_getAssociatedObject(self, &Self.secureFieldKey) as? UITextField }
        set { objc_setAssociatedObject(self, &Self.secureFieldKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Internal methods

    /// The lifetime `removeSecure()` attached to `view`, if any.
    static func windowLifetime(of view: UIView) -> WindowLifetime? {
        objc_getAssociatedObject(view, &windowLifetimeKey) as? WindowLifetime
    }

    // MARK: - Public methods

    @objc public func makeSecure() {
        makeSecure(showsPreventionView: true)
    }

    /// Excludes this window's content from screenshots and recordings.
    ///
    /// - Parameter showsPreventionView: Whether to show the "screen capture disabled" message in captures. Pass
    ///   `false` when stacked over a secured window, its message covers us and ours would show through where our
    ///   content is transparent.
    public func makeSecure(showsPreventionView: Bool) {
        guard TargetManager.isBusinessApp, MDMSetup().disableScreenshots() else {
            return
        }

        installSecureField(showsPreventionView: showsPreventionView)
    }

    /// `makeSecure(showsPreventionView:)` without the MDM check.
    func installSecureField(showsPreventionView: Bool) {
        guard !isSecure else {
            return
        }

        isSecure = true

        let field = SecureTextField()
        field.isSecureTextEntry = true

        if showsPreventionView {
            let hostingController = UIHostingController(rootView: ScreenshotPreventionView())
            hostingController.view.backgroundColor = .clear

            field.leftView = hostingController.view
            field.leftViewMode = .always
        }

        field.semanticContentAttribute = .forceLeftToRight
        secureField = field

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

    /// Reverts `makeSecure(showsPreventionView:)`. Call before releasing a secured window.
    ///
    /// `makeSecure(showsPreventionView:)` re-parents the window's layer into the field's secure container while the
    /// field stays a subview of the window. Dropped in that state, the window leaves the field with a dangling
    /// `superview`. Reverting the layer surgery alone is not enough: the field and its subviews (like the hosting view
    /// of `ScreenshotPreventionView`) may still be deallocated after the window, see `WindowLifetime`.
    public func removeSecure() {
        guard isSecure, let field = secureField else {
            return
        }

        objc_setAssociatedObject(self, &Self.observationKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Restore the layer tree to what `addSubview(field)` created, so UIKit detaches a regular subview
        if let rootLayer = field.layer.superlayer, rootLayer !== layer {
            rootLayer.insertSublayer(layer, above: field.layer)
        }
        else {
            layer.removeFromSuperlayer()
        }
        layer.addSublayer(field.layer)

        // Every view that was part of this window through the field keeps the window alive until it is gone
        let lifetime = WindowLifetime(self)
        func retainWindow(in view: UIView) {
            objc_setAssociatedObject(view, &Self.windowLifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // `subviews` follows the layer tree, which listed this window inside the field. Following it here would
            // attach the lifetime to the window itself, a retain cycle that leaks the window.
            view.subviews.filter { $0.superview === view && $0 !== self }.forEach(retainWindow(in:))
        }
        retainWindow(in: field)
        // May not be a subview yet if the field was never laid out
        if let leftView = field.leftView {
            retainWindow(in: leftView)
        }

        field.removeFromSuperview()

        secureField = nil
        isSecure = false
    }
}
