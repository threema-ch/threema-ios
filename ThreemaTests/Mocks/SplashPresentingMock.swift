import Foundation
import UIKit
@testable import Threema

/// Records which screen `OnboardingCoordinator` asked for.
///
/// `SplashViewController` comes out of the `CreateID` storyboard, so this stands in for it via
/// `SplashPresenting`.
final class SplashPresentingMock: SplashPresenting {

    // MARK: - Recorded Calls

    enum Call: Equatable {
        case setRestoreButtonHidden(Bool)
        case showLicenseViewController
        case showWorkDataFetchFailedAlert
        case showPrivacyControls
        case setAcceptPrivacyPolicyValues(AcceptPrivacyPolicyVariant)
        case showRandomSeedViewController
        case showIDBackupQuestion
        case showIDExistsQuestion(identity: String)
        case showIdentityCreationError
        case cancelIDCreation
        case presentPageViewController
        case showRestoreIdentityViewController(backupData: String?, password: String?, hasError: Bool)
        case navigate
        case navigateBack
        case navigateToRestoreSafeViewController(identityOnly: Bool)
        case navigateToRestoreOptionDataViewController
        case navigateToRestoreOptionBackupViewController
        case navigateBackToRestoreOptionDataViewController
        case navigateBackToRestoreOptionBackupViewController
        case navigateBackToSplash
        case slideOutRestoreOptionBackupViewController
        case showLoadingHUD
        case hideLoadingHUD
    }

    private(set) var calls: [Call] = []

    /// The error handed to `showIdentityCreationError(_:)`, which `Call` cannot carry equatably.
    private(set) var identityCreationError: Error?

    /// The view controllers handed to `navigate(to:)` and `navigateBack(to:)`, in call order.
    private(set) var navigatedViewControllers: [UIViewController] = []

    func contains(_ call: Call) -> Bool {
        calls.contains(call)
    }

    // MARK: - SplashPresenting

    let viewController = UIViewController()

    var splashDelegate: (any SplashViewControllerDelegate)?

    func setRestoreButtonHidden(_ hidden: Bool) {
        calls.append(.setRestoreButtonHidden(hidden))
    }

    func showLicenseViewController() {
        calls.append(.showLicenseViewController)
    }

    func showWorkDataFetchFailedAlert() {
        calls.append(.showWorkDataFetchFailedAlert)
    }

    func showPrivacyControls() {
        calls.append(.showPrivacyControls)
    }

    func setAcceptPrivacyPolicyValues(_ variant: AcceptPrivacyPolicyVariant) {
        calls.append(.setAcceptPrivacyPolicyValues(variant))
    }

    func showRandomSeedViewController() {
        calls.append(.showRandomSeedViewController)
    }

    func showIDBackupQuestion() {
        calls.append(.showIDBackupQuestion)
    }

    func showIDExistsQuestion(for identity: String) {
        calls.append(.showIDExistsQuestion(identity: identity))
    }

    func showIdentityCreationError(_ error: Error) {
        identityCreationError = error
        calls.append(.showIdentityCreationError)
    }

    func cancelIDCreation() {
        calls.append(.cancelIDCreation)
    }

    func presentPageViewController(with setupConfiguration: SetupConfiguration) {
        calls.append(.presentPageViewController)
    }

    func showRestoreIdentityViewController(
        withBackupData backupData: String?,
        password: String?,
        error: Error?
    ) {
        calls.append(.showRestoreIdentityViewController(
            backupData: backupData,
            password: password,
            hasError: error != nil
        ))
    }

    func navigateToRestoreSafeViewController(identityOnly: Bool) {
        calls.append(.navigateToRestoreSafeViewController(identityOnly: identityOnly))
    }

    func navigateToRestoreOptionDataViewController() {
        calls.append(.navigateToRestoreOptionDataViewController)
    }

    func navigateToRestoreOptionBackupViewController() {
        calls.append(.navigateToRestoreOptionBackupViewController)
    }

    func navigateBackToRestoreOptionDataViewController() {
        calls.append(.navigateBackToRestoreOptionDataViewController)
    }

    func navigateBackToRestoreOptionBackupViewController() {
        calls.append(.navigateBackToRestoreOptionBackupViewController)
    }

    func navigateBackToSplash() {
        calls.append(.navigateBackToSplash)
    }

    func slideOutRestoreOptionBackupViewController() {
        calls.append(.slideOutRestoreOptionBackupViewController)
    }

    func navigate(to viewController: UIViewController) {
        navigatedViewControllers.append(viewController)
        calls.append(.navigate)
    }

    func navigateBack(to viewController: UIViewController) {
        navigatedViewControllers.append(viewController)
        calls.append(.navigateBack)
    }

    func showLoadingHUD() {
        calls.append(.showLoadingHUD)
    }

    func hideLoadingHUD() {
        calls.append(.hideLoadingHUD)
    }
}
