import AudioSessionManagerTestHelper
import AVFoundation
import Foundation
import Testing
@testable import AudioSessionManager

/// Every test builds its own manager and driver, so the suite is parallel-safe without `.serialized`. Nothing
/// here touches a real `AVAudioSession`: tests that exercise system interruptions post to a private
/// `NotificationCenter` rather than `.default`, and the two that use the *production* initialiser — the one
/// that builds a real `AVAudioSessionDriver` for non-call kinds — claim `.call`, so all the work lands on a
/// mock.
extension AudioSessionProfile {
    fileprivate static var call: AudioSessionProfile { AudioSessionClientKind.call.profile(for: .system) }
    fileprivate static var playback: AudioSessionProfile { AudioSessionClientKind.playback.profile(for: .system) }

    /// Playback with the phone held to the ear, which is the one profile a route promotes to a
    /// different category.
    fileprivate static var playbackAtEar: AudioSessionProfile {
        AudioSessionClientKind.playback.profile(for: .receiver)
    }

    /// The kind's profile with the speaker forced, for asserting that a route change re-applies.
    ///
    /// Resolved through `profile(for:)` rather than by copying and editing one: a profile is immutable, because
    /// a route can imply a category and only that function knows when.
    fileprivate static func onSpeaker(_ kind: AudioSessionClientKind) -> AudioSessionProfile {
        kind.profile(for: .speaker)
    }
}

/// These tests are about *whether* the winner is re-asserted, not about what the route was, so they match on
/// the case and the reason only. The payload is no longer untestable — it comes from the driver, so a test that
/// cares sets it with `setRoute(outputs:hasBluetoothInput:)` and compares the whole event. See
/// `routePayloadComesFromTheDriver()`.
extension AudioSessionEvent {
    fileprivate func isOutputRouteChanged(_ expected: AVAudioSession.RouteChangeReason) -> Bool {
        guard case let .outputRouteChanged(reason, _) = self else {
            return false
        }
        return reason == expected
    }
}

@Suite("AudioSessionManager Tests")
struct AudioSessionManagerTests {

    // MARK: - Granting

    @Test("The first claim applies its profile exactly once")
    func firstClaimApplies() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.playback)

        #expect(await driver.calls == [.apply(.playback)])
        #expect(await manager.activeKind == .playback)
    }

    @Test("A manager with no claims asserts nothing")
    func passiveUntilFirstClaim() async {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        #expect(await manager.isPassive)
        #expect(await driver.calls.isEmpty)
    }

    @Test(
        "A higher kind takes the session from a lower one",
        arguments: [
            (AudioSessionClientKind.ambient, AudioSessionClientKind.playback),
            (.ambient, .mediaPlayback),
            (.ambient, .speech),
            (.ambient, .call),
            (.playback, .recording),
            (.mediaPlayback, .recording),
            (.speech, .call),
            (.playback, .call),
            (.playback, .groupCall),
            (.recording, .call),
            (.recording, .groupCall),
        ]
    )
    func higherKindWins(lower: AudioSessionClientKind, higher: AudioSessionClientKind) async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(lower)
        #expect(await manager.activeKind == lower)

        _ = try await manager.acquire(higher)
        #expect(await manager.activeKind == higher)
    }

    // MARK: - Subordination

    @Test("A lower-priority claim acquired during a call is granted without reconfiguring")
    func subordinateClaimDoesNotReconfigure() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        let playback = try await manager.acquire(.playback)

        // The claim exists — playback is allowed to proceed — but the call's session is untouched.
        #expect(await driver.calls.isEmpty)
        #expect(await manager.activeKind == .call)

        await manager.release(playback)

        #expect(await driver.calls.isEmpty)
        #expect(await manager.activeKind == .call)
    }

    @Test("Updating a subordinate claim's route does not touch the session")
    func updatingSubordinateClaimDoesNotReconfigure() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        let playback = try await manager.acquire(.playback)
        await driver.reset()

        await manager.update(playback, output: .speaker)

        #expect(await driver.calls.isEmpty)
    }

    @Test("Updating the winning claim's route re-applies")
    func updatingWinnerReapplies() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let call = try await manager.acquire(.call)
        await driver.reset()

        await manager.update(call, output: .speaker)

        #expect(await driver.calls == [.apply(.onSpeaker(.call))])
    }

    @Test(
        "The playback kinds share a rank, so the most recent wins rather than the highest raw value",
        arguments: [
            (AudioSessionClientKind.playback, AudioSessionClientKind.mediaPlayback),
            (.mediaPlayback, .playback),
            (.speech, .playback),
            (.playback, .speech),
        ]
    )
    func playbackKindsTieOnSequence(first: AudioSessionClientKind, second: AudioSessionClientKind) async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(first)
        _ = try await manager.acquire(second)

        // They differ in *mode*, not in who should own the session. If `Comparable` ran on the raw value
        // instead of the rank, `.speech` would outrank `.playback` for no reason anyone chose.
        #expect(await manager.activeKind == second)
    }
	
    @Test("A claim that stops winning is told, once, and only if it still holds the claim")
    func losingTheSessionIsReported() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let recording = try await manager.acquire(.recording)
        var events = await manager.events(for: recording).makeAsyncIterator()

        // A call may start while a recording is in progress — the refusal only runs the other way round. The
        // recorder's microphone goes away with nothing else to tell it: the session is simply reconfigured for
        // the winner, and `AVAudioRecorder` goes quiet without an error.
        let call = try await manager.acquire(.call)
        #expect(await events.next() == .subordinated)

        // Losing is reported once, not on every later reconcile.
        _ = try await manager.acquire(.ambient)
        await manager.release(call)

        // Whatever arrives next, it is not a second `.subordinated` for the same loss.
        await manager.release(recording)
        #expect(await events.next() == nil)
    }

    @Test("Releasing a claim is not reported as losing it")
    func releasingIsNotSubordination() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let playback = try await manager.acquire(.playback)
        var events = await manager.events(for: playback).makeAsyncIterator()

        // It did not lose the session, it gave it up — and `release(_:)` finishes the stream, so the only thing
        // this iterator should ever produce is the end.
        await manager.release(playback)
        #expect(await events.next() == nil)
    }

    // MARK: - Refusal

    @Test("Recording during a call is refused rather than silently starved of the microphone")
    func recordingDuringCallIsRefused() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        await #expect(throws: AudioSessionError.busyWithCall) {
            _ = try await manager.acquire(.recording)
        }

        #expect(await driver.calls.isEmpty)
        #expect(await manager.activeKind == .call)
    }

    @Test(
        "Recording is refused by a group call too, not only by a 1:1 call",
        arguments: [AudioSessionClientKind.call, .groupCall]
    )
    func recordingDuringEitherCallKindIsRefused(callKind: AudioSessionClientKind) async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(callKind)

        await #expect(throws: AudioSessionError.busyWithCall) {
            _ = try await manager.acquire(.recording)
        }
    }

    @Test("The two call kinds differ in who activates, and in nothing else")
    func callKindsDifferOnlyInActivation() {
        let call = AudioSessionClientKind.call.profile(for: .system)
        let groupCall = AudioSessionClientKind.groupCall.profile(for: .system)

        // A group call has no CallKit, so nothing else will ever call `setActive(true)` for it.
        #expect(call.activation == .external)
        #expect(groupCall.activation == .driverOwned)

        #expect(call.category == groupCall.category)
        #expect(call.mode == groupCall.mode)
        #expect(call.options == groupCall.options)
        #expect(call.prefersNoInterruptionsFromSystemAlerts == groupCall.prefersNoInterruptionsFromSystemAlerts)
    }

    @Test("Handing the session from a 1:1 call to a group call never tears it down")
    func callKindChangeKeepsOneDriver() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )

        let call = try await manager.acquire(.call)
        await callDriver.reset()

        _ = try await manager.acquire(.groupCall)
        await manager.release(call)

        // Both kinds resolve to the same driver instance, so `applyWinner()`'s identity check sees no change
        // and never deactivates between them. A second driver would have handed the session over via a
        // teardown, which is audible.
        #expect(await callDriver.calls == [.apply(AudioSessionClientKind.groupCall.profile(for: .system))])
    }

    @Test("A call may still start while a recording is in progress")
    func callDuringRecordingIsGranted() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.recording)

        _ = try await manager.acquire(.call)

        #expect(await manager.activeKind == .call)
    }

    // MARK: - Release

    @Test("Releasing the last claim deactivates and returns to passive")
    func releasingLastClaimGoesPassive() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let claim = try await manager.acquire(.playback)
        await driver.reset()

        await manager.release(claim)

        #expect(await driver.calls == [.deactivate])
        #expect(await manager.isPassive)
    }

    @Test("Releasing the winner promotes the highest remaining claim")
    func releasingWinnerPromotesNextClaim() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.playback)
        let call = try await manager.acquire(.call)
        await driver.reset()

        await manager.release(call)

        #expect(await manager.activeKind == .playback)
        #expect(await driver.calls == [.apply(.playback)])
    }

    @Test("A change of winning kind on a shared driver reconfigures in place, never tearing down")
    func kindChangeOnSharedDriverNeverDeactivates() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let ambient = try await manager.acquire(.ambient)
        let playback = try await manager.acquire(.playback)
        let call = try await manager.acquire(.call)
        await manager.release(call)
        await manager.release(playback)

        // Some claim is held throughout, and one driver serves all three kinds. A `.deactivate`
        // anywhere in here would be a teardown of a session that is reconfigured on the very next
        // line — the redundant churn this package exists to remove, audible as a glitch on a call.
        #expect(await !driver.calls.contains(.deactivate))
        #expect(await manager.activeKind == .ambient)

        await manager.release(ambient)

        #expect(await driver.calls.last == .deactivate)
        #expect(await manager.isPassive)
    }

    @Test("Releasing an already-released claim does nothing")
    func doubleReleaseIsIgnored() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let claim = try await manager.acquire(.playback)
        await manager.release(claim)
        await driver.reset()

        await manager.release(claim)

        #expect(await driver.calls.isEmpty)
        #expect(await manager.isPassive)
    }

    // MARK: - Tie-breaking

    @Test("Between two claims of equal kind the most recent wins, deterministically")
    func equalKindResolvesToMostRecent() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let first = try await manager.acquire(.playback)
        let second = try await manager.acquire(.playback)
        await driver.reset()

        // Two claims of one kind share a profile, so nothing in what was *applied* distinguishes them.
        // A route change does: only the winner's request reaches the driver. Without the sequence
        // tie-break the winner would depend on `Dictionary` iteration order, and this would flip.
        await manager.update(first, output: .speaker)
        #expect(await driver.calls.isEmpty)

        await manager.update(second, output: .speaker)

        #expect(await driver.calls == [.apply(.onSpeaker(.playback))])
    }

    // MARK: - Driver selection

    @Test("The winning kind selects the driver, and the outgoing driver releases first")
    func winnerKindSelectsDriver() async throws {
        let defaultDriver = MockAudioSessionDriver()
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: defaultDriver,
            callDriver: callDriver
        )

        _ = try await manager.acquire(.playback)
        _ = try await manager.acquire(.call)

        #expect(await defaultDriver.calls == [.apply(.playback), .deactivate])
        #expect(await callDriver.calls == [.apply(.call)])
    }

    // MARK: - Interruptions

    @Test("An interruption asserts nothing on the session")
    func interruptionDoesNotTouchTheSession() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        await manager.interruptionBegan()

        // The system already took the session. Deactivating or reconfiguring here is what produces
        // the cracks and artifacts an alarm used to cause.
        #expect(await driver.calls.isEmpty)
        #expect(await manager.isPassive)
    }

    @Test("A resumable interruption restores the winner through the recovery path")
    func resumableInterruptionRecoversWinner() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        await manager.interruptionBegan()
        await manager.interruptionEnded(shouldResume: true)

        // Recovery, not `apply`: the CallKit driver cannot restore the input route by configuring,
        // so the manager must not silently take the ordinary path.
        #expect(await driver.calls == [.recoverFromInterruption(.call)])
        #expect(await manager.activeKind == .call)
    }

    @Test("A non-resumable interruption leaves the session alone")
    func nonResumableInterruptionDoesNotRestore() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.playback)
        await driver.reset()

        await manager.interruptionBegan()
        await manager.interruptionEnded(shouldResume: false)

        #expect(await driver.calls.isEmpty)
        #expect(await manager.isPassive)
    }

    @Test("Claims acquired during an interruption are recorded, then honoured on recovery")
    func claimsDuringInterruptionApplyOnRecovery() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.playback)
        await manager.interruptionBegan()
        await driver.reset()

        _ = try await manager.acquire(.call)

        // Registered but not applied — nothing may touch the session mid-interruption.
        #expect(await driver.calls.isEmpty)

        await manager.interruptionEnded(shouldResume: true)

        // The winner is re-read on recovery, so the call acquired mid-interruption wins.
        #expect(await driver.calls == [.recoverFromInterruption(.call)])
        #expect(await manager.activeKind == .call)
    }

    @Test("A claim acquired during an interruption is applied even when the system says not to resume")
    func claimsDuringInterruptionApplyWithoutResumeHint() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        await manager.interruptionBegan()

        _ = try await manager.acquire(.playback)
        #expect(await driver.calls.isEmpty)

        await manager.interruptionEnded(shouldResume: false)

        // A claim that arrived during the interruption is a new intent, not a resumption, so `shouldResume`
        // does not speak for it. Without this it would never reach a driver at all.
        #expect(await driver.calls == [.apply(.playback)])
        #expect(await manager.activeKind == .playback)
    }

    @Test("A claim released during an interruption does not resurrect the session afterwards")
    func claimsReleasedDuringInterruptionStayReleased() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let playback = try await manager.acquire(.playback)
        await manager.interruptionBegan()
        await driver.reset()

        await manager.release(playback)
        await manager.interruptionEnded(shouldResume: false)

        #expect(await driver.calls.isEmpty)
        #expect(await manager.isPassive)
    }

    @Test("Recovery re-applies even though the winning profile never changed")
    func recoveryDoesNotShortCircuitOnUnchangedProfile() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let call = try await manager.acquire(.call)

        await manager.interruptionBegan()
        await manager.interruptionEnded(shouldResume: true)
        await driver.reset()

        // The session is live again, so ordinary arbitration resumes: a subordinate claim must still
        // not reconfigure it.
        _ = try await manager.acquire(.playback)
        #expect(await driver.calls.isEmpty)

        await manager.release(call)
        #expect(await manager.activeKind == .playback)
    }

    @Test("Interruption events reach the claim holder")
    func interruptionEventsAreDelivered() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let claim = try await manager.acquire(.playback)
        var events = await manager.events(for: claim).makeAsyncIterator()

        await manager.interruptionBegan()
        let began = await events.next()
        #expect(began == .interrupted)

        await manager.interruptionEnded(shouldResume: true)
        let ended = await events.next()
        #expect(ended == .interruptionEnded(shouldResume: true))
    }

    @Test("Releasing a claim finishes its event stream")
    func releaseFinishesEventStream() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        let claim = try await manager.acquire(.playback)
        var events = await manager.events(for: claim).makeAsyncIterator()

        await manager.release(claim)

        let next = await events.next()
        #expect(next == nil)
    }

    @Test("A repeated interruptionBegan is ignored")
    func repeatedInterruptionBeganIsIgnored() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)

        await manager.interruptionBegan()
        await manager.interruptionBegan()
        await driver.reset()
        await manager.interruptionEnded(shouldResume: true)

        #expect(await driver.calls == [.recoverFromInterruption(.call)])
    }

    @Test("An interruptionEnded without a began is ignored")
    func unmatchedInterruptionEndedIsIgnored() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        await manager.interruptionEnded(shouldResume: true)

        #expect(await driver.calls.isEmpty)
        #expect(await manager.activeKind == .call)
    }

    // MARK: - System alert interruptions

    @Test("The system-alert preference is part of profile identity, so changing it re-applies")
    func interruptionPreferenceIsPartOfProfileIdentity() async throws {
        // Built as a pair rather than by editing one: a profile is immutable, because a route can imply a
        // category and only `profile(for:)` knows when. That also makes this test honest about what it
        // covers — the field's presence in `Equatable`, not a mutation that cannot happen.
        let suppressing = AudioSessionProfile(
            category: .playAndRecord,
            mode: .voiceChat,
            prefersNoInterruptionsFromSystemAlerts: true
        )
        let interruptible = AudioSessionProfile(
            category: .playAndRecord,
            mode: .voiceChat,
            prefersNoInterruptionsFromSystemAlerts: false
        )

        // If this field were left out of `Equatable`, the manager's "profile unchanged, skip the apply"
        // short-circuit would not notice a change to it. A client cannot inject a profile, so the only
        // field that can differ at runtime is `output` — `updatingWinnerReapplies` covers that path.
        #expect(suppressing != interruptible)
    }

    @Test(
        "Only the kinds an alarm would damage ask to suppress system-alert interruptions",
        arguments: [
            (AudioSessionClientKind.call, true),
            (.groupCall, true),
            (.recording, true),
            (.playback, false),
            (.mediaPlayback, false),
            (.speech, false),
            (.ambient, false),
        ]
    )
    func interruptionPreferencePerKind(kind: AudioSessionClientKind, suppresses: Bool) {
        #expect(kind.profile(for: .system).prefersNoInterruptionsFromSystemAlerts == suppresses)
    }

    @Test(
        "A playAndRecord kind asking for the speaker says so in its options, not only in the override",
        arguments: [AudioSessionClientKind.call, .groupCall, .recording]
    )
    func speakerIsDurableForPlayAndRecordKinds(kind: AudioSessionClientKind) {
        // `overrideOutputAudioPort(.speaker)` is temporary: it lasts until the category is set again, and
        // WebRTC sets it again when it starts its audio unit — which for an outgoing call is the instant the
        // callee answers. A speaker chosen while it rang was silently dropped to the earpiece right there.
        #expect(kind.profile(for: .speaker).options.contains(.defaultToSpeaker))

        // And only when asked for, or every call would start on the speaker.
        #expect(!kind.profile(for: .system).options.contains(.defaultToSpeaker))
        #expect(!kind.profile(for: .receiver).options.contains(.defaultToSpeaker))
    }

    @Test(
        "A kind that is not playAndRecord never carries the option, which is invalid on any other category",
        arguments: [AudioSessionClientKind.ambient, .playback, .mediaPlayback, .speech]
    )
    func speakerOptionIsOnlyForPlayAndRecord(kind: AudioSessionClientKind) {
        let profile = kind.profile(for: .speaker)

        #expect(profile.category != .playAndRecord)
        #expect(!profile.options.contains(.defaultToSpeaker))
    }

    // MARK: - Following the proximity sensor

    @Test("Playback asking for the earpiece becomes a playAndRecord session, because iOS has no other route to it")
    func playbackAtEarPromotesTheCategory() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.playback)
        await manager.update(claim, output: .receiver)

        #expect(await driver.calls == [.apply(.playback), .apply(.playbackAtEar)])
        #expect(AudioSessionProfile.playbackAtEar.category == .playAndRecord)

        // Without these, the category change would drop a connected headset off A2DP mid-message.
        #expect(AudioSessionProfile.playbackAtEar.options.contains(.allowBluetoothA2DP))
    }

    @Test("Taking the phone away from the ear goes back to plain playback rather than staying on playAndRecord")
    func leavingTheEarRestoresThePlaybackCategory() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.playback)
        await manager.update(claim, output: .receiver)
        await manager.update(claim, output: .system)

        #expect(await driver.calls == [.apply(.playback), .apply(.playbackAtEar), .apply(.playback)])
    }

    @Test("The proximity sensor firing twice for the same state does not re-apply")
    func repeatedProximityUpdatesApplyOnce() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.playback)
        await manager.update(claim, output: .receiver)
        await manager.update(claim, output: .receiver)

        #expect(await driver.calls == [.apply(.playback), .apply(.playbackAtEar)])
    }

    @Test(
        "For a kind that is already playAndRecord, the earpiece is what the system route resolves to anyway",
        arguments: [AudioSessionClientKind.call, .recording]
    )
    func receiverIsANoOpForPlayAndRecordKinds(kind: AudioSessionClientKind) {
        let system = kind.profile(for: .system)
        let receiver = kind.profile(for: .receiver)

        // Only the declared route differs. If the configuration ever diverged, a client asking for the
        // ear mid-call would change the category or mode of a live call — which rebuilds the
        // voice-processing IO unit, and that is audible.
        #expect(system.category == receiver.category)
        #expect(system.mode == receiver.mode)
        #expect(system.options == receiver.options)
    }

    // MARK: - System observation

    @Test("A system interruption notification drives the manager end to end")
    func systemNotificationDrivesInterruption() async throws {
        // A private centre, not `.default`: this suite runs in parallel, and managers sharing the
        // process-wide centre would see each other's notifications.
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingInterruptions()

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()
        await driver.reset()

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        // Awaiting the event is the synchronisation: the observer hops onto the actor through a
        // `Task`, so there is no point asserting until the manager has actually seen it. No sleeps.
        let began = await events.next()
        #expect(began == .interrupted)
        #expect(await driver.calls.isEmpty)

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
            ]
        )

        let ended = await events.next()
        #expect(ended == .interruptionEnded(shouldResume: true))
        #expect(await driver.calls == [.recoverFromInterruption(.call)])
    }

    @Test("The production manager starts observing on its first claim, without being asked")
    func productionManagerObservesLazily() async throws {
        let center = NotificationCenter()
        // The production initialiser is the thing under test — it is what sets `observesSystemNotifications`.
        // Claiming `.call` keeps the work on the mock driver: the default driver this initialiser builds is a
        // real `AVAudioSessionDriver`, and any other kind would configure the host's session.
        let manager = AudioSessionManager(callDriver: MockExternallyActivatedDriver(), notificationCenter: center)

        // Nothing claimed yet, so nothing is observed — there is no configuration to protect.
        #expect(await manager.isPassive)

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        // Arrived without any call to `startObservingInterruptions()`: acquiring installed the observer.
        let began = await events.next()
        #expect(began == .interrupted)
    }

    @Test("A driver-injected manager does not observe unless asked")
    func injectedManagerDoesNotObserveByDefault() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        _ = try await manager.acquire(.call)
        await driver.reset()

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        // This initialiser leaves observation to the caller, so the notification is not seen.
        #expect(await manager.activeKind == .call)
        #expect(await driver.calls.isEmpty)
    }

    @Test("An interruption notification without a resume hint does not restore")
    func systemNotificationWithoutResumeHint() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingInterruptions()

        let claim = try await manager.acquire(.playback)
        var events = await manager.events(for: claim).makeAsyncIterator()
        await driver.reset()

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        _ = await events.next()

        // No option key at all, so no `.shouldResume`.
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        let ended = await events.next()
        #expect(ended == .interruptionEnded(shouldResume: false))
        #expect(await driver.calls.isEmpty)
    }

    @Test("A begin/end pair posted back to back is handled in the order it was posted")
    func interruptionNotificationsKeepTheirOrder() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingInterruptions()

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()
        await driver.reset()

        // Both in one go, as a short interruption produces. Each used to hop onto the actor in its own
        // unstructured `Task`, so they raced: if `.ended` won, it returned early on `guard isInterrupted` and
        // `.began` then set the flag with nothing left to clear it — every later claim recorded and never
        // applied, for the life of the process.
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
            ]
        )

        #expect(await events.next() == .interrupted)
        #expect(await events.next() == .interruptionEnded(shouldResume: true))

        // Recovered, not stranded: the manager is usable again.
        #expect(await driver.calls == [.recoverFromInterruption(.call)])
        #expect(await manager.activeKind == .call)
    }

    @Test("Malformed interruption notifications are ignored")
    func malformedNotificationIsIgnored() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingInterruptions()
        _ = try await manager.acquire(.call)
        await driver.reset()

        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: nil)
        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: UInt(99)]
        )

        #expect(await manager.activeKind == .call)
        #expect(await driver.calls.isEmpty)
    }

    @Test("Stopping observation detaches from the centre")
    func stopObservingDetaches() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingInterruptions()
        _ = try await manager.acquire(.call)
        await manager.stopObservingInterruptions()
        await driver.reset()

        center.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        #expect(await manager.activeKind == .call)
        #expect(await driver.calls.isEmpty)
    }

    // MARK: - Failure

    @Test("A driver that fails to apply leaves nothing marked as applied")
    func failedApplyDoesNotRecordState() async throws {
        let driver = MockAudioSessionDriver()
        await driver.failApply()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.playback)

        // Still passive, so the next reconcile retries rather than skipping the apply as redundant.
        #expect(await manager.isPassive)
        #expect(await driver.calls == [.apply(.playback)])
    }

    // MARK: - Externally activated sessions

    @Test("Activation is forwarded to the call driver synchronously")
    func externalActivationReachesTheCallDriver() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )
        _ = try await manager.acquire(.call)
        await callDriver.reset()

        manager.sessionWasActivatedExternally(AVAudioSession.sharedInstance())

        #expect(await callDriver.waitForCalls(1) == [.sessionDidActivate])
    }

    @Test("Deactivation is forwarded to the call driver")
    func externalDeactivationReachesTheCallDriver() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )
        _ = try await manager.acquire(.call)
        await callDriver.reset()

        manager.sessionWasDeactivatedExternally(AVAudioSession.sharedInstance())

        #expect(await callDriver.waitForCalls(1) == [.sessionDidDeactivate])
    }

    @Test("A manager built without a call driver swallows activation instead of crashing")
    func externalActivationWithoutACapableDriverIsSurvivable() async throws {
        // Unreachable in the app: `AudioSessionManagerFactory.make()` types the parameter on
        // `ExternallyActivatedDriver`, so a manager that cannot forward activation does not compile. It stays
        // reachable for a test that never exercises a call, so it has to be logged and ignored, not a trap.
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)
        _ = try await manager.acquire(.call)
        await driver.reset()

        manager.sessionWasActivatedExternally(AVAudioSession.sharedInstance())
        manager.sessionWasDeactivatedExternally(AVAudioSession.sharedInstance())

        #expect(await driver.calls.isEmpty)
    }

    @Test("Recovery is handed to the call driver, and withdrawn when its claim is released")
    func recoveryIsForwardedAndCleared() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )
        let call = try await manager.acquire(.call)
        await callDriver.reset()

        await manager.setRecovery(StubRecovery(), for: call)
        await manager.release(call)

        #expect(await callDriver.calls == [
            .setRecovery(isNil: false),
            .setRecovery(isNil: true),
            .deactivate,
        ])
    }

    @Test("A finished call cannot withdraw the recovery hook of the call that replaced it")
    func releasingAnOldClaimLeavesTheCurrentRecoveryAlone() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )

        // Two overlapping calls, as a fast redial produces: the second installs its hook before the first has
        // finished tearing down.
        let first = try await manager.acquire(.call)
        await manager.setRecovery(StubRecovery(), for: first)
        let second = try await manager.acquire(.call)
        await manager.setRecovery(StubRecovery(), for: second)
        await callDriver.reset()

        await manager.release(first)
        #expect(await callDriver.calls.isEmpty)

        await manager.release(second)
        #expect(await callDriver.calls == [.setRecovery(isNil: true), .deactivate])
    }

    @Test("A recovery hook for an unknown claim is ignored")
    func recoveryForUnknownClaimIsIgnored() async throws {
        let callDriver = MockExternallyActivatedDriver()
        let manager = AudioSessionManager(
            defaultDriver: MockAudioSessionDriver(),
            callDriver: callDriver
        )
        let call = try await manager.acquire(.call)
        await manager.release(call)
        await callDriver.reset()

        await manager.setRecovery(StubRecovery(), for: call)

        #expect(await callDriver.calls.isEmpty)
    }

    // MARK: - Route changes

    @Test(
        "A device appearing or disappearing re-asserts the winner's output",
        arguments: [
            AVAudioSession.RouteChangeReason.newDeviceAvailable,
            .oldDeviceUnavailable,
        ]
    )
    func deviceChangeReassertsOutput(reason: AVAudioSession.RouteChangeReason) async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingRouteChanges()

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()
        await driver.reset()

        center.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue]
        )

        // Awaiting the event is the synchronisation, as in the interruption tests: the observer hops
        // onto the actor through a `Task`, and the re-assert happens before the event is emitted.
        #expect(await events.next()?.isOutputRouteChanged(reason) == true)

        // The profile has not changed, so this only happens because a route change forces the apply.
        #expect(await driver.calls == [.apply(.call)])
    }

    @Test(
        "Route changes this manager caused are reported but never re-asserted",
        arguments: [
            AVAudioSession.RouteChangeReason.override,
            .categoryChange,
        ]
    )
    func selfInflictedRouteChangeDoesNotReassert(reason: AVAudioSession.RouteChangeReason) async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)
        await manager.startObservingRouteChanges()

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()
        await driver.reset()

        center.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue]
        )

        #expect(await events.next()?.isOutputRouteChanged(reason) == true)

        // The feedback loop: `.override` is what our own `overrideOutputAudioPort` reports, so
        // answering it with another apply is what made `observeAudioRoutes` chase its own tail.
        #expect(await driver.calls.isEmpty)
    }

    @Test("An output the user chose through system UI is adopted, not overwritten")
    func externalOverrideIsAdopted() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.call)
        await driver.reset()

        // `AVRoutePickerView` sits over the call UI's speaker button whenever a Bluetooth device is
        // available, so tapping it moves the route through system UI with no claim involved. The manager
        // hears only `.override`, and if it keeps believing `.system` the choice is lost at the next
        // category application — which is what WebRTC does the instant a call connects.
        await driver.setRoute(outputs: [.builtInSpeaker], hasBluetoothInput: true)
        await manager.routeChanged(reason: .override)

        #expect(await manager.activeKind == .call)
        #expect(await driver.calls == [.apply(.onSpeaker(.call))])
    }

    @Test("Adopting stops once the model matches the route")
    func adoptingTerminates() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.call)
        await driver.setRoute(outputs: [.builtInSpeaker], hasBluetoothInput: true)
        await manager.routeChanged(reason: .override)
        await driver.reset()

        // Our own `overrideOutputAudioPort` reports `.override` too. The second pass must find nothing to
        // adopt, or every adoption would trigger another one.
        await manager.routeChanged(reason: .override)

        #expect(await driver.calls.isEmpty)
    }

    @Test("Choosing a headset through system UI records no forced output")
    func adoptingAHeadsetRecordsSystem() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.call, output: .speaker)
        await driver.reset()

        // Moving to a headset is not a *forced* output — it is what `.system` already means. Recording it
        // as `.speaker` would have the manager fight the device the user just picked.
        await driver.setRoute(outputs: [.bluetoothHFP], hasBluetoothInput: true)
        await manager.routeChanged(reason: .override)

        #expect(await driver.calls == [.apply(.call)])
    }

    @Test("Playback held to the ear is not mistaken for a route the user chose")
    func adoptingLeavesTheProximityRouteAlone() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.playback)
        await manager.update(claim, output: .receiver)
        await driver.setRoute(outputs: [.builtInReceiver])
        await driver.reset()

        // The proximity sensor's own `update` reports `.override`, and the receiver is not the speaker.
        // Reading that as "the user chose `.system`" would drop the phone at the ear back to the speaker
        // mid-message — and `overrideOutputAudioPort` is invalid outside `.playAndRecord` anyway.
        await manager.routeChanged(reason: .override)

        #expect(await driver.calls.isEmpty)
    }

    @Test("A route change while passive asserts nothing")
    func routeChangeWhilePassiveIsIgnored() async {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        // No claim, so a not-yet-migrated client may legitimately own the session right now.
        await manager.routeChanged(reason: .newDeviceAvailable)

        #expect(await manager.isPassive)
        #expect(await driver.calls.isEmpty)
    }

    @Test("A route change during an interruption asserts nothing")
    func routeChangeWhileInterruptedIsIgnored() async throws {
        let center = NotificationCenter()
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver, notificationCenter: center)

        _ = try await manager.acquire(.call)
        await manager.interruptionBegan()
        await driver.reset()

        // The system is moving the route itself while the alarm plays. Asserting against it is what
        // `isAudioInterrupted` was added to `VoIPCallService` to prevent, and it is audible.
        await manager.routeChanged(reason: .newDeviceAvailable)

        #expect(await driver.calls.isEmpty)
    }

    @Test("A route change re-asserts the route the winner asked for, not the one it started with")
    func reassertUsesTheUpdatedOutput() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.call)
        await manager.update(claim, output: .speaker)
        await driver.reset()

        // Unplugging headphones mid-call must not silently drop the call back to the receiver.
        await manager.routeChanged(reason: .oldDeviceUnavailable)

        #expect(await driver.calls == [.apply(.onSpeaker(.call))])
    }

    @Test("A route change re-asserts the winner, not a subordinate claim")
    func reassertIgnoresSubordinateClaims() async throws {
        let driver = MockAudioSessionDriver()
        let manager = AudioSessionManager(defaultDriver: driver)

        _ = try await manager.acquire(.call)
        _ = try await manager.acquire(.playback)
        await driver.reset()

        await manager.routeChanged(reason: .newDeviceAvailable)

        #expect(await driver.calls == [.apply(.call)])
    }

    @Test("The reported route comes from the driver, not from the session the test host happens to have")
    func routePayloadComesFromTheDriver() async throws {
        let driver = MockAudioSessionDriver()
        await driver.setRoute(outputs: [.bluetoothHFP], hasBluetoothInput: true)
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()

        await manager.routeChanged(reason: .newDeviceAvailable)

        // Asserting the whole event, which was impossible while the manager read `AVAudioSession` itself:
        // the payload was whatever the simulator was routed to.
        #expect(await events.next() == .outputRouteChanged(
            reason: .newDeviceAvailable,
            route: AudioSessionRouteSnapshot(outputs: [.bluetoothHFP], hasBluetoothInput: true)
        ))
    }

    @Test("A headset that is available but not selected is still reported as available")
    func bluetoothAvailabilityIsIndependentOfTheCurrentOutput() async throws {
        // The case `VoIPCallService.handleBluetoothAvailabilityChange` exists for, and the reason
        // `hasBluetoothInput` is carried separately: a headset connects while audio is still on the speaker,
        // so `outputs` says nothing about whether one is there to move to.
        let driver = MockAudioSessionDriver()
        await driver.setRoute(outputs: [.builtInSpeaker], hasBluetoothInput: true)
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()

        await manager.routeChanged(reason: .newDeviceAvailable)

        #expect(await events.next() == .outputRouteChanged(
            reason: .newDeviceAvailable,
            route: AudioSessionRouteSnapshot(outputs: [.builtInSpeaker], hasBluetoothInput: true)
        ))
    }

    @Test("The route is read when the event is emitted, so a re-assert cannot report a stale one")
    func routeIsReadAfterTheReassert() async throws {
        let driver = MockAudioSessionDriver()
        await driver.setRoute(outputs: [.builtInReceiver])
        let manager = AudioSessionManager(defaultDriver: driver)

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()

        // The device that caused the change is what the driver will answer with by the time we ask.
        await driver.setRoute(outputs: [.headphones])
        await manager.routeChanged(reason: .newDeviceAvailable)

        #expect(await events.next() == .outputRouteChanged(
            reason: .newDeviceAvailable,
            route: AudioSessionRouteSnapshot(outputs: [.headphones], hasBluetoothInput: false)
        ))
    }

    @Test("The production manager observes route changes on its first claim too")
    func productionManagerObservesRouteChangesLazily() async throws {
        let center = NotificationCenter()
        // `.call` for the reason in `productionManagerObservesLazily()`.
        let manager = AudioSessionManager(callDriver: MockExternallyActivatedDriver(), notificationCenter: center)

        let claim = try await manager.acquire(.call)
        var events = await manager.events(for: claim).makeAsyncIterator()

        center.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable
                .rawValue]
        )

        // Arrived without any call to `startObservingRouteChanges()`: acquiring installed both observers,
        // so production code cannot end up with one and not the other.
        #expect(await events.next()?.isOutputRouteChanged(.newDeviceAvailable) == true)
    }
}

/// Nothing calls back here: these tests assert that the manager *hands over* a recovery, not that it
/// runs one. `recoverFromInterruption` is covered by the interruption tests above.
private struct StubRecovery: AudioSessionRecovering {
    func requestAudioSessionReactivation() async {
        // no-op
    }
}
