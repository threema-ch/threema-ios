import CocoaLumberjackSwift
import Sentry
import ThreemaFramework
import ThreemaMacros
import UIKit

/// Asks the user whether a crash report may be sent, once per report.
///
/// The event is enqueued and the alert is shown once the app is in a state where the user can
/// actually see and answer it. Until then the report stays queued and presentation is retried, so an
/// interruption — an inactive app, the passcode lock, a UI that isn't up yet — postpones the question
/// instead of dropping the report.
///
/// - Note: Reports queued here only live as long as the process does. If the app is killed before the
///   user answers, the report is gone.
@MainActor
final class SentryCrashConsentPresenter {

    static let shared = SentryCrashConsentPresenter()

    /// The user's answer for a single crash report.
    struct Decision {
        let send: Bool
        /// What the user typed into the comment field, `nil` if empty or not sent.
        let comment: String?
    }

    // MARK: - Private types

    /// A crash report waiting for the user's decision.
    private struct PendingReport {
        let event: Sentry.Event
        let eventID: String
        let decisionHandler: @MainActor (Decision) -> Void
    }

    // MARK: - Private properties

    /// How long to wait before checking again whether the alert can be presented.
    private static let retryDelay = Duration.seconds(2)

    /// Stop retrying after roughly five minutes. Reports stay queued and the next
    /// `didBecomeActiveNotification` starts a new round.
    private static let maxRetries = 150

    private var pendingReports: [PendingReport] = []
    private var isPresenting = false

    private var retryScheduled = false
    private var retryCount = 0

    /// Notifications after which a queued report is worth asking about again, each resetting the retry
    /// budget. Releasing the passcode lock is not an app state change, so `didBecomeActiveNotification`
    /// does not cover it.
    private static let retryTriggers: [Notification.Name] = [
        UIApplication.didBecomeActiveNotification,
        .appUnlocked,
    ]

    private var retryTriggerObservers: [NSObjectProtocol] = []

    /// Attempts to present the consent alert now. Returns `false` when the app is in no state to show
    /// it, in which case the caller retries. On the user's answer the completion runs exactly once.
    /// Injected so the queue logic can be tested without UIKit.
    private let present: @MainActor (@escaping @MainActor (Decision) -> Void) -> Bool

    /// Runs `retry` after ``retryDelay``. Injected so tests can drive retries without waiting.
    private let scheduleRetry: @MainActor (@escaping @MainActor () -> Void) -> Void

    // MARK: - Lifecycle

    private init() {
        present = SentryCrashConsentPresenter.presentAlert
        scheduleRetry = SentryCrashConsentPresenter.scheduleRetryAfterDelay
        registerRetryTriggerObservers()
    }

    #if DEBUG
        /// Test seam: inject the presentation and retry scheduling.
        init(
            present: @escaping @MainActor (@escaping @MainActor (Decision) -> Void) -> Bool,
            scheduleRetry: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void
        ) {
            self.present = present
            self.scheduleRetry = scheduleRetry
            registerRetryTriggerObservers()
        }
    #endif

    deinit {
        for observer in retryTriggerObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func registerRetryTriggerObservers() {
        retryTriggerObservers = Self.retryTriggers.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // `queue: .main` guarantees we are on the main thread here.
                MainActor.assumeIsolated {
                    guard let self else {
                        return
                    }
                    self.retryCount = 0
                    self.presentNextIfPossible()
                }
            }
        }
    }

    // MARK: - Public interface

    /// Queues a crash report and asks the user about it as soon as the app can show an alert.
    ///
    /// - Parameters:
    ///   - event: The already sanitized event. It is not uploaded unless `decisionHandler` is called
    ///            with a `Decision` that has `send` set.
    ///   - eventID: Identifier of `event`, used to remove it from the queue once answered. A report
    ///              that is already queued under this ID is ignored, and its `decisionHandler` is
    ///              never called: one answer cannot be delivered to two handlers.
    ///   - decisionHandler: Called at most once, with the user's answer.
    func enqueue(
        _ event: Sentry.Event,
        eventID: String,
        decisionHandler: @escaping @MainActor (Decision) -> Void
    ) {
        guard !pendingReports.contains(where: { $0.eventID == eventID }) else {
            DDLogNotice("[Sentry] Crash report \(eventID) is already queued for a decision.")
            return
        }

        pendingReports.append(PendingReport(
            event: event,
            eventID: eventID,
            decisionHandler: decisionHandler
        ))
        presentNextIfPossible()
    }

    // MARK: - Presentation

    private func presentNextIfPossible() {
        guard !isPresenting, let report = pendingReports.first else {
            return
        }

        isPresenting = true
        let presented = present { [weak self] decision in
            self?.finish(report, with: decision)
        }

        guard presented else {
            isPresenting = false
            DDLogNotice("[Sentry] App cannot show the crash report alert yet, will retry.")
            scheduleRetryIfAllowed()
            return
        }

        // `retryScheduled` is deliberately not cleared here: it tracks whether a retry closure is in
        // flight, and one scheduled before this attempt still is. Clearing it would let the next failure
        // schedule a second, parallel retry chain, halving the effective retry window.
        retryCount = 0
    }

    private func finish(_ report: PendingReport, with decision: Decision) {
        pendingReports.removeAll { $0.eventID == report.eventID }

        isPresenting = false

        report.decisionHandler(decision)

        presentNextIfPossible()
    }

    private func scheduleRetryIfAllowed() {
        guard !retryScheduled else {
            return
        }

        guard retryCount < Self.maxRetries else {
            DDLogWarn(
                "[Sentry] Giving up on presenting the crash report alert for now. \(pendingReports.count) report(s) stay queued until the app becomes active again."
            )
            return
        }

        retryCount += 1
        retryScheduled = true
        scheduleRetry { [weak self] in
            guard let self else {
                return
            }
            retryScheduled = false
            presentNextIfPossible()
        }
    }

    // MARK: - Production presentation

    /// Presents the consent alert on the current top view controller, if the app can show one.
    private static func presentAlert(_ completion: @escaping @MainActor (Decision) -> Void) -> Bool {
        guard let presentingViewController = presentableViewController() else {
            return false
        }

        presentingViewController.present(alert(completion: completion), animated: true)
        return true
    }

    /// Runs `retry` on the main actor after ``retryDelay``.
    private static func scheduleRetryAfterDelay(_ retry: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: retryDelay)
            retry()
        }
    }

    private static func alert(completion: @escaping @MainActor (Decision) -> Void) -> UIAlertController {
        let confirm = UIAlertController(
            title: String.localizedStringWithFormat(
                #localize("sentry_crash_send_title"),
                TargetManager.appName
            ),
            message: #localize("sentry_crash_send_description"),
            preferredStyle: .alert
        )

        confirm.addTextField { textField in
            textField.placeholder = #localize("sentry_crash_comment_placeholder")
        }

        // `confirm` is captured weakly: the alert owns its actions, which own these handlers.
        confirm.addAction(UIAlertAction(
            title: #localize("sentry_crash_send_yes"),
            style: .default,
            handler: { [weak confirm] _ in
                let comment = confirm?.textFields?.first?.text
                completion(Decision(send: true, comment: (comment?.isEmpty ?? true) ? nil : comment))
            }
        ))

        confirm.addAction(UIAlertAction(
            title: #localize("sentry_crash_send_no"),
            style: .cancel,
            handler: { _ in
                completion(Decision(send: false, comment: nil))
            }
        ))

        return confirm
    }

    /// The view controller to present on, or `nil` while the app is in no state to show an alert the
    /// user could actually see and answer.
    ///
    /// The passcode lock lives in its own window, so an alert presented on the app window while the
    /// app is locked would be invisible but count as answered. Onboarding and license entry are
    /// excluded for the same reason.
    private static func presentableViewController() -> UIViewController? {
        guard UIApplication.shared.applicationState == .active,
              !SharedAppProvider.isAppLocked,
              !SharedAppProvider.isPresentingEnterLicense,
              !SharedAppProvider.isPresentingKeyGeneration,
              let topViewController = SharedAppProvider.currentTopViewController,
              topViewController.view.window != nil,
              !topViewController.isBeingPresented,
              !topViewController.isBeingDismissed,
              !(topViewController is UIAlertController)
        else {
            return nil
        }

        return topViewController
    }
}
