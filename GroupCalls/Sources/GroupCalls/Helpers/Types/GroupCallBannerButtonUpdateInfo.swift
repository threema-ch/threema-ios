import Foundation
import ThreemaEssentials

public struct GroupCallBannerButtonUpdate: Sendable {
    public let groupIdentity: GroupIdentity
    public let numberOfParticipants: Int
    // TODO: (IOS-4074) Make optional and possibly hide label in banner?
    public let startDate: Date
    public let joinState: GroupCallJoinState
    public let hideComponent: Bool
    
    init(actor: GroupCallActor, hideComponent: Bool) async {
        self.groupIdentity = actor.group.groupIdentity
        self.numberOfParticipants = await actor.numberOfJoinedParticipants()
        self.startDate = await actor.callStartDate()
        self.joinState = await actor.joinState()
        self.hideComponent = hideComponent
    }
}
