import CocoaLumberjackSwift
import Coordinator
import DataBackup
import FileUtility
import GroupCalls
import Keychain
import MBProgressHUD
import PushKit
import RemoteSecret
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
        splash.viewController
    }

    private let splash: any SplashPresenting

    private static func makeSplashViewController() -> SplashViewController {
        guard
            let splashViewController = UIStoryboard(
                name: "CreateID",
                bundle: .main
            ).instantiateInitialViewController() as? SplashViewController
        else {
            fatalError("Failed to instantiate initial view controller from CreateID storyboard")
        }

        return splashViewController
    }
    
    // MARK: - Properties
    
    let bootstrap: BootstrapContainer
    let bootstrapMDMSetup: any BootstrapMDMSetupProtocol
    weak var delegate: OnboardingCoordinatorDelegate?
    weak var window: UIWindow?
    private let remoteSecretResolver: any RemoteSecretResolving

    private(set) lazy var licenseService = LicenseService(
        licenseStore: bootstrap.licenseStore,
        flavorService: bootstrap.flavorService,
        licenseMDMSetup: bootstrapMDMSetup.mdmSetup,
        credentialsLoader: KeychainLicenseCredentialsLoader()
    )

    private let onboardingCompleter: any OnboardingCompleting

    private(set) lazy var bootstrapIdentityService = BootstrapIdentityService(
        bootstrapIdentityStore: bootstrap.bootstrapIdentityStore,
        bootstrapIdentityCreator: bootstrap.bootstrapIdentityCreator,
        bootstrapKeychainManager: bootstrap.bootstrapKeychainManager,
        bootstrapBackupStore: bootstrap.bootstrapBackupStore,
        appLaunchManager: bootstrap.appLaunchManager
    )

    private var foundIDBackup: String?
    private var isSetupTriggered = false

    /// `viewDidAppear` fires again every time a child view slides back to the splash screen and after a
    /// modal (e.g. the license entry) is dismissed, so the flow must only be started once.
    private var didStartOnboardingFlow = false

    /// Set as soon as the flow moved past the license step, so a license activation link arriving
    /// later (e.g. while the setup wizard is shown) doesn't restart the flow.
    private var didValidateLicense = false

    /// Error message for a license activation link that couldn't be used. Shown on the license entry
    /// screen as soon as it is presented, so the user learns why the link didn't work.
    private var licenseLinkErrorMessage: String?

    private let restoreSafeManager: any SafeRestoring
    
    private enum SafeRestoreOrigin {
        case restoreOptionBackup
        case restoreOptions
    }

    private var safeRestoreOrigin: SafeRestoreOrigin = .restoreOptionBackup

    private lazy var restoreLocalBackupManager = OnboardingRestoreLocalBackupManager()

    /// Kept alive while the local backup picker is on screen: `UIDocumentPickerViewController` holds its delegate
    /// weakly.
    private var localBackupFilePicker: LocalBackupFilePicker?

    // MARK: - Initialization
    
    init(
        bootstrap: BootstrapContainer,
        bootstrapMDMSetup: any BootstrapMDMSetupProtocol,
        delegate: OnboardingCoordinatorDelegate,
        window: UIWindow,
        remoteSecretResolver: any RemoteSecretResolving,
        splash: (any SplashPresenting)? = nil,
        onboardingCompleter: (any OnboardingCompleting)? = nil,
        restoreSafeManager: (any SafeRestoring)? = nil
    ) {
        self.bootstrap = bootstrap
        self.bootstrapMDMSetup = bootstrapMDMSetup
        self.delegate = delegate
        self.window = window
        self.remoteSecretResolver = remoteSecretResolver
        self.onboardingCompleter = onboardingCompleter ?? OnboardingCompleter(bootstrap: bootstrap)
        self.restoreSafeManager = restoreSafeManager ?? OnboardingRestoreSafeManager()
        self.splash = splash ?? Self.makeSplashViewController()
        self.splash.splashDelegate = self
    }
    
    // MARK: - Coordinator Lifecycle
    
    func start() {
        window?.rootViewController = rootViewController
    }
    
    // MARK: - Flow Control
        
    /// Entry point of the onboarding flow, driven by `splashViewControllerDidAppear(_:)`.
    ///
    /// Both `LicenseService.validate()` and `checkUpdateThreemaMDM()` are no-ops for
    /// non-business flavors, so the MDM flow decision runs for every flavor. Gating the whole sequence on
    /// `isBusinessApp` would skip `AppSetup.shouldDirectlyShowSetupWizard` for consumer builds that resume
    /// an interrupted setup.
    private func beginOnboardingFlow() async {
        bootstrapMDMSetup.loadIDCreationValues()
        bootstrapMDMSetup.loadRenewableValues()

        // After MDM and after a license activation link was handed over by `RootCoordinator`: both
        // are already in the license store and win over the credentials of a previous installation.
        licenseService.restoreStoredCredentials()

        await validateLicenseAndContinue()
    }

    /// Validates the license and either continues the onboarding flow or presents the license entry
    /// screen
    private func validateLicenseAndContinue() async {
        switch await licenseService.validate() {
        case .licensed:
            await continueAfterLicenseValidation()

        case .notLicensed:
            // Present anyway, to also fail early if there is no network connection
            showLicenseEntry()

        case .alreadyValidating:
            // Only reachable from `handleLicenseURL(query:)`, and only for credentials that were
            // stored successfully: `LicenseService.validate()` repeats its check for them and the
            // caller that started it — `beginOnboardingFlow()` or an earlier license link — acts on
            // the result, so the flow continues there.
            DDLogNotice(
                "[OnboardingCoordinator] A validation is already running. It covers the new credentials and continues the flow."
            )
        }
    }

    // MARK: - License Activation Link

    /// Applies the credentials of a license activation link (`<scheme>://license?…`) and validates
    /// them.
    ///
    /// Routed here by ``RootCoordinator``, because license links must also work while onboarding is
    /// running. If the link is received before the flow started (cold launch through a license
    /// link), storing the credentials is enough: the license check of ``beginOnboardingFlow()``
    /// picks them up and the license entry screen is never shown.
    func handleLicenseURL(query: [String: String]) {
        let applyResult = licenseService.apply(LicenseCredentials(query: query))

        if applyResult == .invalidServer {
            licenseLinkErrorMessage = #localize("enter_license_invalid_url_link")
        }

        guard didStartOnboardingFlow else {
            // The license check of the starting flow picks the new credentials up
            return
        }

        guard !didValidateLicense else {
            DDLogNotice(
                "[OnboardingCoordinator] Onboarding is past the license step. Only stored the credentials of the license link."
            )
            return
        }

        Task {
            await dismissLicenseViewController()

            guard applyResult == .complete else {
                // Nothing to validate, the user has to complete the credentials of the link
                showLicenseEntry()
                return
            }

            await validateLicenseAndContinue()
        }
    }

    /// Presents the license entry screen with the stored credentials and the error message of a
    /// license activation link, if there is one
    private func showLicenseEntry() {
        splash.showLicenseViewController()

        guard let licenseLinkErrorMessage else {
            return
        }
        self.licenseLinkErrorMessage = nil

        guard
            let enterLicenseViewController = splash.viewController.presentedViewController as? EnterLicenseViewController
        else {
            DDLogWarn("[OnboardingCoordinator] License entry screen is not presented. Unable to show error message.")
            return
        }

        enterLicenseViewController.showErrorMessage(licenseLinkErrorMessage)
    }

    /// Dismisses the license entry screen if it is presented, so the flow can continue or present it
    /// again with the credentials of the activation link
    private func dismissLicenseViewController() async {
        guard splash.viewController.presentedViewController is EnterLicenseViewController else {
            return
        }

        await withCheckedContinuation { continuation in
            splash.viewController.dismiss(animated: false) {
                continuation.resume()
            }
        }
    }

    private func continueAfterLicenseValidation() async {
        didValidateLicense = true

        do {
            try await proceedAfterLicenseValidation()
        }
        catch {
            DDLogError("Threema MDM fetch failed: \(error)")

            splash.showWorkDataFetchFailedAlert()
        }
    }

    private func proceedAfterLicenseValidation() async throws {
        try await bootstrap.bootstrapWorkDataFetcher.checkUpdateThreemaMDM()
            
        // Reload MDM values after fetch
        bootstrapMDMSetup.loadIDCreationValues()
        bootstrapMDMSetup.loadRenewableValues()
            
        let flow = mdmFlow(
            hasDataOnDevice: bootstrapIdentityService.hasDataOnDevice
        )
            
        await handleMDMFlow(flow)
    }
    
    private func handleMDMFlow(_ flow: MDMFlow) async {
        switch flow {
        case let .forceSafeRestore(identityOnly):
            splash.navigateToRestoreSafeViewController(identityOnly: identityOnly)
                
        case .restoreFromMDMBackup:
            await restoreFromMDMBackup()
                
        case .directSetupWizard:
            await handleMDMFlowDirectSetupWizard()
                
        case .showPrivacyControls:
            splash.showPrivacyControls()
        }
    }
    
    private func handleMDMFlowDirectSetupWizard() async {
        do {
            try await proceedToSetupWizard()
        }
        catch {
            DDLogError("MDM direct setup wizard failed: \(error)")
            
            showIDCreationErrorAlert { [weak self] in
                Task { @MainActor in
                    await self?.handleMDMFlowDirectSetupWizard()
                }
            }
        }
    }
    
    private func restoreFromMDMBackup() async {
        splash.setAcceptPrivacyPolicyValues(.implicitly)

        do {
            try await bootstrapMDMSetup.restoreIDBackup()
            try await proceedToSetupWizard()
        }
        catch {
            DDLogError("MDM backup restore failed: \(error)")

            splash.showRestoreIdentityViewController(
                withBackupData: bootstrapMDMSetup.idBackup,
                password: bootstrapMDMSetup.idBackupPassword,
                error: error
            )
        }
    }
        
    private func proceedToSetupWizard() async throws {
        let (remoteSecretManager, keychainManager) = try await resolveRemoteSecret()
        updateFileUtility(remoteSecretManager: remoteSecretManager)
        RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)
        
        bootstrap.licenseStore.performUpdateWorkInfo()
        
        splash.presentPageViewController(
            with: SetupConfiguration(
                remoteSecretAndKeychain: RemoteSecretAndKeychainObjC(
                    remoteSecretManager: remoteSecretManager,
                    keychainManager: keychainManager
                ),
                mdm: bootstrapMDMSetup.mdmSetup
            )
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
        
        // This function should never be reached if the new ID setup is triggered as the new ID setup is disabled if
        // there is an existing RS
        guard isSetupTriggered == false else {
            DDLogError("This should not be reached because new ID setup is disabled if there is an existing RS")
            assertionFailure()
            throw RemoteSecretResolver.ResolverError.invalidFlow
        }
        
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
                DeleteRevokeIdentityManager.deleteLocalDataWithoutBusinessReady()
                exit(EXIT_SUCCESS)
            },
            onCancel: { [weak self, window, previousVC] in
                window.rootViewController = previousVC
                
                guard let self else {
                    DDLogWarn("Unable to navigate back on previous view controller")
                    return
                }
                
                // If Safe restore is disabled, go back to splash otherwise go back to RestoreOptionBackupViewController
                if self.bootstrapMDMSetup.isSafeRestoreDisabled {
                    self.splash.navigateBackToSplash()
                }
                else {
                    self.splash.navigateBackToRestoreOptionBackupViewController()
                }
            }
        )
        
        window.rootViewController = previousVC
        
        let (remoteSecretManager, keychainManager) = try resolver.continueAfterFetch(
            remoteSecretManager: fetchedRSManager
        )
        try resolver.syncKeychain(with: keychainManager)
        return (remoteSecretManager, keychainManager)
    }

    /// Updates `FileUtility.shared` with the RS-aware decorator.
    /// Replaces the side-effect from `RemoteSecretProvider.remoteSecretManager` didSet.

    // TODO: Remove this and its call sites once it is confirmed on device that the provider covers it.
    //
    // `RemoteSecretProvider.setRemoteSecretManager(_:)`, which every call site here invokes on the very next line,
    // already installs a `FileUtilityRemoteSecretDecorator` built from the same `FileUtility()` and the same whitelist
    // — see `RemoteSecretProvider.set(_:)`. So the decorator this installs is replaced by an identical one
    // immediately, and nothing runs in between to observe the difference. `AppLaunchSequenceManager` sets the provider
    // without calling anything like this, and so does the identity pass of `OnboardingRestoreLocalBackupManager`,
    // which is the shortest path to prove it. Kept for now because it predates the data backup work and the claim is
    // untested outside of reading the code.
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

        /// We only show the existing ID question if it's not a business app.
        if bootstrap.appLaunchManager.isBusinessApp == false,
           let identity = bootstrapIdentityService.currentIdentity {
            splash.showIDExistsQuestion(for: identity.rawValue)
            return
        }
        
        if let backup = bootstrapIdentityService.checkForIDBackup() {
            foundIDBackup = backup
            splash.showIDBackupQuestion()
            return
        }
        
        await showSetupViewController()
    }
        
    private func showSetupViewController() async {
        splash.setAcceptPrivacyPolicyValues(.explicitly)
        splash.showRandomSeedViewController()
    }
        
    // MARK: - Restore Flow
        
    private func handleRestoreTapped() async {
        isSetupTriggered = false
            
        if bootstrapMDMSetup.isSafeRestoreDisabled {
            if let backup = bootstrapIdentityService.checkForIDBackup() {
                foundIDBackup = backup
                splash.showIDBackupQuestion()
                return
            }
                
            splash.showRestoreIdentityViewController(
                withBackupData: nil,
                password: nil,
                error: nil
            )
        }
        else {
            if bootstrapIdentityService.hasDataOnDevice {
                splash.navigateToRestoreOptionDataViewController()
            }
            else {
                splash.navigateToRestoreOptionBackupViewController()
            }
        }
    }
        
    // MARK: - Identity Creation
        
    private func createIdentity(with seed: Data) async {
        splash.showLoadingHUD()
            
        bootstrapIdentityService.generateKeyPair(from: seed)
            
        let result = await bootstrapIdentityService.createIdentity()
            
        switch result {
        case .success:
            await processCreatedIdentity()
                
        case let .failure(error):
            processIdentityCreationError(error)
        }
    }
    
    private func processCreatedIdentity() async {
        do {
            try await proceedToSetupWizard()
        }
        catch {
            processIdentityCreationError(error)
        }
    }
    
    private func processIdentityCreationError(_ error: Error) {
        splash.hideLoadingHUD()
        splash.showIdentityCreationError(error)
    }
    
    // MARK: - Error Handling
    
    private func showIDCreationErrorAlert(retryAction: @escaping () -> Void, cancelAction: (() -> Void)? = nil) {
        if let cancelAction {
            UIAlertTemplate.showAlert(
                owner: rootViewController,
                title: String.localizedStringWithFormat(
                    #localize("onboarding_ID_creation_error_title"),
                    bootstrap.flavorService.localizedAppName
                ),
                message: #localize("onboarding_ID_creation_error_message"),
                titleOk: #localize("try_again"),
                actionOk: { _ in
                    retryAction()
                },
                actionCancel: { _ in
                    cancelAction()
                }
            )
        }
        else {
            UIAlertTemplate.showOKAlert(
                owner: rootViewController,
                title: String.localizedStringWithFormat(
                    #localize("onboarding_ID_creation_error_title"),
                    bootstrap.flavorService.localizedAppName
                ),
                message: #localize("onboarding_ID_creation_error_message"),
                titleOk: #localize("try_again")
            ) { _ in
                retryAction()
            }
        }
    }
}

// MARK: - SplashViewControllerDelegate

extension OnboardingCoordinator: SplashViewControllerDelegate {
    func splashViewControllerDidAppear(_ viewController: SplashViewController) {
        guard !didStartOnboardingFlow else {
            return
        }
        didStartOnboardingFlow = true

        splash.setRestoreButtonHidden(bootstrapMDMSetup.disableBackups)

        Task {
            await beginOnboardingFlow()
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
            splash.showRestoreIdentityViewController(
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
            splash.showRestoreIdentityViewController(
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
                await useExistingIdentity()
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
    
    func useExistingIdentity() async {
        // If we don't progress the state at this point the keychain data might be deleted at some later point
        AppSetup.state = .identityAdded
        
        do {
            try await proceedToSetupWizard()
        }
        catch {
            DDLogError("Using existing ID failed: \(error)")
            
            UIAlertTemplate.showOKAlert(
                owner: rootViewController,
                title: String.localizedStringWithFormat(
                    #localize("onboarding_ID_creation_error_title"),
                    bootstrap.flavorService.localizedAppName
                ),
                message: nil
            ) { _ in
                AppSetup.state = .notSetup
                // No navigation needed as it will already switch back to the splash screen
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
        splash.cancelIDCreation()
    }
        
    func splashViewController(
        _ viewController: SplashViewController,
        didSelectRestoreOption option: RestoreOption
    ) {
        switch option {
        case .safe:
            splash.navigateToRestoreSafeViewController(identityOnly: false)

        case .localBackup:
            showLocalBackupFilePicker(from: splash)

        case .safeIdentityOnly:
            splash.navigateToRestoreSafeViewController(identityOnly: true)

        case .idBackup:
            if let backup = bootstrapIdentityService.checkForIDBackup() {
                foundIDBackup = backup
                // If we don't slide out the current view the question is just shown on top of the existing view
                splash.slideOutRestoreOptionBackupViewController()
                splash.showIDBackupQuestion()
            }
            else {
                splash.showRestoreIdentityViewController(
                    withBackupData: nil,
                    password: nil,
                    error: nil
                )
            }

        case .keepLocalData:
            splash.navigateToRestoreOptionBackupViewController()
        }
    }
        
    func splashViewControllerDidCompleteRestoreIdentity(
        _ viewController: SplashViewController
    ) {
        Task {
            await handleCompletedIdentityRestore()
        }
    }
    
    private func handleCompletedIdentityRestore() async {
        do {
            try await proceedToSetupWizard()
        }
        catch {
            DDLogError("Handling of completed ID restore failed: \(error)")
            
            showIDCreationErrorAlert { [weak self] in
                Task { @MainActor in
                    await self?.handleCompletedIdentityRestore()
                }
            } cancelAction: { [weak self] in
                guard let self else {
                    return
                }
                
                Task { @MainActor in
                    // If Safe restore is disabled, go back to splash otherwise go back to
                    // RestoreOptionBackupViewController
                    if self.bootstrapMDMSetup.isSafeRestoreDisabled {
                        self.splash.navigateBackToSplash()
                    }
                    else {
                        self.splash.navigateBackToRestoreOptionBackupViewController()
                    }
                }
            }
        }
    }
        
    func splashViewControllerDidCancelRestore(
        _ viewController: SplashViewController
    ) {
        // Only called from optionDataCancelled — always go back to splash
        splash.navigateBackToSplash()
    }
    
    func splashViewControllerDidCancelRestoreOptionBackup(
        _ viewController: SplashViewController
    ) {
        if bootstrapIdentityService.hasDataOnDevice {
            splash.navigateBackToRestoreOptionDataViewController()
        }
        else {
            splash.navigateBackToSplash()
        }
    }
    
    func splashViewControllerDidCancelRestoreSafe(
        _ viewController: SplashViewController
    ) {
        splash.navigateBackToRestoreOptionBackupViewController()
    }

    func splashViewControllerDidCancelRestoreIdentity(
        _ viewController: SplashViewController
    ) {
        // If user came from setup flow (via ID backup question) or Safe restore is disabled, go back to splash.
        // If user came from restore flow and Safe restore is not disabled, go back to RestoreOptionBackupVC
        if isSetupTriggered || bootstrapMDMSetup.isSafeRestoreDisabled {
            splash.navigateBackToSplash()
        }
        else {
            splash.navigateBackToRestoreOptionBackupViewController()
        }
    }
        
    func splashViewControllerDidConfirmLicense(
        _ viewController: SplashViewController
    ) {
        Task {
            await continueAfterLicenseValidation()
        }
    }
    
    func splashViewController(
        _ viewController: SplashViewController,
        didCompleteIDSetupWith setupConfiguration: SetupConfiguration
    ) async {
        // The setup wizard covers the splash view controller, thus the spinner and any alert have to
        // be presented on the topmost view controller to be visible at all. Drive the injected
        // presenter (`viewController === splash.viewController` in production), not the reporting
        // argument, so the flow stays testable.
        let presenter = splash.viewController.topmostPresentedViewController

        do {
            try await SpinnerPresenter.presentSpinner(in: presenter.view) {
                try await completeOnboarding(
                    remoteSecretManager: setupConfiguration.remoteSecretAndKeychain.remoteSecretManager,
                    keychainManager: setupConfiguration.remoteSecretAndKeychain.keychainManager,
                    setupConfiguration: setupConfiguration
                )
            }
        }
        catch {
            DDLogError("Failed to complete ID setup: \(error)")

            UIAlertTemplate.showAlert(
                owner: presenter,
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
                },
                actionCancel: { [viewController] _ in
                    // Otherwise the last wizard screen is a dead end: its "Finish" button stays
                    // disabled from the previous attempt
                    viewController.resetIDSetupCompletion()
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
                        password: restoreSafeViewController.restoreServerPassword,
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
                presenter: restoreSafeViewController
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
    /// - Note: Internal rather than private so tests can drive it with a `SafeRestorePresenting` double;
    ///   `RestoreSafeViewController` comes from the `CreateID` storyboard.
    @MainActor
    func handleSafeRestore(
        info: OnboardingRestoreSafeInformation,
        presenter: any SafeRestorePresenting
    ) async {
        do {
            LogManager.clearLoggerOutput(for: .safeRestoreFileLog)
            LogManager.addLogger(for: .safeRestoreFileLog)

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
            
            LogManager.removeLogger(for: .safeRestoreFileLog)

            // Complete onboarding directly — safe restore already handled
            // migrations + Safe, so no setupConfiguration needed
            try await completeOnboarding(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            )

            presenter.safeRestoreDidFinish()
        }
        catch {
            presenter.safeRestoreDidFail(with: error)
        }
    }

    /// Shared completion path: given RS + keychain, run post-setup steps and finish onboarding.
    ///
    /// - Parameter setupConfiguration: When coming from the setup wizard, contains the user's
    ///   choices (nickname, email, phone, contacts, Safe password). When coming from safe restore,
    ///   pass `nil` — migrations and Safe activation were already handled by `performRestore`.
    @MainActor
    private func completeOnboarding(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        setupConfiguration: SetupConfiguration? = nil
    ) async throws {
        let appContainer = try await onboardingCompleter.complete(
            remoteSecretManager: remoteSecretManager,
            keychainManager: keychainManager,
            setupConfiguration: setupConfiguration,
            bootstrapMDM: bootstrapMDMSetup
        )

        delegate?.onboardingDidComplete(self, appContainer: appContainer)
    }
}

// MARK: - MDM Bootstrap Flow Decision

extension OnboardingCoordinator {
    /// Determines the initial onboarding flow based on MDM configuration.
    enum MDMFlow: Equatable {
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
        if bootstrapMDMSetup.isSafeRestoreForced {
            return .forceSafeRestore(identityOnly: hasDataOnDevice)
        }
        
        if bootstrapMDMSetup.hasIDBackup,
           bootstrap.appLaunchManager.isAppSetupCompleted == false {
            return .restoreFromMDMBackup
        }
        
        if bootstrap.appLaunchManager.shouldDirectlyShowSetupWizard {
            return .directSetupWizard
        }
        
        return .showPrivacyControls
    }
}

// MARK: - Local Data Backup Restore

extension OnboardingCoordinator {
    private func showLocalBackupFilePicker(from splash: any SplashPresenting) {
        let picker = LocalBackupFilePicker(
            presenter: splash.viewController
        ) { [weak self, weak splash] url in
            guard let self, let splash else {
                return
            }

            let sizeInBytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            DDLogNotice("[LocalBackupRestore] Picked \(url.lastPathComponent) (\(sizeInBytes) bytes)")

            showLocalBackupRecoveryKeyEntry(for: url, from: splash)
        }

        localBackupFilePicker = picker
        picker.show()
    }

    /// Asks for the recovery key the picked backup was encrypted with.
    ///
    /// - Parameter isNavigatingBack: Animates the navigation backwards, for returning here from the restore screen.
    private func showLocalBackupRecoveryKeyEntry(
        for backupURL: URL,
        from splash: any SplashPresenting,
        isNavigatingBack: Bool = false
    ) {
        let model = LocalBackupRecoveryKeyEntryViewModel()

        model.onContinueButtonTapped = { [weak self, weak splash] recoveryKey in
            guard let self, let splash else {
                return
            }

            showLocalBackupRestore(backupURL: backupURL, recoveryKey: recoveryKey, from: splash)
        }

        let keyEntryViewController = OnboardingHostingController(
            rootView: LocalBackupRecoveryKeyEntryView(model: model)
        ) { [weak splash] in
            splash?.navigateBackToRestoreOptionBackupViewController()
        }

        if isNavigatingBack {
            splash.navigateBack(to: keyEntryViewController)
        }
        else {
            splash.navigate(to: keyEntryViewController)
        }
    }

    private func showLocalBackupRestore(
        backupURL: URL,
        recoveryKey: String,
        from splash: any SplashPresenting
    ) {
        let model = LocalBackupRestoreViewModel(state: .inProgress) { [weak self] onProgress in
            guard let self else {
                return
            }

            try await performLocalBackupRestore(
                backupURL: backupURL,
                recoveryKey: recoveryKey,
                onProgress: onProgress
            )
        }

        model.onTryAgainButtonTapped = { [weak self, weak splash] in
            guard let self, let splash else {
                return
            }

            showLocalBackupRecoveryKeyEntry(for: backupURL, from: splash, isNavigatingBack: true)
        }

        model.onDismissButtonTapped = { [weak splash] in
            splash?.navigateBackToRestoreOptionBackupViewController()
        }

        let restoreViewController = OnboardingHostingController(
            rootView: LocalBackupRestoreView(model: model)
        ) {
            // Swiping back out of a running restore would leave the app half-restored, so the gesture does nothing
            // here. The screen's own buttons are the way out.
        }

        splash.navigate(to: restoreViewController)
    }

    /// Sequences the two passes of a local backup restore around the remote secret, and completes onboarding.
    ///
    /// The identity lives *inside* the backup and the remote secret cannot be resolved without it —
    /// `resolveRemoteSecret()` ends in `syncKeychain(with:)`, which throws `noIdentityFound` when the identity is in
    /// neither the store nor the keychain. `OnboardingRestoreLocalBackupManager` therefore hands the identity over
    /// first, and reads the rest of the backup in once the app stands on the secret resolved for it.
    private func performLocalBackupRestore(
        backupURL: URL,
        recoveryKey: String,
        onProgress: @escaping LocalBackupRestoreViewModel.ProgressHandler
    ) async throws {
        _ = try await restoreLocalBackupManager.restoreIdentity(from: backupURL, recoveryKey: recoveryKey)

        let (remoteSecretManager, keychainManager) = try await resolveRemoteSecret()

        updateFileUtility(remoteSecretManager: remoteSecretManager)
        RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

        let progressUpdates = await restoreLocalBackupManager.restoreData(
            from: backupURL,
            recoveryKey: recoveryKey,
            remoteSecretManager: remoteSecretManager
        )

        for try await progress in progressUpdates {
            await MainActor.run {
                onProgress(progress)
            }
        }

        try await completeOnboarding(
            remoteSecretManager: remoteSecretManager,
            keychainManager: keychainManager
        )
    }
}
