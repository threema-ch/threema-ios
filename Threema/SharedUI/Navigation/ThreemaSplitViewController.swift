import SwiftUI
import UIKit

@objc final class ThreemaSplitViewController: UISplitViewController {
    
    private(set) lazy var threemaTabBarController = ThreemaTabBarController()
    private lazy var navigationManager = ThreemaSplitViewNavigationManager()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard (presentedViewController is PortraitNavigationController) == false else {
            return []
        }
        
        if isCollapsed {
            return .allButUpsideDown
        }
        else {
            return .all
        }
    }

    // MARK: - Lifecycle Methods
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        preferredDisplayMode = .oneBesideSecondary
        presentsWithGesture = false
        
        displayModeButtonItem.customView = UIView()
        displayModeButtonItem.isEnabled = false
        displayModeButtonItem.isHidden = true
        
        navigationManager.configure(
            with: self,
            tabBarController: threemaTabBarController
        )
    }
    
    // MARK: - Public functions

    func setViewControllers(
        _ viewControllers: [UIViewController],
        for item: ThreemaTab
    ) {
        navigationManager.thetaStack.store(
            stack: viewControllers,
            for: item
        )
    }
    
    func switchTabIfNeeded(to item: ThreemaTab) {
        guard threemaTabBarController.selectedIndex != item.rawValue else {
            return
        }
        
        threemaTabBarController.selectedIndex = item.rawValue
    }
    
    func navigationController(
        for item: ThreemaTab
    ) -> UINavigationController? {
        if isCollapsed {
            threemaTabBarController.navigationController(
                for: item
            )
        }
        else {
            viewControllers.last as? UINavigationController
        }
    }
    
    func isTopControllerChat(for contact: ContactEntity?) -> Bool {
        guard
            threemaTabBarController.selectedThreemaTab == .conversations,
            let contact,
            let navigationController = navigationController(for: .conversations),
            let chatViewController = navigationController.topViewController as? ChatViewController
        else {
            return false
        }
        
        return chatViewController.isChat(for: contact)
    }
}
