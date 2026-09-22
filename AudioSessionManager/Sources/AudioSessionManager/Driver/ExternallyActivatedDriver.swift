import AVFoundation

/// A driver for a session someone else activates — e.g. for CallKit, the system.
public protocol ExternallyActivatedDriver: AudioSessionDriverProtocol {

    /// Forward the activation. Must be synchronous: whoever owns the session expects the driver to have
    /// observed it by the time their callback returns.
    nonisolated func sessionDidActivate(_ session: AVAudioSession)

    /// Forward the deactivation.
    nonisolated func sessionDidDeactivate(_ session: AVAudioSession)

    /// How to get the session reactivated after an interruption. `nil` clears it.
    func setRecovery(_ recovery: (any AudioSessionRecovering)?) async
}
