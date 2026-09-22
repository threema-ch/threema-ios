import AudioSessionManager
import Foundation

/// Drives CallKit's hold/unhold cycle on `RTCAudioSessionDriver`'s behalf
final class CallKitAudioSessionRecovery: AudioSessionRecovering, @unchecked Sendable {

    private weak var callKitManager: VoIPCallKitManager?
    private let callID: VoIPCallID

    // MARK: - Lifecycle
    
    init(callKitManager: VoIPCallKitManager, callID: VoIPCallID) {
        self.callKitManager = callKitManager
        self.callID = callID
    }

    // MARK: - Internal functions
    
    func requestAudioSessionReactivation() async {
        await MainActor.run {
            callKitManager?.requestAudioSessionReactivation(for: callID)
        }
    }
}
