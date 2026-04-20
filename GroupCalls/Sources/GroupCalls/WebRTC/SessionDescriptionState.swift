import Foundation

@GlobalGroupCallActor
final class SessionDescriptionState: Sendable {
    var version: UInt64
    let localParticipantID: ParticipantID
    var mLineOrder = [ParticipantID]()
    
    init(version: UInt64, localParticipantID: ParticipantID) {
        self.version = version
        self.localParticipantID = localParticipantID
        mLineOrder.append(localParticipantID)
    }
}
