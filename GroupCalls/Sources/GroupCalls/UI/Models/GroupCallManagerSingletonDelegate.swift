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
