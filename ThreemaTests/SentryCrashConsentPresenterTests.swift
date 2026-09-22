import Sentry
import Testing
@testable import Threema

@MainActor
struct SentryCrashConsentPresenterTests {

    // MARK: - Presentation

    @Test("Presents the alert when the app can show it")
    func presentsWhenPossible() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }

        #expect(fake.presentCount == 1)
    }

    @Test("Delivers the user's decision to the handler")
    func deliversDecision() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        var received: SentryCrashConsentPresenter.Decision?
        presenter.enqueue(Sentry.Event(), eventID: "a") { received = $0 }

        fake.answer(SentryCrashConsentPresenter.Decision(send: true, comment: "hi"))

        #expect(received?.send == true)
        #expect(received?.comment == "hi")
    }

    @Test("Presents only one report at a time")
    func presentsOneAtATime() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }
        presenter.enqueue(Sentry.Event(), eventID: "b") { _ in }

        #expect(fake.presentCount == 1)
    }

    @Test("Presents the next report after the current one is answered")
    func presentsNextAfterAnswer() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }
        presenter.enqueue(Sentry.Event(), eventID: "b") { _ in }

        fake.answer(SentryCrashConsentPresenter.Decision(send: false, comment: nil))

        #expect(fake.presentCount == 2)
    }

    @Test("Ignores a second report with an event ID that is already queued")
    func ignoresDuplicateEventID() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }
        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }

        fake.answer(SentryCrashConsentPresenter.Decision(send: false, comment: nil))

        // The duplicate was never queued, so answering leaves nothing to present.
        #expect(fake.presentCount == 1)
    }

    @Test("Delivers the decision of a duplicate report to a single handler")
    func duplicateEventIDGetsNoSecondHandler() {
        let fake = FakePresenter()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        var answers = 0
        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in answers += 1 }
        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in answers += 1 }

        fake.answer(SentryCrashConsentPresenter.Decision(send: true, comment: nil))

        #expect(answers == 1)
    }

    // MARK: - Retry

    @Test("Schedules a retry when the app cannot show the alert")
    func schedulesRetryWhenNotPresentable() {
        let fake = FakePresenter()
        fake.canPresent = false
        let retries = RetryRecorder()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: retries.schedule)

        var answered = false
        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in answered = true }

        #expect(fake.presentCount == 1)
        #expect(retries.count == 1)
        #expect(!answered)
    }

    @Test("Retries presentation once the app can show the alert")
    func retryPresentsWhenPossible() {
        let fake = FakePresenter()
        fake.canPresent = false
        let retries = RetryRecorder()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: retries.schedule)

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }
        #expect(fake.presentCount == 1)

        fake.canPresent = true
        retries.fireLast()

        #expect(fake.presentCount == 2)
    }

    @Test("Stops retrying after the retry limit")
    func stopsRetryingAtLimit() {
        let fake = FakePresenter()
        fake.canPresent = false
        let retries = RetryRecorder()
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: retries.schedule)

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }

        var iterations = 0
        while iterations < 1000 {
            let before = retries.count
            retries.fireLast()
            iterations += 1
            if retries.count == before {
                break
            }
        }

        #expect(iterations < 1000)
        #expect(fake.presentCount > 1)
    }

    @Test("Asks again once the passcode lock is released")
    func retriesWhenTheAppIsUnlocked() async {
        let fake = FakePresenter()
        fake.canPresent = false
        let presenter = SentryCrashConsentPresenter(present: fake.present, scheduleRetry: { _ in })

        presenter.enqueue(Sentry.Event(), eventID: "a") { _ in }
        #expect(fake.presentCount == 1)

        fake.canPresent = true
        NotificationCenter.default.post(name: .appUnlocked, object: nil)

        // The observer is registered with `queue: .main`, so it runs on a later run loop turn.
        #expect(await waitUntil { fake.presentCount == 2 })

        // Referenced after the await so the presenter — and with it its observer — outlives it.
        _ = presenter
    }
}

// MARK: - Helpers

/// Polls `condition` until it holds, and reports whether it did before the timeout.
///
/// Needed for the notification-driven retries: those observers are registered with `queue: .main`, so
/// they run on a run loop turn after the notification was posted.
@MainActor
private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock().now + timeout

    while ContinuousClock().now < deadline {
        if condition() {
            return true
        }

        try? await Task.sleep(for: .milliseconds(5))
    }

    return condition()
}

/// Controllable stand-in for the UIKit presentation.
@MainActor
private final class FakePresenter {
    private(set) var presentCount = 0
    var canPresent = true

    private var completion: (@MainActor (SentryCrashConsentPresenter.Decision) -> Void)?

    func present(_ completion: @escaping @MainActor (SentryCrashConsentPresenter.Decision) -> Void) -> Bool {
        presentCount += 1
        guard canPresent else {
            return false
        }
        self.completion = completion
        return true
    }

    /// Simulates the user tapping a button on the presented alert.
    func answer(_ decision: SentryCrashConsentPresenter.Decision) {
        let completion = completion
        self.completion = nil
        completion?(decision)
    }
}

/// Records scheduled retries so a test can fire them on demand instead of waiting.
@MainActor
private final class RetryRecorder {
    private(set) var scheduled: [@MainActor () -> Void] = []

    var count: Int { scheduled.count }

    func schedule(_ retry: @escaping @MainActor () -> Void) {
        scheduled.append(retry)
    }

    func fireLast() {
        scheduled.last?()
    }
}
