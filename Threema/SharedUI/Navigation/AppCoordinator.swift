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
    
    // MARK: - Coordinator
    
    weak var parentCoordinator: (any Coordinator)?
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        splitViewController
    }

    private var window: UIWindow
    
    // MARK: - Routers
    
    private lazy var shareActivityRouter: ShareActivityRouting = ShareActivityRouter(
        rootViewController: rootViewController
    )
    private lazy var modalRouter: ModalRouting = ModalRouter(
        rootViewController: rootViewController
    )
    private lazy var passcodeRouter: PasscodeRouting = PasscodeRouter(
        lockScreen: LockScreen(isLockScreenController: false),
        isPasscodeRequired: KKPasscodeLock.shared().isPasscodeRequired(),
        rootViewController: rootViewController
    )
    
    // MARK: - Views
    
    private lazy var splitViewController = ThreemaSplitViewController()
    
    private var tabBarController: ThreemaTabBarController {
        splitViewController.threemaTabBarController
    }
    
    // MARK: - Tabs
    
    private lazy var contactsCoordinator: ContactsCoordinator = {
        let coordinator = ContactsCoordinator(
            presentingViewController: rootViewController
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private lazy var conversationsCoordinator: ConversationsCoordinator = {
        let coordinator = ConversationsCoordinator(
            presentingViewController: rootViewController
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private lazy var profileCoordinator: ProfileCoordinator = {
        let coordinator = ProfileCoordinator(
            presentingViewController: rootViewController,
            shareActivityRouter: shareActivityRouter,
            modalRouter: modalRouter,
            passcodeRouter: passcodeRouter
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private lazy var settingsCoordinator: SettingsCoordinator = {
        let coordinator = SettingsCoordinator(
            presentingViewController: rootViewController,
            shareActivityRouter: shareActivityRouter,
            passcodeRouter: passcodeRouter
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()

    // MARK: - Lifecycle

    @objc init(window: UIWindow) {
        self.window = window
        
        super.init()
        
        /// Because this is init from Objective-C,
        /// `start()` method is called upon init.
        start()
    }
    
    func start() {
        configureSplitViewController()
        
        window.rootViewController = splitViewController
        window.makeKeyAndVisible()
    }
    
    // MARK: - Layout management
    
    private func configureSplitViewController() {
        let navigationThreemaLogoViewController = ThreemaLogoViewControllerFactory.threemaLogoNavigationController
        
        splitViewController.viewControllers = [
            tabBarController,
            navigationThreemaLogoViewController,
        ]
        
        /// For now we keep as is. Ideally, the navigation would already be
        /// part of the rootViewController.
        let viewControllers: [UIViewController] = [
            contactsCoordinator.rootViewController,
            conversationsCoordinator.rootViewController,
            profileCoordinator.rootViewController,
            settingsCoordinator.rootViewController,
        ]
        
        tabBarController.viewControllers = viewControllers
        // We must set the conversations tab as the default. This is because, by default, the selectedIndex is 0, which
        // corresponds to the contact tab.
        tabBarController.selectedIndex = ThreemaTabBarController.TabBarItem.conversations.rawValue
    }
}
