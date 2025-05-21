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

public protocol Coordinator<CoordinatorDestination>: AnyObject {
   
    associatedtype CoordinatorDestination
    
    // MARK: - Properties
    
    /// Collection of child coordinators to keep track of
    var childCoordinators: [any Coordinator] { get set }
    
    func rootViewController() -> UIViewController
    
    // MARK: -  Presentation
    
    /// Pass `Destinations` that cannot be handled by the current coodrinator to parent coordinator using this functions
    /// - Parameter destination: `Destination` to be handled by parent
    func show(_ destination: Destination)
    
    /// Call this function to pass a `Destination` to be handled by the respective coordinator
    /// - Parameter destination: `Destination` to be handled by the coordinator
    func show(_ destination: CoordinatorDestination)
    
    /// Use this function to pass a created `UIViewController` to a parent coordinator that knows how to correclty show
    /// it
    /// - Parameters:
    ///   - viewController: `UIViewController` to be shown
    ///   - style: `CordinatorNavigationStyle` to be used
    func show(_ viewController: UIViewController, style: CordinatorNavigationStyle)
    
    /// Use this function to pass a created `UIViewController` to a parent coordinator that knows how to correclty show
    /// it
    /// - Parameters:
    ///   - items: Items to be forwarded to `UIActivityViewController`
    ///   - sourceView: `UIView` acting as popover source
    func shareActivity(_ items: [Any], sourceView: UIView?)
    
    /// Use this function to dismiss the currently presented modal
    func dismiss()
}

extension Coordinator {
    public func show(_ vc: UIViewController) {
        show(vc, style: .show)
    }
    
    /// Removes the given `Coordinator` from it's parents child coordinators
    /// - Parameter child: Child to be removed
    public func childDidFinish(_ child: any Coordinator) {
        childCoordinators.removeAll {
            $0 === child
        }
    }
}
