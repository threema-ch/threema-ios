//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import UIKit

final class ThreemaSplitViewNavigationManager: NSObject {
    
    // MARK: - Private properties
    
    private(set) lazy var thetaStack = ThetaStack()
    private weak var splitViewController: ThreemaSplitViewController?
    private weak var tabBarController: ThreemaTabBarController?
    private var previousSelectedTabIdentifier: ThreemaTabBarController.TabBarItem?
    
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
    
    private func storeViewControllerStack(for tabIdentifier: ThreemaTabBarController.TabBarItem) {
        let viewControllersToStore = currentNavigationStack(for: tabIdentifier)
        thetaStack.store(stack: viewControllersToStore, for: tabIdentifier)
    }
    
    private func currentNavigationStack(for tabIdentifier: ThreemaTabBarController.TabBarItem) -> [UIViewController] {
        /// If this is the currently selected tab, get the current navigation state
        if tabIdentifier == tabBarController?.selectedTabIdentifier {
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
        return thetaStack.restore(for: tabIdentifier)
    }
    
    private func storeCurrentViewControllerStack() {
        guard let currentTabIdentifier = tabBarController?.selectedTabIdentifier else {
            return
        }
        
        storeViewControllerStack(for: currentTabIdentifier)
    }
    
    private func restoreViewControllerStack(for tabIdentifier: ThreemaTabBarController.TabBarItem) {
        let savedStack = thetaStack.restore(for: tabIdentifier)
        let filteredStack = savedStack.filter { !($0 is ThreemaLogoViewController) }
        
        replaceNavigationStack(filteredStack, for: tabIdentifier)
    }
    
    private func replaceNavigationStack(
        _ controllers: [UIViewController],
        for tabIdentifier: ThreemaTabBarController.TabBarItem
    ) {
        /// Only restore to UI if this is the currently selected tab
        guard tabIdentifier == tabBarController?.selectedTabIdentifier else {
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
            let currentTabIdentifier = tabBarController.selectedTabIdentifier
            let viewControllersToStore = secondaryNavigationController.viewControllers
                .filter { !($0 is ThreemaLogoViewController) }
            thetaStack.store(stack: viewControllersToStore, for: currentTabIdentifier)
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
            return ThreemaLogoViewControllerFactory.threemaLogoNavigationController
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
        let selectedTabIdentifier = tabBarController.selectedTabIdentifier
        
        let savedStack = thetaStack.restore(for: selectedTabIdentifier)
        let filteredStack = savedStack.filter { !($0 is ThreemaLogoViewController) }
        
        let secondaryNavigationController: UINavigationController
        if !filteredStack.isEmpty {
            secondaryNavigationController = UINavigationController()
            secondaryNavigationController.viewControllers = filteredStack
        }
        else {
            secondaryNavigationController = ThreemaLogoViewControllerFactory.threemaLogoNavigationController
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
        
        let selectedTabIdentifier = tabBarController.selectedTabIdentifier
        defer { previousSelectedTabIdentifier = selectedTabIdentifier }
        
        /// When tapping again on the same tab bar item, the navigation is popped to root.
        /// If that happens and the split view is collapsed, we need to clear up
        /// the stored stack, so it is not incorrectly restored.
        let isTapOnSameTab = previousSelectedTabIdentifier == selectedTabIdentifier
        if splitViewController?.isCollapsed == true,
           isTapOnSameTab {
            thetaStack.store(stack: [], for: selectedTabIdentifier)
        }
        
        restoreViewControllerStack(for: selectedTabIdentifier)
    }
}
