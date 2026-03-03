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

public protocol Coordinator: AnyObject {
    
    // MARK: - Properties
    
    /// Collection of child coordinators to keep track of
    var childCoordinators: [any Coordinator] { get set }
    
    var rootViewController: UIViewController { get }
    
    // MARK: -  Presentation
    
    /// Initiates the coordinator's flow by creating and presenting its initial view controller.
    ///
    /// This method serves as the entry point for the coordinator, responsible for:
    /// - Instantiating the first view controller in the flow
    /// - Configuring the view controller with necessary dependencies
    /// - Presenting or pushing the view controller onto the navigation stack
    ///
    /// Call this method when you want to begin the coordinator's managed flow.
    ///
    /// - Note: This method should be called only once per coordinator lifecycle to avoid
    ///         duplicate presentations.
    ///
    /// Example:
    /// ```swift
    /// let coordinator = LoginCoordinator(navigationController: navController)
    /// // Begins the login flow
    /// coordinator.start()
    /// ```
    func start()
}

extension Coordinator {
    /// Removes the given `Coordinator` from it's parents child coordinators
    /// - Parameter child: Child to be removed
    public func childDidFinish(_ child: any Coordinator) {
        childCoordinators.removeAll {
            $0 === child
        }
    }
}
