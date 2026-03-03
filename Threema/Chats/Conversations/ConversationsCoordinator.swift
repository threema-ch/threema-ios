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

final class ConversationsCoordinator: Coordinator, CurrentDestinationHolding {
    
    // MARK: Internal destination
    
    enum InternalDestination: Equatable {
        case todo
    }
    
    // MARK: - Coordinator
    
    var childCoordinators = [any Coordinator]()
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    var currentDestination: InternalDestination?
    
    private lazy var conversationsViewController: ConversationsViewController = {
        let conversationsViewController = ConversationsViewController()
        
        let tabBarItem = ThreemaTabBarController.TabBarItem(.conversations)
        conversationsViewController.tabBarItem = tabBarItem.uiTabBarItem
        conversationsViewController.title = tabBarItem.title
        
        return conversationsViewController
    }()
    
    private lazy var rootNavigationController = UINavigationController()
        
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: conversationsViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    private weak var presentingViewController: UIViewController?
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }
    
    // MARK: - Presentation
    
    func start() {
        rootNavigationController.delegate = navigationDestinationResetter
        
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [conversationsViewController],
            animated: false
        )
    }
    
    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }
        currentDestination = destination

        presentingViewController?.show(
            rootNavigationController,
            sender: self
        )
    }
}
