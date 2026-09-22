import AVFoundation
import CocoaLumberjackSwift
import Foundation
import NotificationCenter

/// The single owner of the process-wide audio session.
///
/// Clients do not configure anything. They acquire a claim describing what they need, and this type
/// resolves competing claims by `AudioSessionClientKind` and hands the winner to a driver exactly
/// once. Two properties matter more than the rest:
///
/// - A lower-priority claim is granted but subordinate, e.g. playing a voice message during a call
///   still plays; it simply does not reconfigure the session.
public actor AudioSessionManager: AudioSessionManagerProtocol {

    // MARK: - Types

    private struct Registration {
        /// The claim this was granted for, so `applyWinner()` can tell one claim it stopped winning.
        let id: UUID
        let kind: AudioSessionClientKind
        let sequence: UInt64
        var profile: AudioSessionProfile
    }
    
    /// What a system notification turned out to be, extracted before it crosses into the actor.
    private enum SystemEvent: Sendable {
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        case routeChanged(reason: AVAudioSession.RouteChangeReason)
    }

    /// Makes the observer token storable as `Sendable` actor state.
    private final class ObserverToken: @unchecked Sendable {
        let value: any NSObjectProtocol

        init(_ value: any NSObjectProtocol) {
            self.value = value
        }
    }

    // MARK: - Package properties used for testing
    
    /// **Used for testing only**
    /// The kind currently configured on the session, or `nil` while passive.
    package var activeKind: AudioSessionClientKind? {
        applied?.kind
    }

    /// **Used for testing only**
    /// `true` while no claim is held and nothing is asserted.
    package var isPassive: Bool {
        applied == nil
    }
    
    // MARK: - Private properties
    
    private let defaultDriver: any AudioSessionDriverProtocol

    /// The driver for `.call`.
    private let callDriver: (any ExternallyActivatedDriver)?

    private let notificationCenter: NotificationCenter
    
    private var registrations: [UUID: Registration] = [:]
    private var nextSequence: UInt64 = 0

    /// What was last handed to a driver, or `nil` while passive.
    private var applied: (kind: AudioSessionClientKind, profile: AudioSessionProfile)?

    private var isReconciling = false
    private var needsReconcile = false
    private var isInterrupted = false

    /// Set when a claim was acquired, updated or released while the system held the session, so
    /// `interruptionEnded(shouldResume:)` knows a decision is waiting even when told not to resume.
    private var claimsChangedWhileInterrupted = false

    /// Where the notification observers post, and the single task draining it in order.
    private let systemEvents: AsyncStream<SystemEvent>.Continuation
    private var pendingSystemEvents: AsyncStream<SystemEvent>?
    private var systemEventTask: Task<Void, Never>?

    private var eventContinuations: [UUID: AsyncStream<AudioSessionEvent>.Continuation] = [:]

    /// The claim the current recovery hook was supplied for.
    private var recoveryClaimID: UUID?

    /// The claim currently configured for, so a change of winner can be reported to the claim that lost.
    private var winningClaimID: UUID?

    /// Token for the `interruptionNotification` observer
    private var interruptionObserver: ObserverToken?

    /// Token for the `routeChangeNotification` observer
    private var routeChangeObserver: ObserverToken?

    /// Route changes the system caused, as opposed to the ones this manager caused.
    private static let routeChangeReasonsWorthReasserting: Set<AVAudioSession.RouteChangeReason> = [
        .newDeviceAvailable,
        .oldDeviceUnavailable,
    ]
    
    /// Whether this manager installs the system observers for itself. Used for testing
    private let observesSystemNotifications: Bool

    /// Whether it already has, so the first `acquire(_:)` installs them and no later one repeats the work.
    private var hasStartedObserving = false

    /// Set when the winner has to be handed to its driver even though its profile has not changed.
    private var forceReapply = false

    // MARK: - Lifecycle

    /// The production manager: real drivers, and it observes the system for itself.
    ///
    /// - Parameters:
    ///   - callDriver: The driver for `.call`, whose activation is CallKit's.
    ///   - notificationCenter: Where interruptions and route changes are observed.
    package init(
        callDriver: any ExternallyActivatedDriver,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaultDriver = AVAudioSessionDriver()
        self.callDriver = callDriver
        self.notificationCenter = notificationCenter

        let (events, continuation) = AsyncStream<SystemEvent>.makeStream()
        self.systemEvents = continuation
        self.pendingSystemEvents = events

        /// Observation starts with the first `acquire(_:)` rather than here.
        self.observesSystemNotifications = true
    }

    /// For tests: drivers you supply, and no automatic observation — a test opts in with
    /// `startObservingInterruptions()` and injects its own `NotificationCenter`.
    ///
    /// Separate from the initializer above rather than one with a flag, so that "real drivers" and "observes
    /// the system" cannot be separated by a caller.
    package init(
        defaultDriver: any AudioSessionDriverProtocol,
        callDriver: (any ExternallyActivatedDriver)? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaultDriver = defaultDriver
        self.callDriver = callDriver
        self.notificationCenter = notificationCenter

        let (events, continuation) = AsyncStream<SystemEvent>.makeStream()
        self.systemEvents = continuation
        self.pendingSystemEvents = events

        self.observesSystemNotifications = false
    }

    deinit {
        systemEvents.finish()
        systemEventTask?.cancel()

        if let interruptionObserver {
            notificationCenter.removeObserver(interruptionObserver.value)
        }
        if let routeChangeObserver {
            notificationCenter.removeObserver(routeChangeObserver.value)
        }
    }

    // MARK: - Public functions
    
    /// A one-line description of what the session is doing, for a log.
    public func diagnostics() async -> String {
        guard let applied else {
            return await "passive, " + (defaultDriver.diagnostics())
        }

        return await "kind=\(applied.kind), " + (driver(for: applied.kind).diagnostics())
    }

    public func currentRoute() async -> AudioSessionRouteSnapshot {
        // With no claim there is nothing applied, so the default driver answers.
        guard let applied else {
            return await defaultDriver.currentRoute()
        }

        return await driver(for: applied.kind).currentRoute()
    }

    /// Register what this client needs and resolve it against the existing claims.
    ///
    /// The returned claim must be released explicitly.
    ///
    /// - Throws: `AudioSessionError.busyWithCall` if `kind` is `.recording` while a call holds a
    ///   claim. Every other kind is granted, possibly as a subordinate.
    public func acquire(
        _ kind: AudioSessionClientKind,
        output: AudioSessionOutput = .system
    ) async throws -> AudioSessionClaim {
        if kind == .recording, registrations.values.contains(where: \.kind.isCall) {
            DDLogError("[AudioSessionManager] Ignoring recording request because a call is active")
            throw AudioSessionError.busyWithCall
        }

        startObservingSystemNotificationsIfNeeded()

        nextSequence += 1
        let claim = AudioSessionClaim(kind: kind)
        registrations[claim.id] = Registration(
            id: claim.id,
            kind: kind,
            sequence: nextSequence,
            profile: kind.profile(for: output)
        )

        await reconcile()
        return claim
    }

    /// Change the route this claim is asking for.
    ///
    /// A no-op for a subordinate claim: it updates the request, but the session is only reconfigured
    /// if this claim is the winner.
    public func update(_ claim: AudioSessionClaim, output: AudioSessionOutput) async {
        guard var registration = registrations[claim.id] else {
            DDLogWarn("[AudioSessionManager] Ignoring route update for unknown claim")
            return
        }
        
        DDLogInfo(
            "[AudioSessionManager] Updating route for \(claim.kind): \(registration.profile.output) -> \(output)"
        )

        // Rebuilt, not mutated: the kind decides what a route implies, so only `profile(for:)` may pair a
        // category with an output.
        registration.profile = registration.kind.profile(for: output)
        registrations[claim.id] = registration

        await reconcile()
    }

    /// Give up this claim. Releasing an unknown or already-released claim does nothing.
    public func release(_ claim: AudioSessionClaim) async {
        guard registrations.removeValue(forKey: claim.id) != nil else {
            DDLogWarn("[AudioSessionManager] Ignoring route release for unknown claim")
            return
        }

        DDLogInfo("[AudioSessionManager] Releasing route for \(claim.kind)")
        eventContinuations.removeValue(forKey: claim.id)?.finish()

        // Only this claim's own hook.
        if recoveryClaimID == claim.id {
            recoveryClaimID = nil
            await callDriver?.setRecovery(nil)
        }

        await reconcile()
    }

    /// Tell the `.call` driver that its session has been activated for it.
    public nonisolated func sessionWasActivatedExternally(_ session: AVAudioSession) {
        guard let callDriver else {
            DDLogError("[AudioSessionManager] No externally activated driver to forward activation to")
            return
        }

        callDriver.sessionDidActivate(session)
    }

    /// Tell the `.call` driver that its session has been deactivated.
    public nonisolated func sessionWasDeactivatedExternally(_ session: AVAudioSession) {
        callDriver?.sessionDidDeactivate(session)
    }

    /// Supply how the session held by `claim` gets reactivated after an interruption.
    ///
    /// Withdrawn automatically when `claim` is released, so no teardown path has to remember to.
    public func setRecovery(_ recovery: any AudioSessionRecovering, for claim: AudioSessionClaim) async {
        guard registrations[claim.id] != nil else {
            DDLogWarn("[AudioSessionManager] Ignoring recovery hook for unknown claim")
            return
        }

        recoveryClaimID = claim.id
        await callDriver?.setRecovery(recovery)
    }

    /// Events affecting the session this claim was granted against.
    public func events(for claim: AudioSessionClaim) -> AsyncStream<AudioSessionEvent> {
        /// Buffers only the newest few events: a client that has stopped consuming has by definition
        /// stopped caring about the backlog, and only the latest interruption state is actionable.
        let (stream, continuation) = AsyncStream<AudioSessionEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(4)
        )

        guard registrations[claim.id] != nil else {
            // Unknown or already-released claim. Hand back an immediately-finished stream rather than
            // retaining a continuation that nothing will ever complete.
            continuation.finish()
            return stream
        }

        eventContinuations.updateValue(continuation, forKey: claim.id)?.finish()
        return stream
    }

    // MARK: - Internal functions

    /// Start translating `AVAudioSession.interruptionNotification` into `interruptionBegan()` and
    /// `interruptionEnded(shouldResume:)`.
    func startObservingInterruptions() {
        stopObservingInterruptions()
        startDrainingSystemEvents()

        let token = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            
            guard let self else {
                return
            }
            
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                return
            }

            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                .contains(.shouldResume)

            switch type {
            case .began:
                systemEvents.yield(.interruptionBegan)
            case .ended:
                systemEvents.yield(.interruptionEnded(shouldResume: shouldResume))
            @unknown default:
                break
            }
        }

        interruptionObserver = ObserverToken(token)
    }

    func stopObservingInterruptions() {
        guard let interruptionObserver else {
            return
        }

        notificationCenter.removeObserver(interruptionObserver.value)
        self.interruptionObserver = nil
    }

    /// Start translating `AVAudioSession.routeChangeNotification` into `routeChanged(reason:)`.
    func startObservingRouteChanges() {
        stopObservingRouteChanges()
        startDrainingSystemEvents()

        let token = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in

            guard let self else {
                return
            }
            
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
                return
            }

            systemEvents.yield(.routeChanged(reason: reason))
        }

        routeChangeObserver = ObserverToken(token)
    }

    func stopObservingRouteChanges() {
        guard let routeChangeObserver else {
            return
        }

        notificationCenter.removeObserver(routeChangeObserver.value)
        self.routeChangeObserver = nil
    }

    /// The route changed under the winning claim.
    func routeChanged(reason: AVAudioSession.RouteChangeReason) async {
        guard let winner = applied, !isInterrupted else {
            return
        }

        let route = await driver(for: winner.kind).currentRoute()

        // The manager is not the only thing that can move the route. `AVRoutePickerView` lets the user choose an
        // output through system UI, with no claim involved, and that arrives here as `.override`.
        if reason == .override, let winningClaimID {
            await adoptExternalOutput(matching: route, for: winningClaimID, appliedOutput: winner.profile.output)
        }

        if Self.routeChangeReasonsWorthReasserting.contains(reason) {
            DDLogVerbose(
                "[AudioSessionManager] Re-asserting \(winner.profile.output) after route change: \(reason)"
            )
            forceReapply = true
            await reconcile()
        }

        // Re-read: the reconcile above may have changed the winner, and the route with it. If everything was
        // released meanwhile there is nothing configured to report a route for.
        guard let current = self.applied else {
            return
        }

        await emit(.outputRouteChanged(
            reason: reason,
            route: driver(for: current.kind).currentRoute()
        ))
    }

    /// The system has taken the session.
    func interruptionBegan() {
        guard !isInterrupted else {
            return
        }

        isInterrupted = true
        claimsChangedWhileInterrupted = false

        // Whatever the driver last applied is no longer in effect, so recording it as applied would
        // be a lie.
        applied = nil

        DDLogVerbose("[AudioSession] Interruption began")
        emit(.interrupted)
    }

    /// The system has given the session back.
    ///
    /// - Parameter shouldResume: from `AVAudioSession.InterruptionOptions.shouldResume`. When `true`
    ///   the winning claim is restored through its driver before the event is delivered. When `false`
    ///   nothing is resumed — but a claim that arrived during the interruption is a new intent rather than a
    ///   resumption, so it is still applied.
    func interruptionEnded(shouldResume: Bool) async {
        guard isInterrupted else {
            return
        }

        isInterrupted = false
        DDLogVerbose("[AudioSession] Interruption ended, shouldResume=\(shouldResume)")

        let claimsChanged = claimsChangedWhileInterrupted
        claimsChangedWhileInterrupted = false

        if shouldResume {
            await recoverWinner()
        }
        else if claimsChanged {
            DDLogVerbose("[AudioSession] Not resuming, but the claims changed while interrupted")
            await reconcile()
        }

        emit(.interruptionEnded(shouldResume: shouldResume))
    }

    // MARK: - Private functions
    
    private func startObservingSystemNotificationsIfNeeded() {
        // The driver-injecting initializer leaves lifecycle to its owner. Not a problem to report.
        guard observesSystemNotifications, !hasStartedObserving else {
            return
        }

        hasStartedObserving = true

        startObservingInterruptions()
        startObservingRouteChanges()
    }

    private func startDrainingSystemEvents() {
        // Start the one consumer of `systemEvents`, if it is not running.
        guard systemEventTask == nil, let pendingSystemEvents else {
            return
        }
        self.pendingSystemEvents = nil

        systemEventTask = Task { [weak self] in
            for await event in pendingSystemEvents {
                guard let self else {
                    return
                }

                switch event {
                case .interruptionBegan:
                    await interruptionBegan()
                case let .interruptionEnded(shouldResume):
                    await interruptionEnded(shouldResume: shouldResume)
                case let .routeChanged(reason):
                    await routeChanged(reason: reason)
                }
            }
        }
    }
    
    private func recoverWinner() async {
        guard let winner = currentWinner() else {
            DDLogWarn("[AudioSessionManager] No winner to recover")
            return
        }

        // Recovery, not `apply`: the CallKit driver cannot restore the input route by configuring.
        do {
            try await driver(for: winner.kind).recoverFromInterruption(restoring: winner.profile)
            applied = (winner.kind, winner.profile)
        }
        catch {
            DDLogError("[AudioSession] Recovering \(winner.kind) after interruption failed: \(error)")
        }
    }

    private func emit(_ event: AudioSessionEvent, to claimID: UUID) {
        eventContinuations[claimID]?.yield(event)
    }

    private func emit(_ event: AudioSessionEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    /// Bring the session in line with the current claims.
    ///
    /// Coalesced rather than run directly, because an actor is **reentrant**: `applyWinner()` awaits
    /// a driver, and during that suspension another `acquire` or `release` runs on this actor. Two
    /// overlapping passes could then write `applied` in completion order rather than decision order,
    /// leaving the session configured for a claim that had already lost. Only one pass runs at a
    /// time, and it re-reads the winner on each iteration, so late arrivals converge instead of
    /// racing.
    private func reconcile() async {
        // The system owns the session for the duration of an interruption. Asserting against the
        // route changes an alarm produces is audible as cracks and artifacts, so claims acquired or
        // released while interrupted are recorded and nothing more; `interruptionEnded(shouldResume:)`
        // picks up whatever the winner turned out to be once the session comes back.
        guard !isInterrupted else {
            claimsChangedWhileInterrupted = true
            return
        }

        needsReconcile = true

        guard !isReconciling else {
            return
        }

        isReconciling = true
        defer { isReconciling = false }

        while needsReconcile {
            needsReconcile = false
            await applyWinner()
        }
    }

    private func currentWinner() -> Registration? {
        registrations.values.max { lhs, rhs in
            if lhs.kind < rhs.kind {
                return true
            }
            if rhs.kind < lhs.kind {
                return false
            }

            return lhs.sequence < rhs.sequence
        }
    }

    private func applyWinner() async {
        let winner = currentWinner()

        // Told before anything is applied, so a client hears that it lost the session before the session
        if let previous = winningClaimID, previous != winner?.id, registrations[previous] != nil {
            emit(.subordinated, to: previous)
        }
        winningClaimID = winner?.id

        // Consumed unconditionally, so a route change that arrives with no claims left does not leave
        // the flag set to force an unrelated apply later.
        let mustReapply = forceReapply
        forceReapply = false

        guard let winner else {
            if let applied {
                await deactivate(driverFor: applied.kind)
                self.applied = nil
            }
            return
        }

        let incoming = driver(for: winner.kind)

        // Release only when the *driver* changes, not merely the winning kind. Two different drivers
        // must not both hold an activation, so the outgoing one goes first. But when the same driver
        // serves both kinds, deactivating here would tear the session down one line before
        // reconfiguring it — the redundant setActive(false)-then-reconfigure churn that this package
        // exists to remove, and an audible glitch on a live call.
        if let applied, driver(for: applied.kind) !== incoming {
            await deactivate(driverFor: applied.kind)
            self.applied = nil
        }

        guard mustReapply || applied?.profile != winner.profile else {
            // This is the subordinate path: acquiring or releasing a lower-priority claim must not reconfigure
            // anything.
            applied = (winner.kind, winner.profile)
            return
        }

        do {
            try await incoming.apply(winner.profile)
            applied = (winner.kind, winner.profile)
        }
        catch {
            DDLogError("[AudioSession] Applying \(winner.kind) profile failed: \(error)")
        }
    }

    /// Record an output the user chose through system UI, so the winner's profile matches the session.
    private func adoptExternalOutput(
        matching route: AudioSessionRouteSnapshot,
        for claimID: UUID,
        appliedOutput: AudioSessionOutput
    ) async {
        guard var registration = registrations[claimID], registration.kind.isCall else {
            return
        }

        let onSpeaker = route.outputs.contains(.builtInSpeaker)

        guard onSpeaker != (appliedOutput == .speaker) else {
            return
        }

        let chosen: AudioSessionOutput = onSpeaker ? .speaker : .system

        DDLogVerbose(
            "[AudioSessionManager] Adopting \(chosen) chosen outside the manager (was \(appliedOutput))"
        )

        registration.profile = registration.kind.profile(for: chosen)
        registrations[claimID] = registration

        await reconcile()
    }

    private func deactivate(driverFor kind: AudioSessionClientKind) async {
        do {
            try await driver(for: kind).deactivate()
        }
        catch {
            DDLogWarn("[AudioSession] Deactivating after \(kind) failed: \(error)")
        }
    }

    private func driver(for kind: AudioSessionClientKind) -> any AudioSessionDriverProtocol {
        guard kind.isCall, let callDriver else {
            return defaultDriver
        }

        return callDriver
    }
}
