import Foundation
import Testing
import ThreemaFramework
@testable import Threema

@MainActor
struct VoIPPushHandlerTests {

    // MARK: - Reporting

    @Test
    func reportsCallFromPayload() throws {
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy)

        // Number of calls reported by the time PushKit was told we are done. The whole point of the
        // inline path: without this being 1, iOS terminates the app.
        var reportedCallsWhenCompleted: Int?
        handler.report(dictionaryPayload: Self.validPayload) {
            reportedCallsWhenCompleted = spy.reportedCalls.count
        }

        #expect(reportedCallsWhenCompleted == 1)
        #expect(spy.cancelledCalls.isEmpty)

        let reported = try #require(spy.reportedCalls.first)
        #expect(reported.callID.callID == 42)
        #expect(reported.callPartnerIdentity == "ECHOECHO")
        #expect(reported.callPartnerName == "Test Contact")
        #expect(reported.ringtoneSound == "default")
        #expect(reported.fromPush)
    }

    @Test(arguments: [
        // Not a call push at all
        [:],
        // Missing caller name
        [
            Constants.notificationExtensionOffer: "ECHOECHO",
            Constants.notificationExtensionRingtoneSoundName: "default",
            Constants.notificationExtensionCallID: "42",
        ],
        // Call ID that is not a `UInt32`
        [
            Constants.notificationExtensionOffer: "ECHOECHO",
            Constants.notificationExtensionCallerName: "Test Contact",
            Constants.notificationExtensionRingtoneSoundName: "default",
            Constants.notificationExtensionCallID: "not a number",
        ],
    ] as [[String: String]])
    func reportsAndCancelsCallForUnparsablePayload(payload: [String: String]) {
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy)

        var completionCalled = false
        handler.report(dictionaryPayload: payload) {
            completionCalled = true
        }

        // A call must be reported for every VoIP push, even one we cannot interpret
        #expect(spy.reportedCalls.isEmpty)
        #expect(spy.cancelledCalls == [TargetManager.appName])
        #expect(completionCalled)
    }

    @Test
    func forwardsHangupOfRingingCall() throws {
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy)

        var completionCalled = false
        handler.report(dictionaryPayload: Self.hangupPayload) {
            completionCalled = true
        }

        #expect(completionCalled)
        #expect(spy.reportedCalls.isEmpty)
        #expect(spy.cancelledCalls.isEmpty)

        let hungUp = try #require(spy.hungUpCalls.first)
        #expect(hungUp.callID.callID == 42)
        #expect(hungUp.callPartnerIdentity == "ECHOECHO")
        #expect(hungUp.callPartnerName == "Test Contact")

        #expect(spy.followUpRunCount == 0)
        handler.businessDidBecomeReady()
        #expect(spy.followUpRunCount == 1)
    }

    @Test
    func reportsAndCancelsCallForPayloadWithNonStringValues() {
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy)

        var completionCalled = false
        handler.report(dictionaryPayload: ["aps": ["content-available": 1]]) {
            completionCalled = true
        }

        #expect(spy.reportedCalls.isEmpty)
        #expect(spy.cancelledCalls == [TargetManager.appName])
        #expect(completionCalled)
    }

    // MARK: - Connecting

    @Test
    func defersConnectingUntilTheLaunchSequenceSignalsReady() async {
        let bringUp = BringUpSpy()
        let spy = VoIPCallReportingSpy()
        // A scene is launching, so the handler must leave the bring-up to it
        let handler = makeHandler(spy: spy, bringUp: bringUp, isLaunchSequenceRunning: true)

        handler.report(dictionaryPayload: Self.validPayload) { }
        await handler.headlessActivation?.value

        // Reported straight away, everything that needs the business layer waits
        #expect(spy.reportedCalls.count == 1)
        #expect(spy.followUpRunCount == 0)
        #expect(bringUp.callCount == 0)

        handler.businessDidBecomeReady()

        #expect(spy.followUpRunCount == 1)
        #expect(bringUp.callCount == 0)
    }

    @Test
    func connectsImmediatelyWhenBusinessIsAlreadyReady() {
        let bringUp = BringUpSpy()
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy, bringUp: bringUp)
        handler.businessDidBecomeReady()

        handler.report(dictionaryPayload: Self.validPayload) { }

        #expect(spy.followUpRunCount == 1)
        #expect(bringUp.callCount == 0)
        #expect(handler.headlessActivation == nil)
    }

    @Test
    func bringsUpBusinessItselfWhenNoLaunchSequenceIsRunning() async {
        let bringUp = BringUpSpy()
        let spy = VoIPCallReportingSpy()
        // No scene connected: a call-triggered launch with the device locked
        let handler = makeHandler(spy: spy, bringUp: bringUp)

        handler.report(dictionaryPayload: Self.validPayload) { }
        await handler.headlessActivation?.value

        #expect(bringUp.callCount == 1)
        #expect(spy.followUpRunCount == 1)
    }

    @Test
    func keepsConnectingQueuedWhenTheBringUpFails() async {
        let bringUp = BringUpSpy(succeeds: false)
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy, bringUp: bringUp)

        handler.report(dictionaryPayload: Self.validPayload) { }
        await handler.headlessActivation?.value

        #expect(bringUp.callCount == 1)
        #expect(spy.followUpRunCount == 0)

        // A failed bring-up can be transient, so a launch sequence must still be able to release it
        handler.businessDidBecomeReady()

        #expect(spy.followUpRunCount == 1)
    }

    @Test
    func bringsUpBusinessOnlyOnceForSeveralPushes() async {
        let bringUp = BringUpSpy()
        let spy = VoIPCallReportingSpy()
        let handler = makeHandler(spy: spy, bringUp: bringUp)

        handler.report(dictionaryPayload: Self.validPayload) { }
        handler.report(dictionaryPayload: Self.validPayload) { }
        await handler.headlessActivation?.value

        #expect(spy.reportedCalls.count == 2)
        #expect(spy.followUpRunCount == 2)
        #expect(bringUp.callCount == 1)
    }

    // MARK: - Helpers

    private static let validPayload: [String: String] = [
        Constants.notificationExtensionOffer: "ECHOECHO",
        Constants.notificationExtensionCallerName: "Test Contact",
        Constants.notificationExtensionRingtoneSoundName: "default",
        Constants.notificationExtensionCallID: "42",
    ]

    private static let hangupPayload: [String: String] = [
        Constants.notificationExtensionHangup: "ECHOECHO",
        Constants.notificationExtensionCallerName: "Test Contact",
        Constants.notificationExtensionCallID: "42",
    ]

    private func makeHandler(
        spy: VoIPCallReportingSpy,
        bringUp: BringUpSpy? = nil,
        isLaunchSequenceRunning: Bool = false
    ) -> VoIPPushHandler {
        let resolvedBringUp = bringUp ?? BringUpSpy()
        return VoIPPushHandler(
            callReporter: spy,
            markAppActive: { /* Not the app group's business in a test */ },
            isLaunchSequenceRunning: { isLaunchSequenceRunning },
            bringUpBusinessLayer: { resolvedBringUp.run() },
            activationDelay: .zero
        )
    }
}

// MARK: - VoIPCallReportingSpy

private final class VoIPCallReportingSpy: VoIPCallReporting {

    struct ReportedCall {
        let callID: VoIPCallID
        let callPartnerIdentity: String
        let callPartnerName: String?
        let ringtoneSound: String
        let fromPush: Bool
    }

    struct HungUpCall {
        let callID: VoIPCallID
        let callPartnerIdentity: String
        let callPartnerName: String?
    }

    private(set) var reportedCalls: [ReportedCall] = []
    private(set) var hungUpCalls: [HungUpCall] = []
    private(set) var cancelledCalls: [String] = []

    /// How often the follow-up work handed back to the handler actually ran
    private(set) var followUpRunCount = 0

    func newIncomingCallFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        fromPush: Bool,
        completion: @escaping (@escaping () -> Void) -> Void
    ) {
        reportedCalls.append(
            ReportedCall(
                callID: callID,
                callPartnerIdentity: callPartnerIdentity,
                callPartnerName: callPartnerName,
                ringtoneSound: ringtoneSound,
                fromPush: fromPush
            )
        )

        completion { [weak self] in
            self?.followUpRunCount += 1
        }
    }

    func ringingCallHungUpFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        completion: @escaping (@escaping () -> Void) -> Void
    ) {
        hungUpCalls.append(
            HungUpCall(callID: callID, callPartnerIdentity: callPartnerIdentity, callPartnerName: callPartnerName)
        )

        completion { [weak self] in
            self?.followUpRunCount += 1
        }
    }

    func startAndCancelCall(from localizedName: String, completion: @escaping () -> Void) {
        cancelledCalls.append(localizedName)
        completion()
    }
}

// MARK: - BringUpSpy

@MainActor
private final class BringUpSpy {

    private(set) var callCount = 0

    private let succeeds: Bool

    init(succeeds: Bool = true) {
        self.succeeds = succeeds
    }

    func run() -> Bool {
        callCount += 1
        return succeeds
    }
}
