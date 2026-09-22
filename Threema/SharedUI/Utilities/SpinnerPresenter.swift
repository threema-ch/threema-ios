import MBProgressHUD
import UIKit

@MainActor
enum SpinnerPresenter {
    static func presentSpinner<T>(
        label: String,
        window: UIWindow?,
        while action: () throws -> T
    ) async throws -> T {
        guard let window else {
            fatalError("No window to present UI on")
        }

        let progressHUD = MBProgressHUD(view: window)
        progressHUD.label.numberOfLines = 0
        progressHUD.label.text = String(format: label, TargetManager.appName)
        progressHUD.mode = .indeterminate

        window.addSubview(progressHUD)
        progressHUD.show(animated: true)

        UIApplication.shared.isIdleTimerDisabled = true
        try await Task.sleep(seconds: 0.3)

        let result = try action()

        progressHUD.hide(animated: true)
        progressHUD.removeFromSuperview()

        UIApplication.shared.isIdleTimerDisabled = false
        return result
    }

    /// Shows an indeterminate spinner on top of `view` while the asynchronous `action` runs.
    ///
    /// Use this instead of `presentSpinner(label:window:while:)` if the work is asynchronous or if
    /// the spinner belongs to a specific view instead of the window. Note that the view has to be
    /// the one that is actually visible: a spinner added to the view of a view controller that is
    /// covered by a presented view controller (such as the onboarding wizard) never shows up.
    static func presentSpinner<T>(
        in view: UIView,
        while action: () async throws -> T
    ) async throws -> T {
        let progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
        progressHUD.mode = .indeterminate

        defer {
            progressHUD.hide(animated: true)
        }

        return try await action()
    }
}
