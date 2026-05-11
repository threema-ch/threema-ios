import Coordinator
import Keychain
import ThreemaEssentials
import ThreemaFramework

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
    
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    private let window: UIWindow
    private let bootstrap: BootstrapContainer
    private let launchManager: AppLaunchSequenceManager
    
    init(
        window: UIWindow,
        bootstrap: BootstrapContainer
    ) {
        self.window = window
        self.bootstrap = bootstrap
        self.launchManager = AppLaunchSequenceManager(bootstrap: bootstrap)
    }
    
    func start() {
        childCoordinators.append(loadingCoordinator)
        loadingCoordinator.start()
        
        Task { @MainActor [weak self] in
            await self?.performLaunchSequence()
        }
    }
    
    // MARK: - Launch Sequence
    
    @MainActor
    private func performLaunchSequence() async {
        loadingCoordinator.showLoading()
        
        bootstrap.appLaunchManager.runLaunchSetup(window: window)
        
        let result = await launchManager.run()
        await handleLaunchResult(result)
    }
    
    private func handleLaunchResult(_ result: AppLaunchSequenceManager.LaunchResult) async {
        switch result {
        case .needsOnboarding:
            await goToOnboarding()
            
        case let .needsPasscode(businessInjector):
            await goToPasscode(businessInjector: businessInjector)
            
        case .needsRemoteSecretFetch:
            await handleRemoteSecretFetch()
            
        case .protectedDataUnavailable:
            showProtectedDataUnavailable()
            
        case let .ready(appContainer):
            await goToApp(appContainer: appContainer)
            
        case let .failed(error):
            showError(error)
        }
    }
    
    // MARK: - Transitions
    
    private func goToOnboarding() async {
        let remoteSecretResolver = RemoteSecretResolver(
            appLaunchManager: bootstrap.appLaunchManager,
            licenseStore: bootstrap.licenseStore.store,
            myIdentityStore: bootstrap.bootstrapIdentityStore.store,
            mdmSetup: MDMSetup(),
            flavorService: AppFlavorService(),
            hasPreexistingData: bootstrap.appLaunchManager.hasPreexistingDatabaseFile
        )
        let onboardingCoordinator = OnboardingCoordinator(
            bootstrap: bootstrap,
            delegate: self,
            window: window,
            remoteSecretResolver: remoteSecretResolver
        )
        
        childCoordinators.append(onboardingCoordinator)
        onboardingCoordinator.start()
        
        childDidFinish(loadingCoordinator)
    }
    
    private func goToPasscode(businessInjector: BusinessInjectorProtocol) async {
        // TODO: Implement PasscodeCoordinator (Phase 1)
        loadingCoordinator.showLoading(message: "Passcode required...")
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
                    exit(0)
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
            showError(LaunchError.remoteSecretSetupFailed(error))
        }
    }
    
    private func goToApp(appContainer: AppDependencyContainer) async {
        let appCoordinator = AppCoordinator(
            window: window,
            appContainer: appContainer
        )
        childCoordinators.append(appCoordinator)
        
        window.rootViewController = appCoordinator.rootViewController
        window.makeKeyAndVisible()
        
        appCoordinator.start()
        
        childDidFinish(loadingCoordinator)
    }
    
    private func showProtectedDataUnavailable() {
        loadingCoordinator.showError(
            message: "Protected data is not available. Please unlock your device.",
            isRetryable: true,
            onRetry: { [weak self] in
                Task {
                    await self?.performLaunchSequence()
                }
            }
        )
    }
    
    private func showError(_ error: LaunchError) {
        loadingCoordinator.showError(
            message: error.localizedDescription,
            isRetryable: error.isRetryable,
            onRetry: error.isRetryable
                ? { [weak self] in
                    Task {
                        await self?.performLaunchSequence()
                    }
                }
                : nil
        )
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
            
            childDidFinish(coordinator)
        }
    }
}
