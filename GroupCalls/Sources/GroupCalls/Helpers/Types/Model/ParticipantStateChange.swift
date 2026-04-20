import Foundation

enum ParticipantStateChange {
    case audioState(MuteState)
    case videoState(MuteState)
    case screenState(MuteState)
}
