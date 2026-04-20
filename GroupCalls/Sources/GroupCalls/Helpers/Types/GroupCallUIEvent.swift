import Foundation

enum GroupCallUIEvent {
    case joining
    case connecting
    case connected
    case error(GroupCallErrorProtocol)
    case add(ViewModelParticipant)
    case remove(ParticipantID)
    case participantStateChange(ParticipantID, ParticipantStateChange)
    case forceDismissGroupCallViewController
    case videoMuteChange(OwnMuteState)
    case videoCameraChange(CameraPosition)
    case audioMuteChange(OwnMuteState)
}
