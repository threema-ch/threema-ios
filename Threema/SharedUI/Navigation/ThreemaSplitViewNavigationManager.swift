import UIKit

final class ThreemaSplitViewNavigationManager: NSObject {
    
    // MARK: - Private properties
    
    private(set) lazy var thetaStack = ThetaStack()
    private weak var splitViewController: ThreemaSplitViewController?
    private weak var tabBarController: ThreemaTabBarController?
    private var previousSelectedTab: ThreemaTab?
    
    private var secondaryNavigationController: UINavigationController? {
        splitViewController?.viewControllers.last as? UINavigationController
    }
    
    private var selectedTabNavigationController: UINavigationController? {
        tabBarController?.selectedViewController as? UINavigationController
    }
    
    // MARK: - Public methods
    
    func configure(
        with splitViewController: ThreemaSplitViewController,
        tabBarController: ThreemaTabBarController
    ) {
        self.splitViewController = splitViewController
        self.tabBarController = tabBarController
        
        splitViewController.delegate = self
        tabBarController.delegate = self
    }
    
    // MARK: - Private methods
    
    private func storeViewControllerStack(for tab: ThreemaTab) {
        let viewControllersToStore = currentNavigationStack(for: tab)
        thetaStack.store(stack: viewControllersToStore, for: tab)
    }
    
    private func currentNavigationStack(for tab: ThreemaTab) -> [UIViewController] {
        /// If this is the currently selected tab, get the current navigation state
        if tab == tabBarController?.selectedThreemaTab {
            /// In regular mode: navigation is in secondary view controller
            if let secondaryNavigationController {
                return secondaryNavigationController.viewControllers.filter { !($0 is ThreemaLogoViewController) }
            }
            /// In compact mode: navigation is in the selected tab controller
            else if let selectedTabNavigationController {
                return Array(selectedTabNavigationController.viewControllers.dropFirst())
            }
        }
        
        /// For non-current tabs, return what's stored in navigationStateStorage
        return thetaStack.restore(for: tab)
    }
    
    private func storeCurrentViewControllerStack() {
        guard let currentTab = tabBarController?.selectedThreemaTab else {
            return
        }
        
        storeViewControllerStack(for: currentTab)
    }
    
    private func restoreViewControllerStack(for tab: ThreemaTab) {
        let savedStack = thetaStack.restore(for: tab)
        let filteredStack = savedStack.filter { !($0 is ThreemaLogoViewController) }
        
        replaceNavigationStack(filteredStack, for: tab)
    }
    
    private func replaceNavigationStack(
        _ controllers: [UIViewController],
        for tab: ThreemaTab
    ) {
        /// Only restore to UI if this is the currently selected tab
        guard tab == tabBarController?.selectedThreemaTab else {
            return
        }
        
        /// In regular mode: set navigation in secondary view controller
        if let secondaryNavigationController {
            if !controllers.isEmpty {
                secondaryNavigationController.viewControllers = controllers
            }
            else {
                let emptyVC = ThreemaLogoViewControllerFactory.threemaLogoViewController
                secondaryNavigationController.viewControllers = [emptyVC]
            }
        }
        /// In compact mode: set navigation in selected tab controller
        else if let selectedTabNavigationController {
            if !controllers.isEmpty {
                var fullStack = [selectedTabNavigationController.viewControllers.first].compactMap { $0 }
                fullStack.append(contentsOf: controllers)
                selectedTabNavigationController.setViewControllers(fullStack, animated: false)
            }
            else {
                if let rootVC = selectedTabNavigationController.viewControllers.first {
                    selectedTabNavigationController.setViewControllers([rootVC], animated: false)
                }
            }
        }
    }
}

// MARK: - UISplitViewControllerDelegate

extension ThreemaSplitViewNavigationManager: UISplitViewControllerDelegate {
    
    // MARK: - Collapse Handling
    
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        guard
            let tabBarController = primaryViewController as? ThreemaTabBarController,
            let selectedNavigationController = tabBarController.selectedViewController as? UINavigationController
        else {
            return false
        }
        
        /// Store current tab's state before any UI changes
        if let secondaryNavigationController = splitViewController.viewControllers.last as? UINavigationController {
            let currentTab = tabBarController.selectedThreemaTab
            let viewControllersToStore = secondaryNavigationController.viewControllers
                .filter { !($0 is ThreemaLogoViewController) }
            thetaStack.store(stack: viewControllersToStore, for: currentTab)
        }
        
        /// Handle the secondary view controller, which is a UINavigationController
        if let secondaryNavigationController = secondaryViewController as? UINavigationController {
            
            var secondaryViewControllersToTransfer = secondaryNavigationController.viewControllers
            
            /// Filter out ``ThreemaLogoViewController``
            secondaryViewControllersToTransfer = secondaryViewControllersToTransfer
                .filter { !($0 is ThreemaLogoViewController) }
            
            guard !secondaryViewControllersToTransfer.isEmpty else {
                return true
            }
            
            /// Ensure we clean the view controllers in the secondaryNavigationController
            secondaryNavigationController.setViewControllers([], animated: false)
            
            var currentViewControllers = selectedNavigationController.viewControllers
            
            currentViewControllers.append(contentsOf: secondaryViewControllersToTransfer)
            
            selectedNavigationController.setViewControllers(currentViewControllers, animated: false)
        }
        
        return true
    }
    
    // MARK: - Expand Handling
    
    func splitViewController(
        _ splitViewController: UISplitViewController,
        separateSecondaryFrom primaryViewController: UIViewController
    ) -> UIViewController? {
        guard let tabBarController = primaryViewController as? ThreemaTabBarController else {
            /// Return navigation controller with ``ThreemaLogoViewController`` in a navigation controller
            /// if there is nothing in the secondary controller
            return ThreemaLogoViewControllerFactory.threemaLogoNavigationController()
        }
        
        /// Store current tab's navigation state and pop all tabs to root
        storeCurrentViewControllerStack()
        
        /// Pop all tabs to root
        if let tabViewControllers = tabBarController.viewControllers {
            for tabViewController in tabViewControllers {
                if let navigationController = tabViewController as? UINavigationController {
                    navigationController.popToRootViewController(animated: false)
                }
            }
        }
        
        /// Create secondary navigation controller with current tab's saved state
        let selectedTab = tabBarController.selectedThreemaTab
        
        let savedStack = thetaStack.restore(for: selectedTab)
        let filteredStack = savedStack.filter { !($0 is ThreemaLogoViewController) }
        
        let secondaryNavigationController: UINavigationController
        if !filteredStack.isEmpty {
            secondaryNavigationController = UINavigationController()
            secondaryNavigationController.viewControllers = filteredStack
        }
        else {
            secondaryNavigationController = ThreemaLogoViewControllerFactory.threemaLogoNavigationController()
        }
        
        return secondaryNavigationController
    }
    
    // MARK: - Display Mode
    
    func splitViewController(
        _ splitViewController: UISplitViewController,
        show vc: UIViewController,
        sender: Any?
    ) -> Bool {
        if splitViewController.isCollapsed {
            guard
                let tabBarController = splitViewController.viewControllers.first as? ThreemaTabBarController,
                let navigationController = tabBarController.selectedViewController as? UINavigationController
            else {
                return false
            }
            
            navigationController.pushViewController(vc, animated: true)
        }
        else {
            guard let navigationController = splitViewController.viewControllers.last as? UINavigationController else {
                return false
            }
            
            /// If it's not collapsed, we just replace the secondary controller
            navigationController.setViewControllers([vc], animated: false)
        }
        
        /// Handle storage after pushing
        storeCurrentViewControllerStack()
        
        return true
    }
    
    func splitViewController(
        _ splitViewController: UISplitViewController,
        showDetail vc: UIViewController,
        sender: Any?
    ) -> Bool {
        self.splitViewController(
            splitViewController,
            show: vc,
            sender: sender
        )
    }
}

// MARK: - UITabBarControllerDelegate

extension ThreemaSplitViewNavigationManager: UITabBarControllerDelegate {
    
    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        /// Store current tab's navigation stack before switching
        storeCurrentViewControllerStack()
        return true
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        /// Restore navigation stack for the newly selected tab
        guard let tabBarController = tabBarController as? ThreemaTabBarController else {
            return
        }
        
        let selectedTab = tabBarController.selectedThreemaTab
        defer { previousSelectedTab = selectedTab }
        
        /// When tapping again on the same tab bar item, the navigation is popped to root.
        /// If that happens and the split view is collapsed, we need to clear up
        /// the stored stack, so it is not incorrectly restored.
        let isTapOnSameTab = previousSelectedTab == selectedTab
        if splitViewController?.isCollapsed == true,
           isTapOnSameTab {
            thetaStack.store(stack: [], for: selectedTab)
        }
        
        restoreViewControllerStack(for: selectedTab)
    }
}
