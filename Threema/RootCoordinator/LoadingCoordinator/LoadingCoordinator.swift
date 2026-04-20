import Coordinator
import SwiftUI
import UIKit

final class LoadingCoordinator: Coordinator {
    
    // MARK: - Coordinator Protocol
    
    var childCoordinators: [any Coordinator] = []
    
    var rootViewController: UIViewController {
        presentingNavigationViewController
    }
    
    // MARK: - Properties
    
    let presentingNavigationViewController: UINavigationController
    
    let viewModel: LoadingViewModel
    
    private weak var window: UIWindow?
    
    // MARK: - Private Properties
    
    private lazy var loadingViewController: UIHostingController<LoadingView> = {
        let loadingView = LoadingView(viewModel: viewModel)
        return UIHostingController(rootView: loadingView)
    }()
    
    // MARK: - Initialization
    
    init(
        viewModel: LoadingViewModel,
        presentingNavigationViewController: UINavigationController,
        window: UIWindow
    ) {
        self.viewModel = viewModel
        self.presentingNavigationViewController = presentingNavigationViewController
        self.window = window
    }
    
    // MARK: - Coordinator Lifecycle
    
    func start() {
        presentingNavigationViewController.setViewControllers(
            [loadingViewController],
            animated: false
        )
        window?.rootViewController = presentingNavigationViewController
        window?.makeKeyAndVisible()
        viewModel.setInitializing()
    }
    
    // MARK: - State Updates
    
    func showLoading(message: String? = nil) {
        presentingNavigationViewController.popToRootViewController(animated: false)
        viewModel.setLoading(message: message)
    }
    
    func showError(
        message: String,
        isRetryable: Bool = true,
        onRetry: (() -> Void)? = nil
    ) {
        presentingNavigationViewController.popToRootViewController(animated: false)
        viewModel.onRetry = onRetry
        viewModel.setError(message: message, isRetryable: isRetryable)
    }
    
    // MARK: - Status Bar
    
    func configureStatusBar() {
        loadingViewController.overrideUserInterfaceStyle = .dark
    }
}
