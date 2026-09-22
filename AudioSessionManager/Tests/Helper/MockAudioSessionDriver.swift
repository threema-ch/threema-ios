import AudioSessionManager
import AVFoundation
import Foundation

/// Records what the manager asked for without touching a real audio session.
public actor MockAudioSessionDriver: AudioSessionDriverProtocol {

    public enum Call: Sendable, Equatable {
        case apply(AudioSessionProfile)
        case deactivate

        /// Recorded separately from `apply` even though `AVAudioSessionDriver` implements one in terms
        /// of the other, so a test can prove the manager took the recovery path and not the ordinary
        /// configure path. For the CallKit driver those are entirely different operations.
        case recoverFromInterruption(AudioSessionProfile)
    }

    /// Every call in the order it arrived. Assert on this rather than on a call count, so a test
    /// that expects "nothing happened" fails with the unexpected call in the message.
    public private(set) var calls: [Call] = []

    private var applyError: (any Error)?

    /// What `currentRoute()` answers. Settable, which is the point of routing the read through the driver:
    /// `outputRouteChanged`'s payload used to come from whatever session the simulator had.
    private var route = AudioSessionRouteSnapshot(outputs: [], hasBluetoothInput: false)

    public init() {
        // no-op
    }

    // MARK: - AudioSessionDriverProtocol

    public func apply(_ profile: AudioSessionProfile) async throws {
        calls.append(.apply(profile))

        if let applyError {
            throw applyError
        }
    }

    public func deactivate() async throws {
        calls.append(.deactivate)
    }

    public func recoverFromInterruption(restoring profile: AudioSessionProfile) async throws {
        calls.append(.recoverFromInterruption(profile))

        if let applyError {
            throw applyError
        }
    }

    /// Deliberately not recorded: the manager asks on every route change, so recording it would make every
    /// route assertion carry noise it does not care about.
    public func currentRoute() async -> AudioSessionRouteSnapshot {
        route
    }

    public func diagnostics() async -> String {
        "mock driver, route=\(route.outputs.map(\.rawValue).joined(separator: "+"))"
    }

    // MARK: - Test control

    /// Forget every recorded call
    public func reset() {
        calls.removeAll()
    }

    /// Make every subsequent `apply(_:)` throw. The call is still recorded first, so a test can
    /// distinguish "was not attempted" from "was attempted and failed".
    public func failApply(with error: any Error = MockAudioSessionDriverError.applyFailed) {
        applyError = error
    }

    /// What the next `currentRoute()` answers.
    public func setRoute(outputs: [AVAudioSession.Port], hasBluetoothInput: Bool = false) {
        route = AudioSessionRouteSnapshot(outputs: outputs, hasBluetoothInput: hasBluetoothInput)
    }
}

public enum MockAudioSessionDriverError: Error, Equatable, Sendable {
    case applyFailed
}

/// Records what the manager forwards for a session someone else activates.
///
/// Separate from `MockAudioSessionDriver` rather than folded into it, because the manager finds this
/// capability by dynamic cast: a test that installs a driver *without* it is the only way to cover the
/// case where activation silently goes nowhere.
public actor MockExternallyActivatedDriver: ExternallyActivatedDriver {

    public enum Call: Sendable, Equatable {
        case apply(AudioSessionProfile)
        case deactivate
        case recoverFromInterruption(AudioSessionProfile)
        case sessionDidActivate
        case sessionDidDeactivate
        case setRecovery(isNil: Bool)
    }

    public private(set) var calls: [Call] = []

    /// What `currentRoute()` answers. Settable, which is the point of routing the read through the driver:
    /// `outputRouteChanged`'s payload used to come from whatever session the simulator had.
    private var route = AudioSessionRouteSnapshot(outputs: [], hasBluetoothInput: false)

    public init() {
        // no-op
    }

    // MARK: - AudioSessionDriverProtocol

    public func apply(_ profile: AudioSessionProfile) async throws {
        calls.append(.apply(profile))
    }

    public func currentRoute() async -> AudioSessionRouteSnapshot {
        route
    }

    public func diagnostics() async -> String {
        "mock driver, route=\(route.outputs.map(\.rawValue).joined(separator: "+"))"
    }

    public func deactivate() async throws {
        calls.append(.deactivate)
    }

    public func recoverFromInterruption(restoring profile: AudioSessionProfile) async throws {
        calls.append(.recoverFromInterruption(profile))
    }

    // MARK: - ExternallyActivatedDriver

    /// `nonisolated`, as in the real driver: the forwarding has to be synchronous. Recording therefore
    /// hops onto the actor, so a test waits on `calls` rather than asserting immediately.
    public nonisolated func sessionDidActivate(_ session: AVAudioSession) {
        Task { await record(.sessionDidActivate) }
    }

    public nonisolated func sessionDidDeactivate(_ session: AVAudioSession) {
        Task { await record(.sessionDidDeactivate) }
    }

    public func setRecovery(_ recovery: (any AudioSessionRecovering)?) async {
        calls.append(.setRecovery(isNil: recovery == nil))
    }

    // MARK: - Test control

    public func reset() {
        calls.removeAll()
    }

    /// What the next `currentRoute()` answers.
    public func setRoute(outputs: [AVAudioSession.Port], hasBluetoothInput: Bool = false) {
        route = AudioSessionRouteSnapshot(outputs: outputs, hasBluetoothInput: hasBluetoothInput)
    }

    /// Wait for `calls` to reach `count`, so the `nonisolated` forwarders can be asserted without sleeps.
    public func waitForCalls(_ count: Int) async -> [Call] {
        while calls.count < count {
            await Task.yield()
        }
        return calls
    }

    private func record(_ call: Call) {
        calls.append(call)
    }
}

/// Builds a **real** `AudioSessionManager` for tests outside this package.
///
/// Named for what it is — a door, not a doubling. Both of `AudioSessionManager`'s initialisers are `package`
/// so that `AudioSessionManagerFactory.make()` is the only way app code can obtain one, which locks tests out
/// too; this lets them through the same door. What comes back arbitrates for real: subordination, the
/// `busyWithCall` refusal, tie-breaking. Only the driver and the notification centre are substituted.
///
/// For a double that records calls instead of arbitrating, see `MockAudioSessionManager` — and prefer this one
/// whenever the behaviour under test derives its meaning from arbitration, because a stub cannot refuse.
///
/// A type rather than an extension on `AudioSessionManager`, for the same reason as
/// `AudioSessionManagerFactory`: an extension member is attributed to the type's own module, so the
/// import of this one would look unused to SwiftFormat's `unusedImports` rule and be stripped.
public enum AudioSessionManagerTestFactory {

    /// A real manager over the drivers you supply, observing nothing and touching no real session.
    public static func make(
        defaultDriver: any AudioSessionDriverProtocol = MockAudioSessionDriver(),
        callDriver: (any ExternallyActivatedDriver)? = nil,
        notificationCenter: NotificationCenter = .default
    ) -> AudioSessionManager {
        AudioSessionManager(
            defaultDriver: defaultDriver,
            callDriver: callDriver,
            notificationCenter: notificationCenter
        )
    }
}
