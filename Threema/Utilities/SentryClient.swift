import CocoaLumberjackSwift
import FileUtility
import Foundation
import Sentry
import ThreemaFramework
import ThreemaMacros

/// Carries a Sentry `Event` from Sentry's queue to the main actor.
///
/// `Event` is a mutable Objective-C class and therefore not `Sendable`. Ownership here is strictly
/// hand-over: the event is sanitized on Sentry's queue, then only touched on the main actor until the
/// user answered, and afterwards only by the SDK again.
private struct EventBox: @unchecked Sendable {
    let event: Event
}

/// Mutable state lives in ``SentryConsentLedger``, which is internally locked, so instances are safe to
/// touch from Sentry's queue and from the main actor.
final class SentryClient: NSObject, @unchecked Sendable {

    /// Shared instance, kept alive for the whole app lifetime.
    static let shared = SentryClient()

    private static let sentryNotEnabled = "SENTRY_NOT_ENABLED"
    private static var didStart = false

    /// Upper bound on crash reports waiting for a decision. Sentry caches only a handful of envelopes,
    /// so this merely guards against pathological cases.
    private static let maxPendingReports = 10

    /// Tracks pending, consented, and deferred-context state across Sentry's queue and the main actor.
    private let ledger = SentryConsentLedger(maxPendingReports: SentryClient.maxPendingReports)

    /// Strips everything that must never leave the device from an event.
    private let sanitizer = EventSanitizer()

    /// Identifies an event by the anonymized app device hash instead of by the user.
    private let enricher = EventEnricher()

    // MARK: - Lifecycle

    override private init() {
        super.init()
    }

    // MARK: - Start

    /// Create Sentry and start crash handler.
    func start() {
        #if DISABLE_SENTRY
            return
        #endif

        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }

        guard !SettingsBundleHelper.disableSentry else {
            return
        }

        guard SentryClient.isEnabled() else {
            return
        }

        guard !SentryClient.didStart else {
            return
        }

        guard
            let sentryDsn = BundleUtil.object(forInfoDictionaryKey: "SentryClientDsn") as? String,
            !sentryDsn.isEmpty
        else {
            DDLogError("Could not retrieve sentryDsn from bundle. Sentry will not be started.")
            return
        }

        SentryClient.didStart = true

        SentrySDK.start { options in

            // Apply settings
            options.dsn = sentryDsn
            options.environment = ThreemaEnvironment.env().description

            // Disable/Configure certain tracking options
            options.enableAutoSessionTracking = false
            options.enableNetworkTracking = false
            options.enableCaptureFailedRequests = false
            options.appHangTimeoutInterval = TimeInterval(10)

            options.enableMetricKit = true
            options.experimental.enableWatchdogTerminationsV2 = true

            // We disable hang tracking since the reports were inconsistent
            options.enableAppHangTracking = false
            options.enableReportNonFullyBlockingAppHangs = false

            // Disable breadcrumbs
            options.maxBreadcrumbs = 0
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false

            // This will be called when an event occurs
            options.beforeSend = { event in
                self.handle(event: event)
            }
        }

        // `SentryCrash` installs a fatal signal handler for `SIGPIPE`, overwriting the `SIG_IGN`
        // disposition set at launch. `SIGPIPE` is never a programming error worth crashing on (it
        // just means a socket peer went away), so restore the ignore.
        // See `AppLauncher.ignoreSIGPIPE()`.
        AppLauncher.ignoreSIGPIPE()
    }

    // MARK: - Event handling

    /// Decides whether an event may leave the device.
    ///
    /// Nothing is uploaded without the user's consent, and consent cannot be collected from here
    /// without blocking Sentry's queue on an alert. So an event is seen twice: on the first pass it is
    /// sanitized, handed to ``SentryCrashConsentPresenter`` and dropped; if the user agrees it is
    /// re-captured and passed through on the second pass.
    private func handle(event: Event) -> Event? {
        // swiftformat:disable:next acronyms
        let eventID = event.eventId.sentryIdString

        switch ledger.consumeConsent(eventID: eventID) {
        case let .consented(context):
            // On re-capture the SDK re-enriches the event with the *current* run (contexts, user) before
            // handing it back here. Restore the crashed run's context and re-strip anything re-added.
            // Correctness assumes `beforeSend` is the last transform before send; if a future SDK runs
            // event processors after `beforeSend`, move this restore + prepare into a trailing processor.
            if let context {
                event.context = context
            }

            prepare(event)

            return event

        case .notConsented:
            prepare(event)
            askForConsent(about: event, eventID: eventID)

            return nil
        }
    }

    /// Brings an event into the shape we are willing to upload: identified only by the anonymized app
    /// device hash and stripped of everything that must never leave the device.
    ///
    /// Runs on both passes of a deferred event, because re-capturing re-enriches the event with the
    /// current run's user.
    private func prepare(_ event: Event) {
        enricher.enrich(event)
        sanitizer.sanitize(event)
    }

    /// Hands the event to the consent alert and re-captures it if the user agrees.
    private func askForConsent(about event: Event, eventID: String) {
        switch ledger.reservePending(eventID: eventID, context: event.context) {
        case .reserved:
            break

        case .alreadyPending:
            DDLogNotice("[Sentry] Crash report \(eventID) is already waiting for a decision.")
            return

        case .capReached:
            DDLogWarn(
                "[Sentry] \(SentryClient.maxPendingReports) crash reports are already waiting for a decision, dropping \(eventID)."
            )
            return
        }

        let box = EventBox(event: event)
        Task { @MainActor in
            SentryCrashConsentPresenter.shared.enqueue(box.event, eventID: eventID) { [weak self] decision in
                self?.apply(decision, to: box.event, eventID: eventID)
            }
        }
    }

    /// Applies the user's answer.
    @MainActor
    private func apply(
        _ decision: SentryCrashConsentPresenter.Decision,
        to event: Event,
        eventID: String
    ) {
        guard decision.send else {
            ledger.drop(eventID: eventID)

            DDLogNotice("[Sentry] User declined to send crash report \(eventID).")
            return
        }

        ledger.recordConsent(eventID: eventID)

        // Runs through `beforeSend` again, which recognizes the ID and passes the event on.
        SentrySDK.capture(event: event)

        if let comment = decision.comment {
            let feedback = SentryFeedback(
                message: comment,
                name: nil,
                email: nil,
                // swiftformat:disable:next acronyms
                associatedEventId: event.eventId
            )
            SentrySDK.capture(feedback: feedback)
        }
    }

    /// Whether the Sentry crash handler may be started.
    ///
    /// The escape hatch for an app that crashes on start *because of* the Sentry start handler: a file
    /// named ``sentryNotEnabled`` placed in the app's documents directory — reachable over Finder file
    /// sharing without a working app — keeps Sentry off from the next launch on.
    ///
    /// - Returns: `true` to start the Sentry crash handler.
    private static func isEnabled() -> Bool {
        !FileUtility.shared
            .fileExists(at: FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(sentryNotEnabled))
    }
}
