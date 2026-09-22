/// Applies a resolved profile to a real audio session, and provides information about it.
///
/// This is the only seam through which the process-wide session is acessed. Nothing
/// else, the manager included, is permitted to call `AVAudioSession` or `RTCAudioSession` directly.
///
/// Conformers are expected to be actors. The manager serializes its own decisions, but a driver
/// holds the process singleton, so it must serialize its own access rather than relying on the
/// caller's isolation.
public protocol AudioSessionDriverProtocol: AnyObject, Sendable {
    /// Configure and activate the session for `profile`.
    func apply(_ profile: AudioSessionProfile) async throws

    /// Hand the session back.
    func deactivate() async throws

    /// Restore the session after a system interruption ended.
    func recoverFromInterruption(restoring profile: AudioSessionProfile) async throws

    /// A one-line description of the session's live state, for logs.
    func diagnostics() async -> String

    /// The route the session is on right now.
    func currentRoute() async -> AudioSessionRouteSnapshot
}
