import Sentry
import Testing
@testable import Threema

@MainActor
struct EventSanitizerTests {

    // MARK: - Redact

    @Test("Redacts a sensitive keyword")
    func redactsSensitiveKeyword() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        #expect(sanitizer.redact(exceptionDescription: "password=hunter2", identities: []) == "***redacted***")
    }

    @Test("Keeps the text before a redacted keyword")
    func keepsTextBeforeKeyword() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        #expect(
            sanitizer.redact(exceptionDescription: "prefix blobId: 0xabc", identities: []) == "prefix ***redacted***"
        )
    }

    @Test("Redacts contact identities")
    func redactsContactIdentities() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        #expect(
            sanitizer.redact(exceptionDescription: "sent to ECHOECHO now", identities: ["ECHOECHO"])
                == "sent to ***redacted*** now"
        )
    }

    @Test("Redacts each line independently")
    func redactsPerLine() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        let input = "harmless line\npassword=secret\nanother harmless line"
        let expected = "harmless line\n***redacted***\nanother harmless line"

        #expect(sanitizer.redact(exceptionDescription: input, identities: []) == expected)
    }

    @Test("Leaves clean text untouched")
    func leavesCleanTextUntouched() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        let input = "a perfectly harmless message"
        #expect(sanitizer.redact(exceptionDescription: input, identities: []) == input)
    }

    // MARK: - Sanitize

    @Test("Strips registers from threads and exceptions")
    func stripsRegisters() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        let event = Sentry.Event()

        // swiftformat:disable:next acronyms
        let thread = Sentry.SentryThread(threadId: NSNumber(value: 0))
        thread.stacktrace = Sentry.SentryStacktrace(frames: [], registers: ["r0": "0x1"])
        event.threads = [thread]

        let exception = Sentry.Exception(value: "boom", type: "NSException")
        exception.stacktrace = Sentry.SentryStacktrace(frames: [], registers: ["r0": "0x1"])
        event.exceptions = [exception]

        sanitizer.sanitize(event)

        #expect(event.threads?.first?.stacktrace?.registers.isEmpty == true)
        #expect(event.exceptions?.first?.stacktrace?.registers.isEmpty == true)
    }

    @Test("Strips the user geo and IP address")
    func stripsUserGeoAndIPAddress() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        let event = Sentry.Event()
        let user = Sentry.User()
        user.ipAddress = "1.2.3.4"
        let geo = Sentry.Geo()
        geo.city = "Zürich"
        user.geo = geo
        event.user = user

        sanitizer.sanitize(event)

        #expect(event.user?.ipAddress == nil)
        #expect(event.user?.geo == nil)
    }

    @Test("Redacts the exception value")
    func redactsExceptionValue() {
        let sanitizer = EventSanitizer(contactIdentities: { [] })

        let event = Sentry.Event()
        event.exceptions = [Sentry.Exception(value: "password=hunter2", type: "NSException")]

        sanitizer.sanitize(event)

        #expect(event.exceptions?.first?.value == "***redacted***")
    }

    @Test("Redacts every exception of an event, not only the first")
    func redactsAllExceptionValues() {
        let sanitizer = EventSanitizer(contactIdentities: { ["ECHOECHO"] })

        let event = Sentry.Event()
        event.exceptions = [
            Sentry.Exception(value: "password=hunter2", type: "NSException"),
            Sentry.Exception(value: "sent to ECHOECHO", type: "NSException"),
            Sentry.Exception(value: "harmless", type: "NSException"),
        ]

        sanitizer.sanitize(event)

        #expect(event.exceptions?.map(\.value) == ["***redacted***", "sent to ***redacted***", "harmless"])
    }

    @Test("Looks the contact identities up once per event")
    func fetchesContactIdentitiesOnce() {
        var lookups = 0
        let sanitizer = EventSanitizer(contactIdentities: {
            lookups += 1
            return []
        })

        let event = Sentry.Event()
        event.exceptions = [
            Sentry.Exception(value: "a", type: "NSException"),
            Sentry.Exception(value: "b", type: "NSException"),
        ]

        sanitizer.sanitize(event)

        #expect(lookups == 1)
    }
}
