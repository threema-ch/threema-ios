import Sentry
import Testing
@testable import Threema

@MainActor
struct EventEnricherTests {

    @Test("Derives an anonymized user from the app device hash")
    func derivesAnonymizedUserFromAppDeviceHash() {
        var savedAppDevice: String?
        let enricher = EventEnricher(saveAppDevice: { savedAppDevice = $0 })

        let event = Sentry.Event()
        event.context = ["app": ["device_app_hash": "abc123"]]

        enricher.enrich(event)

        #expect(savedAppDevice == "abc123")
        // swiftformat:disable:next acronyms
        #expect(event.user?.userId == "abc123")
    }

    @Test("Leaves the event alone when it carries no app device hash")
    func withoutAppDeviceHash() {
        var savedAppDevice: String?
        let enricher = EventEnricher(saveAppDevice: { savedAppDevice = $0 })

        let event = Sentry.Event()
        event.context = ["app": [:]]

        enricher.enrich(event)

        #expect(savedAppDevice == nil)
        #expect(event.user == nil)
    }
}
