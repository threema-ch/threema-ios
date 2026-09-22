import Foundation
import MBProgressHUD
import UIKit

// MARK: - SafeRestorePresenting

/// The outcome of a Safe restore, as far as the screen that started it is concerned.
///
/// `OnboardingCoordinator` drives the restore and reports back through this, so it does not have to reach
/// into `RestoreSafeViewController`'s view for the progress indicator. That also keeps the restore
/// orchestration testable: `RestoreSafeViewController` comes from the `CreateID` storyboard.
@MainActor
protocol SafeRestorePresenting: AnyObject {

    /// Hides the progress indicator and re-enables interaction.
    func safeRestoreDidFinish()

    /// Reports the failure to the user. Also hides the progress indicator.
    func safeRestoreDidFail(with error: Error)
}

// MARK: - RestoreSafeViewController + SafeRestorePresenting

extension RestoreSafeViewController: SafeRestorePresenting {

    func safeRestoreDidFinish() {
        MBProgressHUD.hide(for: view, animated: true)
        view.isUserInteractionEnabled = true
    }

    func safeRestoreDidFail(with error: Error) {
        // `showAlert(for:)` already hides the progress indicator and re-enables interaction.
        showAlert(for: error)
    }
}
