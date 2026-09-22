import CoreData
import Foundation
import ThreemaEssentials
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

    /// Called when the local user is no longer participating in a group call of the given group
    ///
    /// This is independent of whether the call itself is still running with other participants.
    /// - Parameter groupIdentity: Identity of the group whose call the local user left
    func localUserLeftGroupCall(in groupIdentity: GroupIdentity)
    
    /// Shows an alert that the group call is currently full
    /// - Parameter maxParticipants: Optional maximal participant count
    /// - Parameter onOK: Block to be executed when `OK` is pressed
    func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void)
    
    /// Tries to show the incoming group call notification
    /// - Parameters:
    ///   - conversationManagedObjectID: The managed object id of the conversation
    ///   - title: Title of the notification
    ///   - body: Body of the notification
    ///   - identifier: Identifier to group the notifications
    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    )
}
