import Coordinator
import SwiftUI
import UIKit

final class RCWorkInProgressCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    
    private let presentingViewController: UINavigationController
    
    var rootViewController: UIViewController {
        presentingViewController
    }
    
    private weak var window: UIWindow?
    
    init(
        window: UIWindow,
        presentingViewController: UINavigationController
    ) {
        self.window = window
        self.presentingViewController = presentingViewController
    }
    
    func start() {
        presentingViewController.viewControllers = [
            UIHostingController(rootView: RootCoordinatorPlaceholderView()),
        ]
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
    }
}
