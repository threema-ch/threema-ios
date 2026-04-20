import Foundation

enum MuteState {
    case muted
    case unmuted
}

enum OwnMuteState {
    case changing
    case muted
    case unmuted
    
    func muteState() -> MuteState {
        switch self {
        case .changing, .muted:
            .muted
        case .unmuted:
            .unmuted
        }
    }
}
