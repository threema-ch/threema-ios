import Foundation
import Sentry
import ThreemaFramework

/// Identifies an event by the anonymized app device hash instead of by the user.
struct EventEnricher {

    /// Persists the anonymized app device hash. Defaults to `UserSettings`.
    var saveAppDevice: (String) -> Void = { UserSettings.shared()?.sentryAppDevice = $0 }

    /// Replaces the event's user with one identified only by the app device hash, so events can be
    /// counted per device in the Sentry UI without identifying anyone.
    func enrich(_ event: Sentry.Event) {
        guard let appDevice = event.context?["app"]?["device_app_hash"] as? String else {
            return
        }

        // Save anonymous app device, it will be displayed under Settings -> Advanced
        saveAppDevice(appDevice)

        // Send app device hash to count users per event on sentry ui
        // swiftformat:disable:next acronyms
        event.user = Sentry.User(userId: appDevice)
    }
}
