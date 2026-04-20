import Foundation

// MARK: - SplashViewControllerDelegate

/// Delegate protocol for SplashViewController to communicate events to OnboardingCoordinator.
/// This allows the coordinator to control the onboarding flow while SplashViewController
/// handles UI presentation and navigation animations.
@objc
protocol SplashViewControllerDelegate: AnyObject {
    
    // MARK: - Lifecycle
    
    /// Called when the view controller has appeared and is ready for instructions.
    /// The coordinator should respond by calling appropriate methods on SplashViewController.
    func splashViewControllerDidAppear(_ viewController: SplashViewController)
    
    // MARK: - User Actions
    
    /// Called when user taps the "Setup" button to create a new identity.
    func splashViewControllerDidTapSetup(_ viewController: SplashViewController) async
    
    /// Called when user taps the "Restore" button to restore an existing identity.
    func splashViewControllerDidTapRestore(_ viewController: SplashViewController)
    
    // MARK: - Question Responses
    
    /// Called when user responds to the "ID backup found" question.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - useBackup: `true` if user wants to use the found backup, `false` to ignore it
    func splashViewController(_ viewController: SplashViewController, didAnswerIDBackupQuestion useBackup: Bool)
    
    /// Called when user responds to the "ID already exists" question.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - useExisting: `true` if user wants to use existing ID, `false` to create new
    func splashViewController(_ viewController: SplashViewController, didAnswerIDExistsQuestion useExisting: Bool)
    
    /// Called when user responds to the "Remote Secret exists" question.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - restore: `true` if user wants to restore, `false` to start fresh (deletes keychain)
    func splashViewController(_ viewController: SplashViewController, didAnswerRemoteSecretQuestion restore: Bool)
    
    // MARK: - Identity Creation
    
    /// Called when RandomSeedViewController has generated a random seed.
    /// The coordinator should proceed with identity creation.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - seed: The generated random seed data
    func splashViewController(_ viewController: SplashViewController, didGenerateRandomSeed seed: Data)
    
    /// Called when user cancels identity creation (backs out of RandomSeedViewController).
    func splashViewControllerDidCancelIDCreation(_ viewController: SplashViewController)
    
    // MARK: - Restore Flow
    
    /// Called when a restore option is selected.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - option: The selected restore option
    func splashViewController(_ viewController: SplashViewController, didSelectRestoreOption option: RestoreOption)
    
    /// Called when restore flow completes successfully.
    func splashViewControllerDidCompleteRestore(_ viewController: SplashViewController)
    
    /// Called when user cancels the restore flow.
    func splashViewControllerDidCancelRestore(_ viewController: SplashViewController)
    
    // MARK: - License (Business/OnPrem)
    
    /// Called when license entry is confirmed.
    func splashViewControllerDidConfirmLicense(_ viewController: SplashViewController)
    
    // MARK: - Completion
    
    /// Called when the entire onboarding/ID setup flow has completed.
    /// - Parameters:
    ///   - viewController: The SplashViewController
    ///   - setupConfiguration: The setup configuration with user's choices
    func splashViewController(
        _ viewController: SplashViewController,
        didCompleteIDSetupWith setupConfiguration: SetupConfiguration
    ) async
}

// MARK: - RestoreOption

/// Options for restoring an identity.
@objc
enum RestoreOption: Int {
    /// Restore from Threema Safe (full restore)
    case safe
    /// Restore identity only from Threema Safe
    case safeIdentityOnly
    /// Restore from ID backup string
    case idBackup
    /// Keep local data and restore identity
    case keepLocalData
}
