//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import CoreData
import Foundation
import UIKit

/// Protocol used to show alerts and view controllers from the GroupCalls package in the Threema-App via the
/// `GlobalGroupCallManagerSingleton`
public protocol GroupCallManagerSingletonUIDelegate: AnyObject {
    /// Tries to present the given `GroupCallViewController`
    /// - Parameter viewController: `GroupCallViewController` to be shown
    func showViewController(_ viewController: GroupCallViewController)
    
    /// Tries to show an alert for a given `GroupCallErrorProtocol`
    /// - Parameter error: `GroupCallErrorProtocol`
    func showAlert(for error: GroupCallErrorProtocol)
    
    /// Shows an alert that the group call is currently full
    /// - Parameter maxParticipants: Optional maximal participant count
    /// - Parameter onOK: Block to be executed when `OK` is pressed
    func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void)
    
    /// Tries to show the incoming group call notification
    /// - Parameters:
    ///   - conversationManagedObjectID: The managed object id of the conversation
    ///   - title: Title of the notification
    ///   - body: Body of the notification
    ///   - contactImage: Image of the group
    ///   - identifier: Identifier to group the notifications
    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        contactImage: UIImage,
        identifier: String
    )
}
