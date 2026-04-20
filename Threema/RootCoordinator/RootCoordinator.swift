import Coordinator
import ThreemaFramework

final class RootCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    
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
    
    init(
        window: UIWindow,
        bootstrap: BootstrapContainer
    ) {
        self.window = window
        self.bootstrap = bootstrap
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
        
        // Run pre-launch setup
        bootstrap.appLaunchManager.runLaunchSetup(window: window)
        
        // TODO: Replace with AppLaunchSequenceManager
        // For now, simulate launch and go to onboarding for fresh install
        try? await Task.sleep(for: .seconds(0.5))
        
        let launchResult = determineLaunchDestination()
        await handleLaunchResult(launchResult)
    }
    
    @MainActor
    private func determineLaunchDestination() -> LaunchResult {
        guard bootstrap.appLaunchManager.isAppSetupCompleted else {
            return .needsOnboarding
        }
        
        // TODO: Handle existing user flows:
        // - .needsRemoteSecretInitialization
        // - .needsPasscode
        // - .ready(appContainer)
        // For now, fall through to onboarding as placeholder
        return .needsOnboarding
    }
    
    private func handleLaunchResult(_ result: LaunchResult) async {
        switch result {
        case .needsOnboarding:
            await goToOnboarding()
            
        case .needsPasscode:
            await goToPasscode()
            
        case .needsRemoteSecretInitialization:
            await handleRemoteSecretInitialization()
            
        case .protectedDataUnavailable:
            showProtectedDataUnavailable()
            
        case let .ready(appContainer):
            await goToMainApp(appContainer: appContainer)
            
        case let .failed(error):
            showError(error)
        }
    }
    
    // MARK: - Transitions
    
    private func goToOnboarding() async {
        let onboardingCoordinator = OnboardingCoordinator(
            bootstrap: bootstrap,
            delegate: self,
            window: window
        )
        
        childCoordinators.append(onboardingCoordinator)
        onboardingCoordinator.start()
        
        childDidFinish(loadingCoordinator)
    }
    
    private func goToPasscode() async {
        // TODO: Implement PasscodeCoordinator
        // We'll need to re-add the loading coordinator here.
        // Also to consider, do we need the loading right away?
        // Or only after remote secret / onboarding
        loadingCoordinator.showLoading(message: "Passcode required...")
    }
    
    private func handleRemoteSecretInitialization() async {
        // TODO: Present RemoteSecret UI using `rootNavigationController`
        // Then call continueAfterRemoteSecret on AppLaunchSequenceManager
        // We'll need to re-add the loading coordinator here.
        // Also to consider, do we need the loading right away?
        // Or only after remote secret / onboarding
        loadingCoordinator.showLoading(message: "Initializing security...")
    }
    
    private func goToMainApp(appContainer: AppDependencyContainer) async {
        // TODO: Got to AppCoordinator
        // Then call continueAfterRemoteSecret on AppLaunchSequenceManager
        // We'll need to re-add the loading coordinator here.
        // Also to consider, do we need the loading right away?
        // Or only after remote secret / onboarding
        loadingCoordinator.showLoading(message: "Loading...")
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
            message: error.message,
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

// MARK: - RootCoordinator.LaunchResult

extension RootCoordinator {
    
    /// Result of the launch sequence.
    /// Will be moved to AppLaunchSequenceManager.
    enum LaunchResult {
        // TODO: RootCoordinator: case needsIDCleanUp?
        case needsOnboarding
        case needsPasscode
        case needsRemoteSecretInitialization
        case protectedDataUnavailable
        case ready(AppDependencyContainer)
        // TODO: RootCoordinator: Should we also have a migration?
        case failed(LaunchError)
    }
}

// MARK: - LaunchError

struct LaunchError: Error {
    let message: String
    let isRetryable: Bool
    
    static let databaseMigrationFailed = LaunchError(
        message: "Database migration failed. Please contact support.",
        isRetryable: false
    )
    
    static let keychainError = LaunchError(
        message: "Unable to access secure storage. Please try again.",
        isRetryable: true
    )
}

// MARK: - AppContainer Placeholder

/// Placeholder for AppContainer - will be implemented later on
@MainActor
final class AppDependencyContainer {
    let bootstrap: BootstrapContainer
    
    init(bootstrap: BootstrapContainer) {
        self.bootstrap = bootstrap
    }
}

// MARK: - RootCoordinator + OnboardingCoordinatorDelegate

extension RootCoordinator: OnboardingCoordinatorDelegate {
    
    func onboardingDidComplete(_ coordinator: OnboardingCoordinator, businessInjector: BusinessInjectorProtocol) {
        // TODO: Use businessInjector to create AppContainer and transition to .ready state
        // For now, show WIP coordinator as placeholder
        let wipCoordinator = RCWorkInProgressCoordinator(
            window: window,
            presentingViewController: rootNavigationController
        )
        childCoordinators.append(wipCoordinator)
        wipCoordinator.start()
    }
}
