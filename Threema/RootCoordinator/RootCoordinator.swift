import CocoaLumberjackSwift
import Coordinator
import Keychain
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

final class RootCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    
    var appCoordinator: AppCoordinator? {
        childCoordinators.first(where: {
            $0 is AppCoordinator
        }) as? AppCoordinator
    }
    
    var tabBarController: UITabBarController? {
        appCoordinator?.tabBarController
    }

    private var onboardingCoordinator: OnboardingCoordinator? {
        childCoordinators.first(where: {
            $0 is OnboardingCoordinator
        }) as? OnboardingCoordinator
    }

    /// Whether a lock is owed at the next activation. `sceneDidBecomeActive` also fires for interruptions
    /// that never backgrounded the scene, and those must not re-lock the app.
    private var didLeaveForegroundSinceUnlock = false

    private var passcodeCoordinator: PasscodeCoordinator? {
        childCoordinators.lazy.compactMap {
            $0 as? PasscodeCoordinator
        }.first
    }
    
    private lazy var rootNavigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        return navigationController
    }()
    
    private lazy var loadingCoordinator = LoadingCoordinator(
        viewModel: LoadingViewModel(),
        presentingNavigationViewController: rootNavigationController,
        window: window
    )
    
    private lazy var callLauncher = CallLauncher(
        voipCallStateManager: VoIPCallStateManager.shared,
        groupCallSingleton: GlobalGroupCallManagerSingleton.shared,
        windowScene: windowScene
    )
    
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    private let window: UIWindow
    private let windowScene: UIWindowScene
    private let bootstrap: BootstrapContainer
    private let launchManager: AppLaunchSequenceManager
    private var screenshotObservers: [any NSObjectProtocol] = []

    private(set) lazy var errorNotificationHandler = ErrorNotificationHandler()

    /// Set when the launch sequence dead-ends because protected data (keychain) was
    /// unavailable — a cold launch while the device is locked. The pre-coordinator
    /// app retried in `applicationProtectedDataDidBecomeAvailable`; without a retry
    /// the app stays on the launch screen forever once the user opens it.
    private var isAwaitingProtectedData = false

    /// License activation link that arrived before the launch sequence reached its destination.
    /// Consumed by ``goToOnboarding()`` and ``goToApp(appContainer:)``, because only they know
    /// whether onboarding or the app has to handle it.
    private var pendingLicenseURL: URL?

    /// Strong owner of the intent handler. ``IntentHandlerProxy`` (via ``DeferredDispatcher``) only
    /// holds it weakly, so without this reference it would deallocate right after
    /// ``goToApp(appContainer:)`` returns and every queued shortcut/intent would silently never fire.
    /// Reassigned on every ``goToApp(appContainer:)`` so it always tracks the current `AppCoordinator`.
    private var intentHandler: IntentHandler?

    private var isSceneForeground: Bool {
        windowScene.activationState != .background
    }
    
    deinit {
        for observer in screenshotObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    init(
        window: UIWindow,
        windowScene: UIWindowScene,
        bootstrap: BootstrapContainer
    ) {
        self.window = window
        self.windowScene = windowScene
        self.bootstrap = bootstrap
        self.launchManager = AppLaunchSequenceManager(bootstrap: bootstrap)
    }

    func start() {
        window.makeSecure()
        
        childCoordinators.append(loadingCoordinator)
        loadingCoordinator.start()
        
        registerScreenshotDetectionObservers()

        errorNotificationHandler.startObserving()

        Task { @MainActor [weak self] in
            await self?.performLaunchSequence()
        }
    }
    
    // MARK: - Scene Lifecycle

    func sceneWillEnterForeground() {
        retryLaunchIfProtectedDataBecameAvailable()
        
        if let appCoordinator {
            let appLaunchTasks = AppLaunchTasks(businessInjector: appCoordinator.appContainer.businessInjector)
            appLaunchTasks.run(launchEvent: .willEnterForeground)
        }
        
        appCoordinator?.willEnterForeground()
        
        // Reload pending user notification cache, because could be changed by Notification Extension in the mean time
        appCoordinator?.appContainer.incomingMessageManager.reloadPendingUserNotificationCache()

        requestReauthenticationIfNeeded()
        hidePrivacyOverlay()
        reconcileTypingObservation()
    }

    func sceneDidBecomeActive() {
        hidePrivacyOverlay()
        appCoordinator?.appContainer.notificationManager.updateUnreadMessagesCount()
        appCoordinator?.didBecomeActive()

        if let passcodeCoordinator {
            passcodeCoordinator.retryBiometricAuthenticationIfNeeded()
        }
        else if didLeaveForegroundSinceUnlock {
            requestReauthenticationIfNeeded()
        }

        reconcileTypingObservation()
    }

    func sceneWillResignActive() {
        appCoordinator?.appContainer.notificationHandler.resetFirstPushHandled()
        showPrivacyOverlay()
    }

    func sceneDidEnterBackground() {
        didLeaveForegroundSinceUnlock = true
        passcodeCoordinator?.sceneDidEnterBackground()
        appCoordinator?.appContainer.passcodeLock.updateLastUnlockTime()
        appCoordinator?.appContainer.bgTaskManager.scheduleTasks()

        appCoordinator?.handleSceneDidEnterBackground()

        SettingsBundleHelper.resetSafeMode()

        showPrivacyOverlay()
        reconcileTypingObservation()

        // Drain pending log writes while we are still running. If the process is suspended with a write in flight we
        // lose the messages and risk a `0xdead10cc` termination for holding a lock in the app group container.
        LogManager.flushLogs()
    }

    // MARK: - Re-authentication

    func requestReauthenticationIfNeeded() {
        // A lock that is up cannot be replaced, but it may still owe the user a biometric prompt.
        if let passcodeCoordinator {
            passcodeCoordinator.retryBiometricAuthenticationIfNeeded()
            return
        }

        guard let appContainer = appCoordinator?.appContainer else {
            return
        }

        let passcodeLock = appContainer.passcodeLock
        guard
            passcodeLock.isPasscodeRequired(),
            !passcodeLock.isWithinGracePeriod()
        else {
            return
        }

        let passcodeCoordinator = PasscodeCoordinator(
            windowScene: windowScene,
            appContainer: appContainer,
            delegate: self
        )
        childCoordinators.append(passcodeCoordinator)
        passcodeCoordinator.start()
    }

    private func reconcileTypingObservation() {
        guard let manager = appCoordinator?.appContainer.typingIndicatorManager else {
            return
        }
        if isSceneForeground {
            manager.startObserving()
        }
        else {
            manager.stopObserving()
        }
    }

    // MARK: - Privacy Overlay

    func showPrivacyOverlay() {
        guard !childCoordinators.contains(where: { $0 is PrivacyCoordinator }) else {
            return
        }
        let coordinator = PrivacyCoordinator(
            windowScene: windowScene,
            isPasscodeRequired: { [weak self] in
                self?.appCoordinator?.appContainer.passcodeLock.isPasscodeRequired() == true
            },
            isRemoteSecretEnabled: {
                do {
                    return try RemoteSecretProvider.isRemoteSecretInKeychain()
                }
                catch {
                    DDLogError("Unable to fetch remote secret from keychain: \(error)")
                    return true
                }
            }
        )
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    func hidePrivacyOverlay() {
        guard let coordinator = childCoordinators.first(where: {
            $0 is PrivacyCoordinator
        }) as? PrivacyCoordinator else {
            return
        }
        coordinator.hideOverlay()
        childDidFinish(coordinator)
    }

    // MARK: - Screenshot Detection

    private func registerScreenshotDetectionObservers() {
        guard bootstrap.flavorService.isBusinessApp else {
            return
        }

        screenshotObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.showScreenshotPrevention()
                }
            }
        ))

        screenshotObservers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    guard UIScreen.main.isCaptured else {
                        return
                    }
                    self?.showScreenshotPrevention()
                }
            }
        ))
    }

    private func showScreenshotPrevention() {
        guard
            bootstrap.flavorService.isBusinessApp,
            MDMSetup().disableScreenshots()
        else {
            return
        }

        let hostingController = UIHostingController(rootView: ScreenshotPreventionView())
        let screenshotPreventionView = hostingController.view!
        screenshotPreventionView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(screenshotPreventionView)

        NSLayoutConstraint.activate([
            screenshotPreventionView.topAnchor.constraint(equalTo: window.topAnchor),
            screenshotPreventionView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            screenshotPreventionView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            screenshotPreventionView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [hostingController] in
            hostingController.view.removeFromSuperview()
        }
    }

    // MARK: - License Activation Link

    /// Handles a license activation link (`<scheme>://license?…`)
    ///
    /// License links must also work before the app is set up, so they can't go through
    /// ``IntentHandlerProxy``, which only delivers once the app UI exists. Forwards to the
    /// ``OnboardingCoordinator`` while onboarding runs, buffers the link while the launch sequence is
    /// still deciding where to go, and otherwise handles it in the running app.
    func handleLicenseURL(_ url: URL) {
        guard url.host()?.lowercased() == "license" else {
            DDLogError(
                "[RootCoordinator] Failed to handle URL: Not a license URL (\(url.host() ?? "unknown")). Aborting license handling."
            )
            return
        }

        guard bootstrap.flavorService.isBusinessApp else {
            DDLogError(
                "[RootCoordinator] Failed to handle URL: No license for private app. Aborting license handling."
            )
            return
        }

        if let onboardingCoordinator {
            onboardingCoordinator.handleLicenseURL(query: url.getQueries)
        }
        else if appCoordinator != nil {
            URLHandler.handleLicense(from: url)
        }
        else {
            pendingLicenseURL = url
        }
    }

    // MARK: - Launch Sequence

    @MainActor
    private func performLaunchSequence() async {
        isAwaitingProtectedData = false
        loadingCoordinator.showLoading()

        bootstrap.appLaunchManager.runLaunchSetup(window: window)

        let result = await launchManager.run()
        await handleLaunchResult(result)
    }

    private func handleLaunchResult(_ result: AppLaunchSequenceManager.LaunchResult) async {
        switch result {
        case .needsOnboarding:
            await goToOnboarding()

        case let .needsPasscode(appContainer):
            await goToPasscode(appContainer: appContainer)

        case .needsRemoteSecretFetch:
            await handleRemoteSecretFetch()

        case .protectedDataUnavailable:
            isAwaitingProtectedData = true
            showProtectedDataUnavailable()

        case let .ready(appContainer):
            await goToApp(appContainer: appContainer)

        case let .failed(error):
            showError(error)
        }
    }

    /// Re-runs the launch sequence if it previously dead-ended on locked protected
    /// data. Called when protected data becomes available and when the scene comes
    /// to the foreground (the launch may have happened in the background, e.g. for
    /// a background task, while the device was still locked).
    func retryLaunchIfProtectedDataBecameAvailable() {
        guard isAwaitingProtectedData, !bootstrap.bootstrapKeychainManager.isKeychainLocked else {
            return
        }

        // Reset before the task runs so a second trigger (foreground + protected
        // data notification) doesn't start the launch sequence twice.
        isAwaitingProtectedData = false

        Task { @MainActor [weak self] in
            await self?.performLaunchSequence()
        }
    }
    
    // MARK: - Transitions
    
    private func goToOnboarding() async {
        let bootstrapMDMSetup = BootstrapMDMAdapter()

        let remoteSecretResolver = RemoteSecretResolver(
            appLaunchManager: bootstrap.appLaunchManager,
            licenseStore: bootstrap.licenseStore.store,
            myIdentityStore: bootstrap.bootstrapIdentityStore.store,
            isRemoteSecretEnabledByMDM: { [bootstrapMDMSetup] in
                bootstrapMDMSetup.isRemoteSecretEnabled
            },
            flavorService: AppFlavorService(),
            hasPreexistingData: bootstrap.appLaunchManager.hasPreexistingDatabaseFile
        )
        let onboardingCoordinator = OnboardingCoordinator(
            bootstrap: bootstrap,
            bootstrapMDMSetup: bootstrapMDMSetup,
            delegate: self,
            window: window,
            remoteSecretResolver: remoteSecretResolver
        )
        
        childCoordinators.append(onboardingCoordinator)
        onboardingCoordinator.start()

        // Hand the link over before the onboarding flow starts (splash `viewDidAppear`), so its
        // license check validates the credentials of the link instead of the ones stored before.
        if let pendingLicenseURL {
            self.pendingLicenseURL = nil
            onboardingCoordinator.handleLicenseURL(query: pendingLicenseURL.getQueries)
        }

        childDidFinish(loadingCoordinator)
    }
    
    private func goToPasscode(appContainer: AppDependencyContainer) async {
        configureCallProvider()

        let passcodeCoordinator = PasscodeCoordinator(
            windowScene: windowScene,
            appContainer: appContainer,
            delegate: self
        )
        childCoordinators.append(passcodeCoordinator)
        passcodeCoordinator.start()
        childDidFinish(loadingCoordinator)
    }
    
    /// Presents RemoteSecret fetch UI (spinner + error recovery) on the loading
    /// coordinator's navigation controller, then continues the launch sequence.
    private func handleRemoteSecretFetch() async {
        let navigationController = loadingCoordinator.presentingNavigationViewController
        
        let viewsManager = RemoteSecretInitializeViewsManager(
            navigationController: navigationController,
            showDeleteAfterRetries: 0
        )
        
        do {
            let identity = bootstrap.bootstrapIdentityStore.store.identity
                .map { ThreemaIdentity($0) }
            
            let remoteSecretManager = try await viewsManager.start(
                identity: identity,
                onDelete: { [weak self] in
                    try? self?.bootstrap.bootstrapKeychainManager.deleteAllItems()
                    exit(EXIT_SUCCESS)
                },
                onCancel: nil
            )
            
            // Restore loading view after fetch UI
            loadingCoordinator.showLoading()
            
            let result = await launchManager.continueAfterRemoteSecretFetch(
                remoteSecretManager: remoteSecretManager
            )
            await handleLaunchResult(result)
        }
        catch {
            loadingCoordinator.showLoading()
            showError(
                LaunchError.remoteSecretSetupFailed(
                    LaunchRemoteSecretError(
                        code: .general(error),
                        enableDeletion: false
                    )
                )
            )
        }
    }
    
    private func configureCallProvider() {
        CallProvider.shared.setCallLauncher(callLauncher)
    }

    private func goToApp(appContainer: AppDependencyContainer) async {
        configureCallProvider()

        // Tear down a previous AppCoordinator (e.g. after erase → onboarding → relaunch).
        // The `appCoordinator` accessor scans `childCoordinators` by type, so a stale
        // instance left in there would shadow or race the new one.
        if let previousAppCoordinator = appCoordinator {
            previousAppCoordinator.finish()
            childDidFinish(previousAppCoordinator)
        }

        let appCoordinator = AppCoordinator(
            window: window,
            appContainer: appContainer,
            launchModalManager: LaunchModalManager.shared
        )
        childCoordinators.append(appCoordinator)

        // NOTE: Do NOT attach the split view to the window here. `appCoordinator.start()` configures the
        // split view's columns/tabs and THEN sets it as the window root and calls `makeKeyAndVisible()`.
        // Attaching + showing the still-unconfigured split view first caused a second `makeKeyAndVisible`
        // / root swap, which left the `.doubleColumn` split view compact-but-NOT-collapsed on launch (the
        // empty logo screen that only a real size-class transition / rotation could recover).
        appCoordinator.start()

        childDidFinish(loadingCoordinator)

        reconcileTypingObservation()
        let handler = makeIntentHandler(appContainer: appContainer, appCoordinator: appCoordinator)
        intentHandler = handler
        SceneDelegate.current?.intentHandlerProxy.attach(handler)

        // A license link received during launch (e.g. relicensing an already set up app): the
        // running-app path needs the app UI, so it can only run now.
        if let pendingLicenseURL {
            self.pendingLicenseURL = nil
            URLHandler.handleLicense(from: pendingLicenseURL)
        }

        // Attach the notification handler only now: replaying a queued cold-start
        // notification response (push tap) any earlier deep-links into a UI that is
        // still being built. The hop to the next main-actor turn lets the first
        // frame of the app hierarchy commit (and the tab routers bind in
        // `viewIsAppearing`) before the deep link mutates navigation state.
        Task { @MainActor in
            ApplicationDelegate.delegate?.notificationDelegateProxy
                .attach(appContainer.notificationHandler)
        }

        /// Start Sentry now that all dependencies are ready,
        /// due to our redaction mechanism depending on the entity manager,
        /// and the entity manager, on remote secret.
        SentryClient.shared.start()
    }

    private func makeIntentHandler(
        appContainer: AppDependencyContainer,
        appCoordinator: AppCoordinator
    ) -> IntentHandler {
        IntentHandler(
            entityManager: appContainer.businessInjector.entityManager,
            voipCallStateManager: .shared,
            hasAudioCallSupportForContact: {
                FeatureMask.check(
                    contact: Contact(contactEntity: $0),
                    for: .o2OAudioCallSupport
                )
            },
            handleConversation: { [weak appCoordinator] conversation in
                appCoordinator?.show(conversation: conversation)
            },
            rootViewControllerProvider: { [weak self] in
                self?.window.rootViewController
            },
            urlHandlerFactory: {
                URLHandler(businessInjector: appContainer.businessInjector)
            }
        )
    }
    
    private func showProtectedDataUnavailable() {
        loadingCoordinator.showError(
            message: #localize("root_coordinator_protected_data_unavailable_message"),
            onRetry: { [weak self] in
                Task {
                    await self?.performLaunchSequence()
                }
            }
        )
    }
    
    private func showError(_ error: LaunchError) {
        // Needs to be separate, because inlining it below leads to a compiler error
        let onRetry: (@Sendable () -> Void) = { [weak self] in
            Task {
                await self?.performLaunchSequence()
            }
        }
        
        let onDelete: (@Sendable () -> Void) = {
            Task { @MainActor in
                DeleteRevokeIdentityManager.deleteLocalDataWithoutBusinessReady()
                exit(EXIT_SUCCESS)
            }
        }
        
        switch error {
        case .databaseMigrationFailed, .encryptedDataDetected, .keychainError, .appDelegateNotAvailable:
            loadingCoordinator.showError(
                message: error.localizedDescription,
                onRetry: error.isRetryable
                    ? onRetry
                    : nil
            )
        case let .remoteSecretSetupFailed(remoteSecretError):
            showRemoteSecretError(remoteSecretError, onRetry: onRetry, onDelete: onDelete)
        }
    }
    
    private func showRemoteSecretError(
        _ remoteSecretError: LaunchRemoteSecretError,
        onRetry: @escaping (@Sendable () -> Void),
        onDelete: @escaping (@Sendable () -> Void)
    ) {
        switch remoteSecretError.code {
        case .blocked:
            loadingCoordinator.showLocked()
        case .mismatch, .timeout:
            loadingCoordinator.showError(
                title: remoteSecretError.localizedTitle,
                message: remoteSecretError.localizedDescription,
                onRetry: remoteSecretError.isRetryable ? onRetry : nil,
                onRemove: remoteSecretError.enableDeletion ? onDelete : nil
            )
        case let .general(generalError):
            loadingCoordinator.showError(
                message: generalError.localizedDescription,
                onRetry: remoteSecretError.isRetryable ? onRetry : nil,
                onRemove: remoteSecretError.enableDeletion ? onDelete : nil
            )
        }
    }
}

// MARK: - PasscodeCoordinatorDelegate

extension RootCoordinator: PasscodeCoordinatorDelegate {

    func passcodeCoordinatorDidAuthenticate(
        _ coordinator: PasscodeCoordinator,
        appContainer: AppDependencyContainer,
        evaluatedPolicyDomainState: Data?
    ) {
        if let state = evaluatedPolicyDomainState {
            appContainer.businessInjector.userSettings.evaluatedPolicyDomainStateApp = state
        }

        // Unlocking has to complete within this main-actor turn, together with the window release in
        // `reportSuccess()`. Deferring any of it leaves a turn in which a coordinator that presents
        // nothing still counts as the app's lock.
        childDidFinish(coordinator)
        didLeaveForegroundSinceUnlock = false

        if appCoordinator != nil {
            // Re-auth: passcode window is gone, restore main window as key.
            window.makeKeyAndVisible()
        }
        else {
            // Launch-time auth: AppCoordinator doesn't exist yet and building it is async.
            Task { @MainActor [weak self] in
                await self?.goToApp(appContainer: appContainer)
            }
        }
    }

    func passcodeCoordinatorDidRequestErase(_ coordinator: PasscodeCoordinator) {
        Task { @MainActor in
            DeleteRevokeIdentityManager.deleteLocalDataWithoutBusinessReady()
        }
    }
}

// MARK: - OnboardingCoordinatorDelegate

extension RootCoordinator: OnboardingCoordinatorDelegate {
    
    func onboardingDidComplete(_ coordinator: OnboardingCoordinator, appContainer: AppDependencyContainer) {
        Task { [weak self] in
            guard let self else {
                return
            }
            
            await goToApp(appContainer: appContainer)

            checkHasPrivateChats(appContainer: appContainer)

            childDidFinish(coordinator)
        }
    }

    /// After onboarding (e.g. restore from backup), if private chats exist but no passcode
    /// is set, prompt the user to create one.
    private func checkHasPrivateChats(appContainer: AppDependencyContainer) {
        let passcodeLock = appContainer.passcodeLock
        guard !passcodeLock.isPasscodeRequired() else {
            return
        }

        let entityManager = appContainer.businessInjector.entityManager
        let hasPrivateChats = entityManager.performAndWait {
            guard let conversations = entityManager.entityFetcher.conversationEntities() else {
                return false
            }
            return conversations.contains { $0.conversationCategory == .private }
        }

        guard hasPrivateChats else {
            return
        }

        guard let rootVC = window.rootViewController else {
            return
        }

        UIAlertTemplate.showAlert(
            owner: rootVC,
            title: #localize("privateChat_alert_title"),
            message: String.localizedStringWithFormat(
                #localize("privateChat_setup_alert_message"),
                TargetManager.localizedAppName
            ),
            titleOk: #localize("privateChat_code_alert_confirm"),
            actionOk: { [weak self] _ in
                let vc = JKLLockScreenViewController(
                    nibName: NSStringFromClass(JKLLockScreenViewController.self),
                    bundle: BundleUtil.frameworkBundle()
                )
                vc.lockScreenMode = .new

                let nav = ModalNavigationController(rootViewController: vc)
                nav.isNavigationBarHidden = true
                nav.modalPresentationStyle = .fullScreen
                self?.window.rootViewController?.present(nav, animated: true)
            },
            titleCancel: nil,
            actionCancel: { _ in }
        )
    }
}
