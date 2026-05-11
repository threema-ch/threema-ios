import CocoaLumberjackSwift
import Coordinator
import FileUtility
import Keychain
import MBProgressHUD
import RemoteSecretProtocol
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - OnboardingCoordinatorDelegate

protocol OnboardingCoordinatorDelegate: AnyObject {
    /// Called when onboarding is completed and the app should continue launch.
    /// - Parameters:
    ///   - coordinator: The onboarding coordinator
    ///   - appContainer: The dependency container with all app dependencies (created after identity setup)
    func onboardingDidComplete(_ coordinator: OnboardingCoordinator, appContainer: AppDependencyContainer)
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
    private let remoteSecretResolver: any RemoteSecretResolving
    
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

    private lazy var restoreSafeManager = OnboardingRestoreSafeManager()
    
    // MARK: - Initialization
    
    init(
        bootstrap: BootstrapContainer,
        delegate: OnboardingCoordinatorDelegate,
        window: UIWindow,
        remoteSecretResolver: any RemoteSecretResolving
    ) {
        self.bootstrap = bootstrap
        self.delegate = delegate
        self.window = window
        self.remoteSecretResolver = remoteSecretResolver
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
            splashViewController.navigateToRestoreSafeViewController(identityOnly: identityOnly)
                
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
        bootstrap.licenseStore.performUpdateWorkInfo()
        
        splashViewController.presentPageViewController(
            with: SetupConfiguration(mdm: bootstrap.bootstrapMDM.mdmSetup)
        )
    }
    
    // MARK: - Remote Secret
    
    /// Creates RS + Keychain using the injected `RemoteSecretResolving`. Handles `.needsFetch`
    /// by presenting the RS fetch UI on the coordinator's window.
    private func resolveRemoteSecret() async throws -> (
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) {
        let result = try await remoteSecretResolver.resolve()
        
        switch result {
        case let .ready(remoteSecretManager, keychainManager):
            return (remoteSecretManager, keychainManager)
            
        case .needsFetch:
            return try await performRemoteSecretFetch(resolver: remoteSecretResolver)
            
        case .encryptedDataDetected:
            showEncryptedDataDetected()
            throw RemoteSecretResolver.ResolverError.missingInfo
        }
    }
    
    /// Presents `RemoteSecretInitializeViewsManager` on the coordinator's window
    /// for RS fetch.
    private func performRemoteSecretFetch(
        resolver: any RemoteSecretResolving
    ) async throws -> (any RemoteSecretManagerProtocol, any KeychainManagerProtocol) {
        guard let window else {
            throw RemoteSecretResolver.ResolverError.missingInfo
        }
        
        let previousVC = window.rootViewController
        
        let navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        window.rootViewController = navigationController
        
        let viewsManager = RemoteSecretInitializeViewsManager(
            navigationController: navigationController,
            showDeleteAfterRetries: 0
        )
        
        let identity = bootstrap.bootstrapIdentityStore.store.identity
            .map { ThreemaIdentity($0) }
        
        let fetchedRSManager = try await viewsManager.start(
            identity: identity,
            onDelete: {
                try? KeychainManager.deleteAllItems()
                exit(0)
            },
            onCancel: { [window, previousVC] in
                window.rootViewController = previousVC
            }
        )
        
        window.rootViewController = previousVC
        
        let (remoteSecretManager, keychainManager) = try resolver.continueAfterFetch(
            remoteSecretManager: fetchedRSManager
        )
        return (remoteSecretManager, keychainManager)
    }
    
    /// Updates `FileUtility.shared` with the RS-aware decorator.
    /// Replaces the side-effect from `RemoteSecretProvider.remoteSecretManager` didSet.
    private func updateFileUtility(remoteSecretManager: any RemoteSecretManagerProtocol) {
        FileUtility.updateSharedInstance(with: FileUtilityRemoteSecretDecorator(
            wrapped: FileUtility(),
            remoteSecretManager: remoteSecretManager,
            whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
        ))
    }
    
    private func showEncryptedDataDetected() {
        guard let window else {
            return
        }
        let viewController = UIHostingController(rootView: RemoteSecretEncryptedDataView())
        let navigationController = UINavigationController(rootViewController: viewController)
        window.rootViewController = navigationController
    }
        
    // MARK: - Setup Flow
        
    private func handleSetupTapped() async {
        isSetupTriggered = true
            
        if bootstrapIdentityService.hasRemoteSecret {
            splashViewController.showRemoteSecretExistsQuestion()
            return
        }
        
        /// We only show the existing ID question if it's not a business app.
        if bootstrap.appLaunchManager.isBusinessApp == false,
           bootstrapIdentityService.hasExistingIdentity == true {
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
                splashViewController.navigateToRestoreOptionDataViewController()
            }
            else {
                splashViewController.navigateToRestoreOptionBackupViewController()
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
        guard bootstrap.appLaunchManager.isBusinessApp else {
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
        viewController.cancelIDCreation()
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didSelectRestoreOption option: RestoreOption
    ) {
        switch option {
        case .safe:
            viewController.navigateToRestoreSafeViewController(identityOnly: false)
        case .safeIdentityOnly:
            viewController.navigateToRestoreSafeViewController(identityOnly: true)
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
            viewController.navigateToRestoreOptionBackupViewController()
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
        // Only called from optionDataCancelled — always go back to splash
        viewController.navigateBackToSplash()
    }
    
    func splashViewControllerDidCancelRestoreOptionBackup(
        _ viewController: SplashViewController
    ) {
        if bootstrapIdentityService.hasDataOnDevice {
            viewController.navigateBackToRestoreOptionDataViewController()
        }
        else {
            viewController.navigateBackToSplash()
        }
    }
    
    func splashViewControllerDidCancelRestoreSafe(
        _ viewController: SplashViewController
    ) {
        // Always go back to RestoreOptionBackupVC (immediate predecessor)
        viewController.navigateBackToRestoreOptionBackupViewController()
    }
    
    func splashViewControllerDidCancelRestoreIdentity(
        _ viewController: SplashViewController
    ) {
        // If user came from restore flow, go back to RestoreOptionBackupVC.
        // If user came from setup flow (via ID backup question), go back to splash.
        if !isSetupTriggered {
            viewController.navigateBackToRestoreOptionBackupViewController()
        }
        else {
            viewController.navigateBackToSplash()
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

        do {
            let (remoteSecretManager, keychainManager) = try await resolveRemoteSecret()
            updateFileUtility(remoteSecretManager: remoteSecretManager)
            RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

            try await completeOnboarding(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager,
                setupConfiguration: setupConfiguration
            )

            MBProgressHUD.hide(for: rootViewController.view, animated: true)
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

    func splashViewController(
        _ viewController: SplashViewController,
        didRequestSafeRestore restoreSafeViewController: RestoreSafeViewController,
        identity: String,
        password: String
    ) {
        Task {
            await handleSafeRestore(
                info: OnboardingRestoreSafeInformation(
                    identity: identity,
                    password: password,
                    server: OnboardingRestoreSafeInformation.Server(
                        user: restoreSafeViewController.restoreServerUsername,
                        password: restoreSafeViewController.restoreSafePassword,
                        url: restoreSafeViewController.restoreServer
                    ),
                    customServer: OnboardingRestoreSafeInformation.Server(
                        user: restoreSafeViewController.restoreServerUsername,
                        password: restoreSafeViewController.restoreServerPassword,
                        url: restoreSafeViewController.restoreCustomServer
                    ),
                    restoreIdentityOnly: restoreSafeViewController.restoreIdentityOnly,
                    activateSafeAnyway: restoreSafeViewController.activateSafeAnyway
                ),
                from: restoreSafeViewController
            )
        }
    }
}

// MARK: - Safe Restore

extension OnboardingCoordinator {

    /// Orchestrates the two-phase safe restore and then completes onboarding.
    ///
    /// Phase 1 (`prepareRestore`) downloads the backup and restores the identity store.
    /// The coordinator then resolves RS using its own `resolveRemoteSecret()` — which
    /// handles `.needsFetch` UI — before handing the RS into phase 2 (`performRestore`).
    private func handleSafeRestore(
        info: OnboardingRestoreSafeInformation,
        from viewController: RestoreSafeViewController
    ) async {
        do {
            let logFile = LogManager.safeRestoreLogFile
            LogManager.deleteLogFile(logFile)
            LogManager.addFileLogger(logFile)
            
            // Phase 1: download backup + restore identity store
            let preparation = try await restoreSafeManager.prepareRestore(with: info)

            // Resolve RS via the coordinator's own resolver (handles all cases incl. .needsFetch)
            let (remoteSecretManager, keychainManager) = try await resolveRemoteSecret()
            updateFileUtility(remoteSecretManager: remoteSecretManager)
            RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

            // Phase 2: migrations + Safe restore + Safe activation
            try await restoreSafeManager.performRestore(
                preparation: preparation,
                remoteSecretManager: remoteSecretManager
            )
            
            LogManager.removeFileLogger(LogManager.safeRestoreLogFile)

            // Complete onboarding directly — safe restore already handled
            // migrations + Safe, so no setupConfiguration needed
            try await completeOnboarding(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            )
            
            MBProgressHUD.hide(for: viewController.view, animated: true)
            viewController.view.isUserInteractionEnabled = true
        }
        catch {
            MBProgressHUD.hide(for: viewController.view, animated: true)
            viewController.view.isUserInteractionEnabled = true
            viewController.showAlert(for: error)
        }
    }

    /// Shared completion path: given RS + keychain, run post-setup steps and finish onboarding.
    ///
    /// - Parameter setupConfiguration: When coming from the setup wizard, contains the user's
    ///   choices (nickname, email, phone, contacts, Safe password). When coming from safe restore,
    ///   pass `nil` — migrations and Safe activation were already handled by `performRestore`.
    private func completeOnboarding(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        setupConfiguration: SetupConfiguration? = nil
    ) async throws {
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

        let businessInjector = BusinessInjector(
            remoteSecretManager: remoteSecretManager
        )

        // Migrations — idempotent, safe to call even if already run by performRestore
        try await completionService.runMigrationsAndSetup(
            remoteSecretManager: remoteSecretManager,
            businessInjector: businessInjector
        )

        // Wizard-specific steps — only when coming from the setup wizard
        if let config = setupConfiguration {
            completionService.persistNickname(config.nickname)
            try await completionService.linkEmail(config.linkEmail)
            try await completionService.linkPhoneNumber(config.linkPhoneNumber)
            try await completionService.syncContacts(
                config.syncContacts,
                userSettings: businessInjector.userSettings
            )
            try await completionService.enableSafe(
                businessInjector: businessInjector,
                keychainManager: keychainManager,
                safePassword: config.safePassword,
                safeCustomServer: config.safeCustomServer,
                safeServerUsername: config.safeServerUsername,
                safeServerPassword: config.safeServerPassword,
                safeMaxBackupBytes: config.safeMaxBackupBytes,
                safeRetentionDays: config.safeRetentionDays
            )
        }

        try await bootstrap.appLaunchManager.runPostOnboardingSetup()

        let appContainer = AppDependencyContainer(
            businessInjector: businessInjector,
            remoteSecretManager: remoteSecretManager,
            keychainManager: keychainManager,
            bootstrap: bootstrap,
            wcSessionManager: WCSessionManagerAdapter()
        )
        delegate?.onboardingDidComplete(self, appContainer: appContainer)
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
