import AVFoundation

/// What the app can ask of the audio session owner: acquire a claim, adjust its route, give it back, hear what
/// happens to the session meanwhile, and — for CallKit — forward an activation performed by someone else.
public protocol AudioSessionManagerProtocol: Sendable {

    /// Register what this client needs and resolve it against the existing claims.
    ///
    /// - Parameter output: the route this client wants. Named here rather than left to a follow-up
    ///   `update(_:output:)` so a client that already knows it — a call answered on speaker, a voice message
    ///   started with the phone at the ear — costs one apply instead of two.
    /// - Throws: `AudioSessionError.busyWithCall` if `kind` is `.recording` while a call holds a claim. Every
    ///   other kind is granted, possibly as a subordinate.
    func acquire(
        _ kind: AudioSessionClientKind,
        output: AudioSessionOutput
    ) async throws -> AudioSessionClaim

    /// Change the route this claim is asking for. A no-op while the claim is subordinate.
    func update(_ claim: AudioSessionClaim, output: AudioSessionOutput) async

    /// Give up this claim. Releasing an unknown or already-released claim does nothing.
    func release(_ claim: AudioSessionClaim) async

    /// A one-line description of what the session is doing, for a log. Driver-answered, so a call reports
    /// WebRTC's activation flags too.
    func diagnostics() async -> String

    /// Where audio is going right now, and whether a Bluetooth input is available to move it to.
    func currentRoute() async -> AudioSessionRouteSnapshot

    /// Events affecting the session this claim was granted against. Finishes when the claim is released.
    func events(for claim: AudioSessionClaim) async -> AsyncStream<AudioSessionEvent>

    /// Supply how the session held by `claim` gets reactivated after an interruption.
    func setRecovery(_ recovery: any AudioSessionRecovering, for claim: AudioSessionClaim) async

    /// Tell the `.call` driver that its session has been activated for it.
    ///
    /// `nonisolated`, and must stay so: `provider(_:didActivate:)` must not return before WebRTC has observed
    /// the activation, and `AVAudioSession` is not `Sendable`, so it cannot cross into an actor at all.
    nonisolated func sessionWasActivatedExternally(_ session: AVAudioSession)

    /// Tell the `.call` driver that its session has been deactivated.
    nonisolated func sessionWasDeactivatedExternally(_ session: AVAudioSession)
}

extension AudioSessionManagerProtocol {

    /// Acquire on whatever route the system selects. Here to provide a default value for `output`.
    public func acquire(_ kind: AudioSessionClientKind) async throws -> AudioSessionClaim {
        try await acquire(kind, output: .system)
    }
}
