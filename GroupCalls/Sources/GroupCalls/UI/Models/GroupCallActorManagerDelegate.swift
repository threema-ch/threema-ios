import Foundation
import ThreemaEssentials
import ThreemaProtocols

/// Protocol that allows delegation from the `GroupCallActor` to the `GroupCallManager`
protocol GroupCallActorManagerDelegate: AnyObject {
    /// Used to provide `GroupCallBannerButtonUpdate`s to the UI-elements via the `GroupCallManager`
    /// - Parameter groupCallBannerButtonUpdate: `GroupCallBannerButtonUpdate` containing the update info
    func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCallBannerButtonUpdate) async
    
    /// Handles the given `WrappedGroupCallStartMessage`
    /// - Parameter wrappedMessage: `WrappedGroupCallStartMessage`
    func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws
    
    /// Adds an `GroupCallActor` to the currently running group calls
    /// - Parameter groupCall: `GroupCallActor` to keep track off
    func addToRunningGroupCalls(groupCall: GroupCallActor) async
    
    /// Removes an `GroupCallActor` from the currently running group calls
    /// - Parameter groupCall: `GroupCallActor` to remove
    func removeFromRunningGroupCalls(groupCall: GroupCallActor) async
    
    /// Starts and runs the refresh steps
    func startRefreshSteps() async
    
    /// Runs the Periodic Refresh-Steps for the group with the given identity.
    /// - Parameter group: GroupIdentity of group to run Refresh-Steps for
    func refreshGroupCalls(in group: GroupIdentity) async
    
    /// Shows an alert that the group call is currently full
    /// - Parameter maxParticipants: Optional maximal participant count
    func showGroupCallFullAlert(maxParticipants: Int?) async
}
