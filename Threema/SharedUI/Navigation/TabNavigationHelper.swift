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
import UIKit

/// This class helps us replacing `UINavigationController`s and moving `UIViewController`s between them, when the
/// horizontal size class changes.
/// This allows us to keep the view controllers and the navigation hierarchy.
class TabNavigationHelper {
    private(set) var primaryNavigationController: UINavigationController {
        didSet {
            setNavigationTitle()
        }
    }
    
    private(set) var detailNavigationController = UINavigationController()
    
    private let destination: Destination.AppDestination
    private var navigationDelegate: UINavigationControllerDelegate?
    
    // MARK: - Lifecycle
    
    init(destination: Destination.AppDestination, coordinator: any Coordinator) {
        self.destination = destination
        
        self.primaryNavigationController = UINavigationController(rootViewController: coordinator.rootViewController())
        
        if let navigationDelegeate = coordinator as? UINavigationControllerDelegate {
            self.navigationDelegate = navigationDelegeate
        }
        
        self.detailNavigationController = UINavigationController()
    }
    
    // MARK: - Public functions
    
    func adaptNavigationControllers(for sizeClass: UIUserInterfaceSizeClass) {
        if sizeClass == .regular {
            // We separate the navigation stack for a splitview layout
            var viewControllers = primaryNavigationController.viewControllers
            let supplementaryVC = viewControllers.removeFirst()
            
            primaryNavigationController.viewControllers = [supplementaryVC]
            detailNavigationController.viewControllers = viewControllers
        }
        else {
            // We combine the navigation controllers for compact layout
            primaryNavigationController.viewControllers = primaryNavigationController
                .viewControllers + detailNavigationController.viewControllers
            detailNavigationController.viewControllers = []
        }
        
        replaceNavigationController()
    }
    
    // MARK: - Private functions
    
    /// We replace the navigation controller to not mess up moving them between the split view and the tab bar
    private func replaceNavigationController() {
        let primaryNavC = UINavigationController()
        let primaryVCs = primaryNavigationController.viewControllers
        primaryNavC.setViewControllers(primaryVCs, animated: false)
        primaryNavigationController = primaryNavC
        primaryNavigationController.delegate = navigationDelegate
        
        let detailNavC = UINavigationController()
        let detailVCs = detailNavigationController.viewControllers
        detailNavC.setViewControllers(detailVCs, animated: false)
        detailNavigationController = detailNavC
    }
    
    private func setNavigationTitle() {
        let item = TabBarController.TabBarItem(destination)
        primaryNavigationController.tabBarItem = item.uiTabBarItem
        primaryNavigationController.viewControllers.first?.title = item.title
    }
}
