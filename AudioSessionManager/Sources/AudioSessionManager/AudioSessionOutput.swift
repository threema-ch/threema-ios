import AVFoundation

/// Where a client wants audio to come out.
public enum AudioSessionOutput: Sendable, Equatable {
    /// Whatever the system selects.
    case system

    /// Force the built-in speaker.
    case speaker

    /// Force the built-in earpiece, for a client that follows the proximity sensor.
    case receiver
}
