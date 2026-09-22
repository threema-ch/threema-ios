import AVFoundation

/// Something that happened to the session a claim was granted against.
public enum AudioSessionEvent: Sendable, Equatable {

    /// The system took the session away.
    case interrupted

    /// This claim was the winner and is not any more: something higher-priority took the session.
    case subordinated

    /// The interruption ended.
    ///
    /// - Parameter shouldResume: the system's hint, from `AVAudioSession.InterruptionOptions`
    case interruptionEnded(shouldResume: Bool)

    /// The output route changed.
    case outputRouteChanged(
        reason: AVAudioSession.RouteChangeReason,
        route: AudioSessionRouteSnapshot
    )
}
