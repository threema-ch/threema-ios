import Foundation
import os

/// Tracks which deferred crash reports are awaiting a decision, which the user consented to, and the
/// context to restore when a consented event is re-captured.
///
/// All state is guarded by an `OSAllocatedUnfairLock`, so instances are safe to touch from Sentry's
/// queue (`beforeSend`) and from the main actor (the consent alert).
final class SentryConsentLedger: @unchecked Sendable {

    /// A deferred event's `context` as it was at capture time.
    typealias Context = [String: [String: Any]]

    /// Why a report was or was not queued for the user's decision.
    enum Reservation: Equatable {
        /// A slot was taken and the context stored. The caller must answer with
        /// ``recordConsent(eventID:)`` or ``drop(eventID:)``.
        case reserved
        /// The user is already being asked about this report.
        case alreadyPending
        /// ``maxPendingReports`` reports are already waiting for a decision.
        case capReached
    }

    /// Whether a re-captured event may be uploaded, and with which context.
    enum ConsentOutcome {
        /// The user never consented to this event, or the consent was already consumed. It must not
        /// leave the device.
        case notConsented
        /// The user consented. `context` is the crashed run's context to restore, `nil` if the event
        /// carried none.
        case consented(context: Context?)
    }

    private let lock = OSAllocatedUnfairLock()

    /// Event IDs the user agreed to send. Let through exactly once each.
    private var consentedEventIDs: Set<String> = []

    /// `context` of a deferred event as it was at capture time. Re-capturing an event runs the SDK's
    /// event processors again, which would otherwise describe the *current* run instead of the crashed
    /// one.
    private var originalContexts: [String: Context] = [:]

    /// Reports handed to the consent alert and not answered yet. A set rather than a counter, so a
    /// repeated reservation or a repeated answer for the same report cannot make the cap drift.
    private var pendingEventIDs: Set<String> = []

    /// Upper bound on reports waiting for a decision.
    private let maxPendingReports: Int

    init(maxPendingReports: Int) {
        self.maxPendingReports = maxPendingReports
    }

    /// Reserves a slot for a report awaiting the user's decision and stores its context.
    ///
    /// Nothing is stored unless the result is ``Reservation/reserved``.
    func reservePending(eventID: String, context: Context?) -> Reservation {
        lock.withLockUnchecked {
            guard pendingEventIDs.count < maxPendingReports else {
                return .capReached
            }

            // The SDK may run `beforeSend` more than once for one event. Reserving twice would leak a
            // slot and queue a second alert for a report the user is already being asked about.
            guard pendingEventIDs.insert(eventID).inserted else {
                return .alreadyPending
            }

            if let context {
                originalContexts[eventID] = context
            }

            return .reserved
        }
    }

    /// Records the user's consent so the re-captured event is let through on its next pass, and frees
    /// the report's pending slot.
    ///
    /// Ignores a report that is not waiting for a decision, so a repeated answer neither frees a second
    /// slot nor grants consent twice.
    func recordConsent(eventID: String) {
        lock.withLockUnchecked {
            guard pendingEventIDs.remove(eventID) != nil else {
                return
            }

            consentedEventIDs.insert(eventID)
        }
    }

    /// Drops a report the user declined, freeing its pending slot and discarding its stored context.
    ///
    /// Ignores a report that is not waiting for a decision, see ``recordConsent(eventID:)``.
    func drop(eventID: String) {
        lock.withLockUnchecked {
            guard pendingEventIDs.remove(eventID) != nil else {
                return
            }

            originalContexts.removeValue(forKey: eventID)
        }
    }

    /// Consumes the consent for a re-captured event.
    ///
    /// Consent and context are consumed once each, so any further pass of the same event is
    /// ``ConsentOutcome/notConsented``.
    func consumeConsent(eventID: String) -> ConsentOutcome {
        lock.withLockUnchecked {
            guard consentedEventIDs.remove(eventID) != nil else {
                return .notConsented
            }

            return .consented(context: originalContexts.removeValue(forKey: eventID))
        }
    }
}
