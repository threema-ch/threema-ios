import AudioSessionManager
import AVFoundation
import Foundation

/// Records what a client asked of the audio session owner, without arbitrating.
///
/// **Read this before reaching for it.** It grants every claim. It does not subordinate, does not refuse
/// `.recording` during a call, and does not resolve competing claims — so it will make a test pass wherever
/// production would have refused. Several client behaviours are *defined* by arbitration ("fail loudly when a
/// call owns the microphone" is a feature, not an implementation detail), and for those, use
/// `AudioSessionManagerTestFactory.make()`, which hands back the real manager over `MockAudioSessionDriver`.
///
/// Use this one for a client's own logic: that it acquires at the right moment, releases on every teardown
/// path, asks for the route the proximity sensor implies, and stops capturing when told it was interrupted.
///
/// A `final class` over an `NSLock` rather than an actor, deliberately. Two of the protocol's requirements are
/// `nonisolated`, so an actor would have to record them by hopping (`Task { await record(…) }`) and the
/// recorded order would no longer be the call order — the flaw `MockExternallyActivatedDriver` carries. A lock
/// records synchronously, in order, and witnesses the `async` requirements with plain methods.
public final class MockAudioSessionManager: AudioSessionManagerProtocol, @unchecked Sendable {

    public enum Call: Sendable, Equatable {
        case acquire(AudioSessionClientKind, AudioSessionOutput)
        case update(AudioSessionClaim, AudioSessionOutput)
        case release(AudioSessionClaim)
        case events(AudioSessionClaim)
        case setRecovery(AudioSessionClaim)
        case sessionWasActivatedExternally
        case sessionWasDeactivatedExternally
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private var acquireError: (any Error)?
    /// Ordered, so `outstandingKinds` can be asserted as a sequence. A dictionary would not be.
    private var granted: [(id: UUID, kind: AudioSessionClientKind)] = []
    private var continuations: [UUID: AsyncStream<AudioSessionEvent>.Continuation] = [:]
    private var route = AudioSessionRouteSnapshot(outputs: [], hasBluetoothInput: false)

    // MARK: - Lifecycle

    public init() {
        // no-op
    }

    // MARK: - Inspection

    /// Every call in the order it arrived. Assert on this rather than on a count, so a test that expects
    /// "nothing happened" fails with the unexpected call in the message.
    public var calls: [Call] {
        lock.withLock { recorded }
    }

    /// The kinds of the claims granted and not yet released, oldest first.
    ///
    /// This is what a client test should assert on. A profile is not the client's contract — it belongs to
    /// `AudioSessionClientKind` and will move when a kind is added.
    public var outstandingKinds: [AudioSessionClientKind] {
        lock.withLock { granted.map(\.kind) }
    }

    // MARK: - Test control

    /// Make every subsequent `acquire(_:)` throw. The call is still recorded first, so a test can tell
    /// "was not attempted" from "was attempted and refused".
    public func failAcquire(with error: any Error = AudioSessionError.busyWithCall) {
        lock.withLock { acquireError = error }
    }

    /// Deliver an event to every open stream.
    ///
    /// Broadcast rather than per claim, because that is what the real manager's `emit` does: the events are
    /// session-wide facts, and a double that scoped them would let a test pass on behaviour production does
    /// not have.
    public func send(_ event: AudioSessionEvent) {
        let targets = lock.withLock { Array(continuations.values) }

        for continuation in targets {
            continuation.yield(event)
        }
    }

    /// What the next `currentRoute()` answers, so a client's route decision can be driven.
    public func setRoute(outputs: [AVAudioSession.Port], hasBluetoothInput: Bool = false) {
        lock.withLock {
            route = AudioSessionRouteSnapshot(outputs: outputs, hasBluetoothInput: hasBluetoothInput)
        }
    }

    public func reset() {
        lock.withLock { recorded.removeAll() }
    }

    // MARK: - AudioSessionManagerProtocol

    public func acquire(
        _ kind: AudioSessionClientKind,
        output: AudioSessionOutput
    ) async throws -> AudioSessionClaim {
        let claim = AudioSessionClaim(kind: kind)

        let error: (any Error)? = lock.withLock {
            recorded.append(.acquire(kind, output))

            guard acquireError == nil else {
                return acquireError
            }

            granted.append((claim.id, kind))
            return nil
        }

        if let error {
            throw error
        }

        return claim
    }

    public func update(_ claim: AudioSessionClaim, output: AudioSessionOutput) async {
        lock.withLock { recorded.append(.update(claim, output)) }
    }

    public func release(_ claim: AudioSessionClaim) async {
        let continuation = lock.withLock {
            recorded.append(.release(claim))
            granted.removeAll { $0.id == claim.id }
            return continuations.removeValue(forKey: claim.id)
        }

        // As the real manager does: releasing finishes the claim's stream, which ends the client's loop.
        continuation?.finish()
    }

    public func events(for claim: AudioSessionClaim) async -> AsyncStream<AudioSessionEvent> {
        let (stream, continuation) = AsyncStream<AudioSessionEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(4)
        )

        // The previous stream for this claim is finished outside the lock, as in `release(_:)`: `finish()`
        // resumes a consumer, and a consumer resuming into this mock must not meet a lock it already holds.
        let replaced = lock.withLock {
            recorded.append(.events(claim))
            return continuations.updateValue(continuation, forKey: claim.id)
        }
        replaced?.finish()

        return stream
    }

    public func currentRoute() async -> AudioSessionRouteSnapshot {
        lock.withLock { route }
    }

    public func diagnostics() async -> String {
        "mock manager, outstanding=\(outstandingKinds.map(String.init(describing:)).joined(separator: "+"))"
    }

    public func setRecovery(_ recovery: any AudioSessionRecovering, for claim: AudioSessionClaim) async {
        lock.withLock { recorded.append(.setRecovery(claim)) }
    }

    public func sessionWasActivatedExternally(_ session: AVAudioSession) {
        lock.withLock { recorded.append(.sessionWasActivatedExternally) }
    }

    public func sessionWasDeactivatedExternally(_ session: AVAudioSession) {
        lock.withLock { recorded.append(.sessionWasDeactivatedExternally) }
    }
}
