import Foundation
import Sentry
import ThreemaFramework

/// Strips everything that must never leave the device from a Sentry `Event`.
struct EventSanitizer {

    /// Local contact identities to redact from exception descriptions. Defaults to the Core Data store.
    var contactIdentities: () -> Set<String> = { EventSanitizer.storedContactIdentities() }

    /// Removes everything we never want to upload
    func sanitize(_ event: Sentry.Event) {
        // Remove registers
        event.threads?.forEach { $0.stacktrace?.registers = [:] }
        event.exceptions?.forEach { $0.stacktrace?.registers = [:] }

        // Remove possible user info, some info might still be added server-side
        event.user?.geo = nil
        event.user?.ipAddress = nil

        if let exceptions = event.exceptions, !exceptions.isEmpty {
            // Looked up once for the whole event instead of once per exception.
            let identities = contactIdentities()

            for exception in exceptions {
                guard let value = exception.value else {
                    continue
                }
                
                exception.value = redact(exceptionDescription: value, identities: identities)
            }
        }
    }

    /// Truncates every line from the first sensitive keyword on and replaces local contact identities.
    ///
    /// - Parameter identities: Local contact identities to redact. Passed in rather than looked up, so
    ///   an event with several exceptions queries the store once.
    func redact(exceptionDescription: String, identities: Set<String>) -> String {
        let keys = [
            "encryptionKey",
            "k:",
            "password",
            "blobId",
            "blobThumbnailId",
            "\"k\"",
            "\\\"k\\\"",
            "json",
            "text",
            // CoreData `Contact`
            "cnContactId",
            "firstName",
            "lastName",
            "publicNickname",
            "sortInitial",
        ]

        var linesArray = exceptionDescription.linesArray

        for i in 0..<linesArray.count {
            for k in keys {
                if let range = linesArray[i].range(of: k) {
                    linesArray[i] = String(linesArray[i][..<range.lowerBound]) + "***redacted***"
                }
            }
            for id in identities {
                if linesArray[i].contains(id) {
                    linesArray[i] = linesArray[i].replacingOccurrences(of: id, with: "***redacted***")
                }
            }
        }

        return linesArray.joined(separator: "\n")
    }

    /// Local contact identities from Core Data.
    ///
    /// A background injector on purpose: this runs on Sentry's queue, which must never depend on the
    /// main thread being free.
    private static func storedContactIdentities() -> Set<String> {
        BusinessInjector.ui.runInBackgroundAndWait { injector in
            injector.entityManager.entityFetcher.contactIdentities()
        }
    }
}
