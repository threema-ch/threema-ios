import Testing
@testable import Threema

struct SentryConsentLedgerTests {

    // MARK: - Pending cap

    @Test("Reserves slots up to the pending cap and then refuses")
    func reservesUpToTheCap() {
        let ledger = SentryConsentLedger(maxPendingReports: 2)

        #expect(ledger.reservePending(eventID: "a", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "b", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "c", context: nil) == .capReached)
    }

    @Test("Frees a slot on consent so a new report can be reserved")
    func consentFreesASlot() {
        let ledger = SentryConsentLedger(maxPendingReports: 1)

        #expect(ledger.reservePending(eventID: "a", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "b", context: nil) == .capReached)

        ledger.recordConsent(eventID: "a")

        #expect(ledger.reservePending(eventID: "b", context: nil) == .reserved)
    }

    @Test("Frees a slot on drop so a new report can be reserved")
    func dropFreesASlot() {
        let ledger = SentryConsentLedger(maxPendingReports: 1)

        #expect(ledger.reservePending(eventID: "a", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "b", context: nil) == .capReached)

        ledger.drop(eventID: "a")

        #expect(ledger.reservePending(eventID: "b", context: nil) == .reserved)
    }

    @Test("Refuses a second reservation for a report already awaiting a decision")
    func refusesDuplicateReservation() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        #expect(ledger.reservePending(eventID: "a", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "a", context: nil) == .alreadyPending)
    }

    @Test("A refused duplicate does not consume a slot")
    func duplicateReservationKeepsTheSlot() {
        let ledger = SentryConsentLedger(maxPendingReports: 1)

        _ = ledger.reservePending(eventID: "a", context: nil)
        _ = ledger.reservePending(eventID: "a", context: nil)
        ledger.drop(eventID: "a")

        #expect(ledger.reservePending(eventID: "b", context: nil) == .reserved)
    }

    @Test("Answering the same report twice frees only one slot")
    func repeatedAnswerFreesOneSlot() {
        let ledger = SentryConsentLedger(maxPendingReports: 2)

        _ = ledger.reservePending(eventID: "a", context: nil)
        _ = ledger.reservePending(eventID: "b", context: nil)

        ledger.drop(eventID: "a")
        ledger.drop(eventID: "a")

        #expect(ledger.reservePending(eventID: "c", context: nil) == .reserved)
        #expect(ledger.reservePending(eventID: "d", context: nil) == .capReached)
    }

    // MARK: - Consent consumption

    @Test("An event that was never consented is not let through")
    func notConsentedWithoutConsent() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        _ = ledger.reservePending(eventID: "a", context: nil)

        #expect(!ledger.consumeConsent(eventID: "a").isConsented)
    }

    @Test("Restores the stored context for a consented event")
    func consentRestoresContext() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)
        let context: SentryConsentLedger.Context = ["app": ["device_app_hash": "abc123"]]

        _ = ledger.reservePending(eventID: "a", context: context)
        ledger.recordConsent(eventID: "a")

        let outcome = ledger.consumeConsent(eventID: "a")

        #expect(outcome.restoredContext?["app"]?["device_app_hash"] as? String == "abc123")
    }

    @Test("Consumes consent so a second pass is not let through")
    func consentIsConsumedOnce() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        _ = ledger.reservePending(eventID: "a", context: nil)
        ledger.recordConsent(eventID: "a")

        #expect(ledger.consumeConsent(eventID: "a").isConsented)
        #expect(!ledger.consumeConsent(eventID: "a").isConsented)
    }

    @Test("Consents without a context")
    func consentWithoutContext() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        _ = ledger.reservePending(eventID: "a", context: nil)
        ledger.recordConsent(eventID: "a")

        let outcome = ledger.consumeConsent(eventID: "a")

        #expect(outcome.isConsented)
        #expect(outcome.restoredContext == nil)
    }

    @Test("Consent for a report that was never reserved is ignored")
    func consentWithoutReservationIsIgnored() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        ledger.recordConsent(eventID: "a")

        #expect(!ledger.consumeConsent(eventID: "a").isConsented)
    }

    @Test("A declined event is not let through")
    func declinedEventIsNotConsented() {
        let ledger = SentryConsentLedger(maxPendingReports: 10)

        _ = ledger.reservePending(eventID: "a", context: ["app": [:]])
        ledger.drop(eventID: "a")

        #expect(!ledger.consumeConsent(eventID: "a").isConsented)
    }
}

// MARK: - Helpers

/// `ConsentOutcome` cannot be `Equatable`, because its payload holds `Any` values.
extension SentryConsentLedger.ConsentOutcome {
    fileprivate var isConsented: Bool {
        if case .consented = self {
            true
        }
        else {
            false
        }
    }

    /// The context to restore, `nil` both when not consented and when the event carried no context.
    /// Only meaningful together with ``isConsented``.
    fileprivate var restoredContext: SentryConsentLedger.Context? {
        if case let .consented(context) = self {
            context
        }
        else {
            nil
        }
    }
}
