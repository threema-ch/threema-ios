import Foundation
import Testing
import ThreemaFramework
@testable import Threema

struct VoIPCallKitManagerTests {

    // MARK: - Waiting for the business layer

    @Test
    func actsImmediatelyWhenTheBusinessLayerIsAlreadyUsable() async {
        let readiness = BusinessLayerReadinessSpy()
        let manager = VoIPCallKitManager(isBusinessLayerUsable: { readiness.isUsable() })

        let becameUsable = await manager.waitForBusinessLayer(callID: VoIPCallID(callID: 42))

        #expect(becameUsable)
        // The app was already running: no reason to delay the action by even one poll
        #expect(readiness.checkCount == 1)
    }

    @Test
    func waitsForACallTriggeredLaunchToBringTheBusinessLayerUp() async {
        let readiness = BusinessLayerReadinessSpy(becomesUsableAfterChecks: 3)
        let manager = VoIPCallKitManager(isBusinessLayerUsable: { readiness.isUsable() })

        let becameUsable = await manager.waitForBusinessLayer(callID: VoIPCallID(callID: 42))

        // The bring-up runs asynchronously, so the first checks legitimately fail
        #expect(becameUsable)
        #expect(readiness.checkCount == 4)
    }

    @Test
    func givesUpWhenTheBusinessLayerNeverBecomesUsable() async {
        let readiness = BusinessLayerReadinessSpy(becomesUsableAfterChecks: .max)
        let manager = VoIPCallKitManager(
            isBusinessLayerUsable: { readiness.isUsable() },
            businessLayerWaitTimeout: 0.3
        )

        let becameUsable = await manager.waitForBusinessLayer(callID: VoIPCallID(callID: 42))

        // CallKit times the action out on its own, so waiting has to end well before that
        #expect(!becameUsable)
        #expect(readiness.checkCount > 1)
    }

    // MARK: - Tracking a call reported from a push

    @Test
    func remembersACallReportedFromAPush() {
        let manager = makeManager()
        let callID = VoIPCallID(callID: 42)

        manager.reportIncomingCall(
            with: callID,
            callPartnerIdentity: "ECHOECHO",
            callPartnerName: "Test Contact",
            ringtoneSound: "default",
            fromPush: true
        ) { _ in }

        // Ringing without the state machine knowing about the call: ending it now is a decline and
        // has to send the reject, which only this tells us
        #expect(manager.reportedRingingCallID?.callID == callID.callID)
    }

    @Test
    func forgetsAReportedCallOnceItEnds() {
        let manager = makeManager()
        let callID = VoIPCallID(callID: 42)

        manager.reportIncomingCall(
            with: callID,
            callPartnerIdentity: "ECHOECHO",
            callPartnerName: "Test Contact",
            ringtoneSound: "default",
            fromPush: true
        ) { _ in }
        manager.endCall(with: callID)

        // Otherwise a later hangup of the same call would be mistaken for a decline
        #expect(manager.reportedRingingCallID == nil)
    }

    // MARK: - Helpers

    private func makeManager() -> VoIPCallKitManager {
        VoIPCallKitManager(isBusinessLayerUsable: { true })
    }
}

// MARK: - BusinessLayerReadinessSpy

/// Stands in for the singletons the production readiness check reads.
private final class BusinessLayerReadinessSpy: @unchecked Sendable {

    private(set) var checkCount = 0

    /// How many checks report the business layer as unusable before it comes up.
    private let becomesUsableAfterChecks: Int

    init(becomesUsableAfterChecks: Int = 0) {
        self.becomesUsableAfterChecks = becomesUsableAfterChecks
    }

    func isUsable() -> Bool {
        checkCount += 1
        return checkCount > becomesUsableAfterChecks
    }
}
