import Foundation
import ThreemaEssentials
import ThreemaProtocols

/// Protocol that allows delegation from the `GroupCallManager` to the `GlobalGroupCallManagerSingleton`
public protocol GroupCallManagerSingletonDelegate: AnyObject {
    /// Tries to present the given `GroupCallViewController`
    /// - Parameter viewController: `GroupCallViewController` to be shown
    nonisolated func showGroupCallViewController(viewController: GroupCallViewController)
    
    /// Used to provide `GroupCallBannerButtonUpdate`s to the UI-elements
    /// - Parameter groupCallBannerButtonUpdate: `GroupCallBannerButtonUpdate` containing the update info
    nonisolated func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCallBannerButtonUpdate)

    /// Called when the local user is no longer participating in a group call of the given group
    ///
    /// This is independent of whether the call itself is still running with other participants.
    /// - Parameter groupIdentity: Identity of the group whose call the local user left
    nonisolated func localUserLeftGroupCall(in groupIdentity: GroupIdentity)
    
    func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws
    
    /// Used to show a notification for the new incoming group call
    /// - Parameters:
    ///   - groupModel: GroupCallThreemaGroupModel
    ///   - senderThreemaID: The threema id of the sender
    nonisolated func showIncomingGroupCallNotification(
        groupModel: GroupCallThreemaGroupModel,
        senderThreemaID: ThreemaIdentity
    )
    
    /// Shows an alert that the group call is currently full
    /// - Parameter maxParticipants: Optional maximal participant count
    /// - Parameter onOK: Block to be executed when `OK` is pressed
    nonisolated func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void)
}
