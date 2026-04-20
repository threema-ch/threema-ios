import ThreemaFramework
import ThreemaMacros

enum VoiceMessageError: Error {
    // Audio Session
    case exportFailed
   
    // Audio Recording
    case recordingStartFailed
    case assetNotFound
    
    // File operations
    case fileOperationFailed
    case loadDraftFailed
}
