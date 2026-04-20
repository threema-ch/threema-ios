import CocoaLumberjackSwift
import Coordinator
import Keychain
import MBProgressHUD
import RemoteSecretProtocol
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - OnboardingCoordinatorDelegate

protocol OnboardingCoordinatorDelegate: AnyObject {
    /// Called when onboarding is completed and the app should continue launch.
    /// - Parameters:
    ///   - coordinator: The onboarding coordinator
    ///   - businessInjector: The business injector with all app dependencies (created after identity setup)
    func onboardingDidComplete(_ coordinator: OnboardingCoordinator, businessInjector: BusinessInjectorProtocol)
}

// MARK: - OnboardingCoordinator

final class OnboardingCoordinator: Coordinator {
    
    // MARK: - Coordinator Protocol
    
    var childCoordinators: [any Coordinator] = []
    
    var rootViewController: UIViewController {
        splashViewController
    }
    
    private lazy var splashViewController: SplashViewController = {
        guard
            let splashViewController = UIStoryboard(
                name: "CreateID",
                bundle: .main
            ).instantiateInitialViewController() as? SplashViewController
        else {
            fatalError("Failed to instantiate initial view controller from CreateID storyboard")
        }
        
        splashViewController.delegate = self
        
        return splashViewController
    }()
    
    // MARK: - Properties
    
    let bootstrap: BootstrapContainer
    weak var delegate: OnboardingCoordinatorDelegate?
    weak var window: UIWindow?
    
    private(set) lazy var bootstrapLicenseService = BootstrapLicenseService(
        licenseStore: bootstrap.licenseStore,
        appLaunchManager: bootstrap.appLaunchManager
    )

    private(set) lazy var bootstrapIdentityService = BootstrapIdentityService(
        bootstrapIdentityStore: bootstrap.bootstrapIdentityStore,
        bootstrapIdentityCreator: bootstrap.bootstrapIdentityCreator,
        bootstrapKeychainManager: bootstrap.bootstrapKeychainManager,
        bootstrapBackupStore: bootstrap.bootstrapBackupStore,
        appLaunchManager: bootstrap.appLaunchManager
    )

    private var foundIDBackup: String?
    private var isSetupTriggered = false
    
    // MARK: - Initialization
    
    init(
        bootstrap: BootstrapContainer,
        delegate: OnboardingCoordinatorDelegate,
        window: UIWindow
    ) {
        self.bootstrap = bootstrap
        self.delegate = delegate
        self.window = window
    }
    
    // MARK: - Coordinator Lifecycle
    
    func start() {
        window?.rootViewController = rootViewController
    }
    
    // MARK: - Flow Control
        
    private func beginBusinessOnboardingFlow() async throws {
        guard
            bootstrap.appLaunchManager.isBusinessApp,
            await bootstrapLicenseService.checkLicense()
        else {
            return
        }
            
        try await proceedAfterLicenseValidation()
    }
        
    private func proceedAfterLicenseValidation() async throws {
        try await bootstrap.bootstrapWorkDataFetcher.checkUpdateThreemaMDM()
            
        // Reload MDM values after fetch
        bootstrap.bootstrapMDM.loadIDCreationValues()
        bootstrap.bootstrapMDM.loadRenewableValues()
            
        let flow = mdmFlow(
            hasDataOnDevice: bootstrapIdentityService.hasDataOnDevice
        )
            
        await handleMDMFlow(flow)
    }
    
    private func handleMDMFlow(_ flow: MDMFlow) async {
        switch flow {
        case let .forceSafeRestore(identityOnly):
            splashViewController.showRestoreSafeViewController(identityOnly)
                
        case .restoreFromMDMBackup:
            await restoreFromMDMBackup()
                
        case .directSetupWizard:
            await proceedToSetupWizard()
                
        case .showPrivacyControls:
            splashViewController.showPrivacyControls()
        }
    }
        
    private func restoreFromMDMBackup() async {
        splashViewController.setAcceptPrivacyPolicyValues(.implicitly)
        
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
                
            do {
                try await bootstrap.bootstrapMDM.restoreIDBackup()
                await proceedToSetupWizard()
            }
            catch {
                DDLogError("MDM backup restore failed: \(error)")
                
                splashViewController.showRestoreIdentityViewController(
                    withBackupData: bootstrap.bootstrapMDM.idBackup,
                    password: bootstrap.bootstrapMDM.idBackupPassword,
                    error: error
                )
            }
        }
    }
        
    private func proceedToSetupWizard() async {
        let setupApp = SetupApp(
            delegate: splashViewController,
            licenseStore: bootstrap.licenseStore.store,
            myIdentityStore: bootstrap.bootstrapIdentityStore.store,
            mdmSetup: MDMSetup(),
            hasPreexistingData: bootstrapIdentityService.hasDataOnDevice
        )
            
        do {
            guard let remoteSecretAndKeychain
                = try await setupApp.setupRemoteSecretAndKeychain() else {
                // TODO: RootCoordinator: We need to handle this better
                return
            }
                
            bootstrap.licenseStore.performUpdateWorkInfo()
                
            splashViewController.presentPageViewController(
                with: SetupConfiguration(
                    remoteSecretAndKeychain: remoteSecretAndKeychain,
                    mdm: bootstrap.bootstrapMDM.mdmSetup
                )
            )
        }
        catch {
            DDLogError("Failed to setup remote secret and keychain: \(error)")
            showFatalError(message: #localize("new_identity_creation_error_message"))
        }
    }
        
    private func showFatalError(message: String) {
        UIAlertTemplate.showAlert(
            owner: splashViewController,
            title: #localize("new_identity_creation_error_title"),
            message: message,
            actionOk: { _ in
                exit(EXIT_FAILURE)
            }
        )
    }
        
    // MARK: - Setup Flow
        
    private func handleSetupTapped() async {
        isSetupTriggered = true
            
        if bootstrapIdentityService.hasRemoteSecret {
            splashViewController.showRemoteSecretExistsQuestion()
            return
        }
        
        let isBusinessApp = bootstrap.appLaunchManager.isBusinessApp
        if isBusinessApp ||
            (isBusinessApp == false && bootstrapIdentityService.hasExistingIdentity) {
            splashViewController.showIDExistsQuestion()
            return
        }
        
        if let backup = bootstrapIdentityService.checkForIDBackup() {
            foundIDBackup = backup
            splashViewController.showIDBackupQuestion()
            return
        }
        
        await showSetupViewController()
    }
        
    private func showSetupViewController() async {
        splashViewController.setAcceptPrivacyPolicyValues(.explicitly)
        splashViewController.showRandomSeedViewController()
    }
        
    // MARK: - Restore Flow
        
    private func handleRestoreTapped() async {
        isSetupTriggered = false
            
        if bootstrap.bootstrapMDM.isSafeRestoreDisabled {
            if let backup = bootstrapIdentityService.checkForIDBackup() {
                foundIDBackup = backup
                splashViewController.showIDBackupQuestion()
                return
            }
                
            splashViewController.showRestoreIdentityViewController(
                withBackupData: nil,
                password: nil,
                error: nil
            )
        }
        else {
            if bootstrapIdentityService.hasDataOnDevice {
                splashViewController.showRestoreOptionDataViewController()
            }
            else {
                splashViewController.showRestoreOptionBackupViewController()
            }
        }
    }
        
    // MARK: - Identity Creation
        
    private func createIdentity(with seed: Data) async {
        splashViewController.showLoadingHUD()
            
        bootstrapIdentityService.generateKeyPair(from: seed)
            
        let result = await bootstrapIdentityService.createIdentity()
            
        switch result {
        case .success:
            await proceedToSetupWizard()
                
        case let .failure(error):
            splashViewController.hideLoadingHUD()
            splashViewController.showIdentityCreationError(error)
        }
    }
}

// MARK: - SplashViewControllerDelegate

extension OnboardingCoordinator: SplashViewControllerDelegate {
    func splashViewControllerDidAppear(_ viewController: SplashViewController) {
        guard TargetManager.isBusinessApp else {
            return
        }
        
        // Load MDM configuration
        bootstrap.bootstrapMDM.loadIDCreationValues()
        bootstrap.bootstrapMDM.loadRenewableValues()
        
        Task {
            try await beginBusinessOnboardingFlow()
        }
    }
        
    func splashViewControllerDidTapSetup(
        _ viewController: SplashViewController
    ) async {
        await handleSetupTapped()
    }
        
    func splashViewControllerDidTapRestore(
        _ viewController: SplashViewController
    ) {
        Task {
            await handleRestoreTapped()
        }
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didAnswerIDBackupQuestion useBackup: Bool
    ) {
        if useBackup, let backup = foundIDBackup {
            viewController.showRestoreIdentityViewController(
                withBackupData: backup,
                password: nil,
                error: nil
            )
        }
        else if isSetupTriggered {
            Task {
                await showSetupViewController()
            }
        }
        else {
            viewController.showRestoreIdentityViewController(
                withBackupData: nil,
                password: nil,
                error: nil
            )
        }
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didAnswerIDExistsQuestion useExisting: Bool
    ) {
        if useExisting {
            // Use existing identity
            Task {
                await proceedToSetupWizard()
            }
        }
        else {
            // Delete keychain and create new
            bootstrapIdentityService.deleteAllKeychainItems()
            Task {
                await showSetupViewController()
            }
        }
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didAnswerRemoteSecretQuestion restore: Bool
    ) {
        if restore {
            /// User wants to restore. Show restore options.
            Task {
                await handleRestoreTapped()
            }
        }
        else {
            /// User wants fresh start. Delete keychain.
            bootstrapIdentityService.deleteAllKeychainItems()
            Task {
                await showSetupViewController()
            }
        }
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didGenerateRandomSeed seed: Data
    ) {
        Task {
            await createIdentity(with: seed)
        }
    }
        
    func splashViewControllerDidCancelIDCreation(
        _ viewController: SplashViewController
    ) {
        viewController.showPrivacyControls()
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didSelectRestoreOption option: RestoreOption
    ) {
        switch option {
        case .safe:
            viewController.showRestoreSafeViewController(false)
        case .safeIdentityOnly:
            viewController.showRestoreSafeViewController(true)
        case .idBackup:
            if let backup = bootstrapIdentityService.checkForIDBackup() {
                foundIDBackup = backup
                viewController.showIDBackupQuestion()
            }
            else {
                viewController.showRestoreIdentityViewController(
                    withBackupData: nil,
                    password: nil,
                    error: nil
                )
            }
        case .keepLocalData:
            viewController.showRestoreOptionBackupViewController()
        }
    }
        
    func splashViewControllerDidCompleteRestore(
        _ viewController: SplashViewController
    ) {
        Task {
            await proceedToSetupWizard()
        }
    }
        
    func splashViewControllerDidCancelRestore(
        _ viewController: SplashViewController
    ) {
        if bootstrapIdentityService.hasDataOnDevice {
            viewController.showRestoreOptionDataViewController()
        }
        else {
            viewController.showPrivacyControls()
        }
    }
        
    func splashViewControllerDidConfirmLicense(
        _ viewController: SplashViewController
    ) {
        Task {
            try await proceedAfterLicenseValidation()
        }
    }
    
    func splashViewController(
        _ viewController: SplashViewController,
        didCompleteIDSetupWith setupConfiguration: SetupConfiguration
    ) async {
        MBProgressHUD.showAdded(to: rootViewController.view, animated: true)
        
        // Extract RemoteSecret and Keychain from ObjC bridge (avoid passing bridge object further)
        let remoteSecretManager = setupConfiguration.remoteSecretAndKeychain.remoteSecretManager
        let keychainManager = setupConfiguration.remoteSecretAndKeychain.keychainManager
        
        do {
            let completionService = OnboardingCompletionService(
                bootstrapIdentityStore: bootstrap.bootstrapIdentityStore,
                licenseStore: bootstrap.licenseStore,
                bootstrapUserSettings: bootstrap.bootstrapUserSettings,
                bootstrapContactStore: bootstrap.bootstrapContactStore,
                bootstrapServerAPI: bootstrap.bootstrapServerAPI,
                bootstrapPhoneNumberNormalizer: bootstrap.bootstrapPhoneNumberNormalizer,
                bootstrapMDM: bootstrap.bootstrapMDM,
                safeComponentsFactory: LiveSafeComponentsFactory()
            )
            
            // Run migrations and setup - this sets AppSetup.state = .identitySetupComplete
            try await completionService.runMigrationsAndSetup(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            )
            
            // After migrations, BusinessInjector can be safely created
            let businessInjector = BusinessInjector(
                remoteSecretManager: remoteSecretManager
            )
            
            completionService.persistNickname(setupConfiguration.nickname)
            
            try await completionService.linkEmail(setupConfiguration.linkEmail)
            try await completionService.linkPhoneNumber(setupConfiguration.linkPhoneNumber)
            
            try await completionService.syncContacts(
                setupConfiguration.syncContacts,
                userSettings: businessInjector.userSettings
            )
            
            // Enable Threema Safe if configured (needs BusinessInjector for GroupManager and KeychainManager)
            try await completionService.enableSafe(
                businessInjector: businessInjector,
                keychainManager: keychainManager,
                safePassword: setupConfiguration.safePassword,
                safeCustomServer: setupConfiguration.safeCustomServer,
                safeServerUsername: setupConfiguration.safeServerUsername,
                safeServerPassword: setupConfiguration.safeServerPassword,
                safeMaxBackupBytes: setupConfiguration.safeMaxBackupBytes,
                safeRetentionDays: setupConfiguration.safeRetentionDays
            )
            
            try await bootstrap.appLaunchManager.runPostOnboardingSetup()
            
            // Brief delay to show completion feedback (like old flow)
            try? await Task.sleep(for: .milliseconds(500))
            
            MBProgressHUD.hide(for: rootViewController.view, animated: true)
            
            // Pass BusinessInjector to delegate so it can create AppContainer and transition to .ready
            delegate?.onboardingDidComplete(self, businessInjector: businessInjector)
        }
        catch {
            MBProgressHUD.hide(for: rootViewController.view, animated: true)
            
            UIAlertTemplate.showAlert(
                owner: rootViewController,
                title: #localize("app_setup_steps_failed_title"),
                message: #localize("app_setup_steps_failed_message"),
                titleOk: #localize("try_again"),
                actionOk: { [weak self, viewController, setupConfiguration] _ in
                    Task { @MainActor in
                        await self?.splashViewController(
                            viewController,
                            didCompleteIDSetupWith: setupConfiguration
                        )
                    }
                }
            )
        }
    }
}

// MARK: - MDM Bootstrap Flow Decision

extension OnboardingCoordinator {
    /// Determines the initial onboarding flow based on MDM configuration.
    enum MDMFlow {
        /// Force Safe restore (MDM configured)
        case forceSafeRestore(identityOnly: Bool)
        
        /// Restore from MDM ID backup
        case restoreFromMDMBackup
        
        /// Show setup wizard directly
        case directSetupWizard
        
        /// Show normal privacy/setup controls
        case showPrivacyControls
    }
    
    /// Determines what flow to show based on MDM configuration and app state.
    /// - Parameter hasDataOnDevice: Whether there's existing data on device
    /// - Returns: The initial flow to present
    func mdmFlow(hasDataOnDevice: Bool) -> MDMFlow {
        if bootstrap.bootstrapMDM.isSafeRestoreForced {
            return .forceSafeRestore(identityOnly: hasDataOnDevice)
        }
        
        if bootstrap.bootstrapMDM.hasIDBackup,
           bootstrap.appLaunchManager.isAppSetupCompleted == false {
            return .restoreFromMDMBackup
        }
        
        if bootstrap.appLaunchManager.shouldDirectlyShowSetupWizard {
            return .directSetupWizard
        }
        
        return .showPrivacyControls
    }
}
