import Foundation
import ThreemaFramework
import UIKit

// MARK: - SplashPresenting

/// The surface `OnboardingCoordinator` drives on `SplashViewController`.
///
/// `SplashViewController` is instantiated from the `CreateID` storyboard, so the coordinator cannot be
/// exercised against it in a unit test. Depending on this protocol instead lets tests inject a stub and
/// assert which screen the coordinator asked for.
///
/// Events travel the other way through `SplashViewControllerDelegate`.
protocol SplashPresenting: AnyObject {

    /// The presenter as a view controller, for the coordinator's `rootViewController` and as the owner of
    /// alerts and progress HUDs.
    var viewController: UIViewController { get }

    /// The delegate that receives events from the splash screen. Set by the coordinator so tests can
    /// inject a stub that both receives commands and triggers events back.
    var splashDelegate: (any SplashViewControllerDelegate)? { get set }

    // MARK: - Launch

    func setRestoreButtonHidden(_ hidden: Bool)
    func showLicenseViewController()
    func showWorkDataFetchFailedAlert()
    func showPrivacyControls()
    func setAcceptPrivacyPolicyValues(_ variant: AcceptPrivacyPolicyVariant)

    // MARK: - Setup

    func showRandomSeedViewController()
    func showIDBackupQuestion()
    func showIDExistsQuestion(for identity: String)
    func showIdentityCreationError(_ error: Error)
    func cancelIDCreation()
    func presentPageViewController(with setupConfiguration: SetupConfiguration)

    // MARK: - Restore

    func showRestoreIdentityViewController(
        withBackupData backupData: String?,
        password: String?,
        error: Error?
    )
    func navigate(to viewController: UIViewController)
    func navigateBack(to viewController: UIViewController)
    func navigateToRestoreSafeViewController(identityOnly: Bool)
    func navigateToRestoreOptionDataViewController()
    func navigateToRestoreOptionBackupViewController()
    func navigateBackToRestoreOptionDataViewController()
    func navigateBackToRestoreOptionBackupViewController()
    func navigateBackToSplash()
    func slideOutRestoreOptionBackupViewController()

    // MARK: - Progress

    func showLoadingHUD()
    func hideLoadingHUD()
}

// MARK: - SplashViewController + SplashPresenting

extension SplashViewController: SplashPresenting {
    var viewController: UIViewController {
        self
    }

    var splashDelegate: (any SplashViewControllerDelegate)? {
        get { self.delegate }
        set { self.delegate = newValue }
    }
}
