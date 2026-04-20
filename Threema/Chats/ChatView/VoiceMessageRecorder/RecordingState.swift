import Foundation

/// States of a recording session.
enum RecordingState {
   
    /// No recording is currently active.
    case ready
    
    // MARK: - Recording

    case recording
    case stopped
    
    // MARK: - Playback
    
    /// Playback of a recording is currently in progress.
    case playing
    /// Playback of a recording is paused.
    case paused
    
    /// Indicating whether the recording has been stopped, either explicitly or by pausing or ending playback.
    var recordingStopped: Bool {
        switch self {
        case .paused, .playing, .stopped:
            true
        default:
            false
        }
    }
}
