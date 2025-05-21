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

import Coordinator
import Foundation
import SwiftUI

@objc final class AppCoordinator: NSObject, Coordinator {
    
    // MARK: - Internal destination
    
    // To please the compiler, we add an internal destination.
    typealias CoordinatorDestination = InternalDestination
    
    enum InternalDestination: Equatable {
        case none
    }
    
    // MARK: - Coordinator
    
    weak var parentCoordinator: (any Coordinator)?
    var childCoordinators: [any Coordinator] = []

    private var window: UIWindow
    private lazy var lockScreen = LockScreen(isLockScreenController: false)
    
    // MARK: - Views
    
    private lazy var tabBarController = TabBarController(coordinator: self)
    private lazy var splitViewController = MainSplitViewController(
        coordinator: self,
        tabBarController: tabBarController
    )
    
    private var currentModalNavigationController: UINavigationController?
    
    // MARK: - Tabs
    
    private lazy var settingsCoordinator1 = SettingsCoordinator(parentCoodinator: self)
    private lazy var contactsTabHelper = TabNavigationHelper(
        destination: .contacts,
        coordinator: settingsCoordinator1
    )
    
    private lazy var settingsCoordinator2 = SettingsCoordinator(parentCoodinator: self)
    private lazy var conversationsTabHelper = TabNavigationHelper(
        destination: .conversations,
        coordinator: settingsCoordinator2
    )
    
    private lazy var profileCoordinator = ProfileCoordinator(parentCoodinator: self)
    private lazy var profileTabHelper = TabNavigationHelper(
        destination: .profile,
        coordinator: profileCoordinator
    )
    
    private lazy var settingsCoordinator = SettingsCoordinator(parentCoodinator: self)
    private lazy var settingsTabHelper = TabNavigationHelper(
        destination: .settings,
        coordinator: settingsCoordinator
    )
    
    // MARK: - State
    
    // This property gets updated by the `SplitViewController` since we do not have a view to observe
    var horizontalSizeClass: UIUserInterfaceSizeClass {
        didSet {
            guard oldValue != horizontalSizeClass else {
                return
            }
            horizontalSizeClassDidChange()
        }
    }
    
    private(set) var currentTab: TabBarController.TabBarItem = .profile

    // MARK: - Lifecycle

    @objc init(window: UIWindow) {
        self.window = window
        self.horizontalSizeClass = .unspecified
        
        super.init()
        
        configure()
    }
    
    private func configure() {
        window.rootViewController = splitViewController
        window.makeKeyAndVisible()
    }
    
    func rootViewController() -> UIViewController {
        splitViewController
    }
    
    // MARK: - Layout management
    
    private func horizontalSizeClassDidChange() {
        adaptChildCoordinators()
        horizontalSizeClass == .regular ? presentRegularLayout() : presentCompactLayout()
    }
    
    /// Prepares the navigation controllers and their view controller stacks for a size class change
    private func adaptChildCoordinators() {
        // Call changes to VC's before changing the navigation controllers to prevent crashes.
        
        contactsTabHelper.adaptNavigationControllers(for: horizontalSizeClass)
        conversationsTabHelper.adaptNavigationControllers(for: horizontalSizeClass)
        
        profileCoordinator.horizontalSizeClass = horizontalSizeClass
        profileTabHelper.adaptNavigationControllers(for: horizontalSizeClass)
        
        settingsCoordinator.horizontalSizeClass = horizontalSizeClass
        settingsTabHelper.adaptNavigationControllers(for: horizontalSizeClass)
    }
    
    private func presentCompactLayout() {
        tabBarController.viewControllers = [
            contactsTabHelper.primaryNavigationController,
            conversationsTabHelper.primaryNavigationController,
            profileTabHelper.primaryNavigationController,
            settingsTabHelper.primaryNavigationController,
        ]
        
        tabBarController.selectedIndex = currentTab.rawValue
    }
    
    private func presentRegularLayout() {
        let tabNavigationHelper = tabNavigationHelperForCurrentTab()
        splitViewController.setViewController(tabNavigationHelper.primaryNavigationController, for: .supplementary)
        splitViewController.setViewController(tabNavigationHelper.detailNavigationController, for: .secondary)
    }
        
    // MARK: - Presentation
    
    func swichtTab(to tab: TabBarController.TabBarItem) {
        guard currentTab != tab else {
            return
        }
        
        currentTab = tab
        
        if horizontalSizeClass == .regular {
            // Update maintabbar selection
            splitViewController.updateSelection()
            
            // Set view controllers
            presentRegularLayout()
        }
        else {
            // Update sidebar selection
            splitViewController.updateSelection()
        }
    }
    
    public func show(_ destination: Destination) {
        switch destination {
        case let .app(appDestination):
            // show(appDestination)
            return
        }
    }
    
    public func show(_ destination: InternalDestination) {
        assertionFailure("The app coordinator does not support internal destinations.")
    }
    
    func show(_ destination: Destination.AppDestination) {
        let tab = TabBarController.TabBarItem(destination)
        swichtTab(to: tab)
    }
    
    func show(_ viewController: UIViewController, style: CordinatorNavigationStyle) {
        splitViewController.hide(.primary)
        
        let tabNavigationHelper = tabNavigationHelperForCurrentTab()
        
        switch style {
        case .show:
            if horizontalSizeClass == .regular {
                tabNavigationHelper.detailNavigationController.viewControllers.removeAll()
                tabNavigationHelper.detailNavigationController.pushViewController(viewController, animated: true)
            }
            else {
                tabNavigationHelper.primaryNavigationController.pushViewController(viewController, animated: true)
            }
            
        case let .modal(style, transition):
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = style
            navigationController.modalTransitionStyle = transition
            currentModalNavigationController = navigationController
            tabNavigationHelper.primaryNavigationController.present(navigationController, animated: true)
            
        case let .passcode(style):
            guard KKPasscodeLock.shared().isPasscodeRequired() else {
                show(viewController, style: style)
                return
            }
            
            let parentVCforLockScreen: UIViewController =
                if horizontalSizeClass == .regular {
                    tabNavigationHelper.detailNavigationController
                }
                else {
                    tabNavigationHelper.primaryNavigationController
                }
            
            lockScreen.presentLockScreenView(viewController: parentVCforLockScreen, enteredCorrectly: { [weak self] in
                self?.show(viewController, style: style)
            })
        }
    }
    
    func shareActivity(_ items: [Any], sourceView: UIView?) {
        let tabNavigationHelper = tabNavigationHelperForCurrentTab()
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = sourceView
        tabNavigationHelper.primaryNavigationController.present(activityViewController, animated: true)
    }
    
    func dismiss() {
        currentModalNavigationController?.dismiss(animated: true)
        currentModalNavigationController = nil
    }
    
    // MARK: - Helpers
    
    private func tabNavigationHelperForCurrentTab() -> TabNavigationHelper {
        switch currentTab {
        case .contacts:
            contactsTabHelper
        case .conversations:
            conversationsTabHelper
        case .profile:
            profileTabHelper
        case .settings:
            settingsTabHelper
        }
    }
}
