import Foundation

/// Note: Yielding these states only leads to actions once the group call is in the "Connected" state. This is a flaw
/// in the current design. See IOS-5685.
enum GroupCallUIAction: Equatable {
    case none
    
    // Local Participant
    case leave
    
    case muteVideo
    case unmuteVideo(CameraPosition)
    case switchCamera(CameraPosition)

    case muteAudio
    case unmuteAudio
    
    // Remote Participant
    case subscribeVideo(ParticipantID)
    case unsubscribeVideo(ParticipantID)
}
