import CocoaLumberjackSwift
import FileUtility
import Foundation
import Sentry
import ThreemaFramework
import ThreemaMacros

@objc final class SentryClient: NSObject {

    private static let sentryNotEnabled = "SENTRY_NOT_ENABLED"
    private static var didStart = false

    /// Tracks the active dispatch group used to block Sentry's thread while the crash report
    /// alert is presented. When the app deactivates (e.g. due to a TestFlight alert), we leave
    /// the group early to unblock Sentry's thread before willTerminate tries to sync-dispatch
    /// onto it, which would otherwise cause a deadlock.
    private var activeDispatchGroup: DispatchGroup?

    @objc override init() {
        super.init()
    }
    
    /// Create Sentry and start crash handler.
    @objc func start() {
        
        guard !SettingsBundleHelper.disableSentry else {
            return
        }
        
        guard SentryClient.isEnabled() else {
            return
        }
        
        guard !SentryClient.didStart else {
            return
        }
        
        guard let sentryDsn = BundleUtil.object(forInfoDictionaryKey: "SentryClientDsn") as? String else {
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
            
            // Enable metric kit for sandbox apps
            if TargetManager.isSandbox {
                options.enableMetricKit = true
            }
            
            // Disable breadcrumbs
            options.maxBreadcrumbs = 0
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            
            // This will be called when an event occurs
            options.beforeSend = { event in
                self.handle(event: event)
            }
        }
    }
    
    private func handle(event: Event) -> Event? {
        //  TODO: IOS-3786
        guard !Thread.isMainThread else {
            DDLogError(
                "IOS-3786: Do not process crash on main thread because we would deadlock otherwise."
            )
            return nil
        }
        
        if let appDevice = event.context?["app"]?["device_app_hash"] as? String {
            // Save anonymous app device, it will be displayed under Settings -> Advanced
            UserSettings.shared()?.sentryAppDevice = appDevice
            
            // Send app device hash to count users per event on sentry ui
            // swiftformat:disable:next acronyms
            let user = User(userId: appDevice)
            event.user = user
        }
        
        // Remove registers
        event.threads?.forEach { $0.stacktrace?.registers = [:] }
        event.exceptions?.forEach { $0.stacktrace?.registers = [:] }
        
        // Remove possible user info, some info might still be added server-side
        event.user?.geo = nil
        event.user?.ipAddress = nil
        
        if let value = event.exceptions?.first?.value {
            event.exceptions?.first?.value = redact(exceptionDescription: value)
        }
        
        var send = false

        // Show alert
        let dispatch = DispatchGroup()
        dispatch.enter()
        activeDispatchGroup = dispatch

        DispatchQueue.main.async {
            // Observe app deactivation so we can leave the group before Sentry's willTerminate
            // handler tries to sync-dispatch onto the blocked Sentry queue, preventing a deadlock.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.leaveActiveDispatchGroup),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )

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
            confirm.addAction(UIAlertAction(
                title: #localize("sentry_crash_send_yes"),
                style: .default,
                handler: { [weak self] _ in
                    if let textField = confirm.textFields?.first,
                       let text = textField.text,
                       text.isEmpty == false {
                        let feedback = SentryFeedback(
                            message: text,
                            name: nil,
                            email: nil,
                            // swiftformat:disable:next acronyms
                            associatedEventId: event.eventId
                        )
                        SentrySDK.capture(feedback: feedback)
                    }
                    send = true
                    self?.leaveActiveDispatchGroup()
                }
            ))
            confirm.addAction(UIAlertAction(
                title: #localize("sentry_crash_send_no"),
                style: .cancel,
                handler: { [weak self] _ in
                    self?.leaveActiveDispatchGroup()
                }
            ))

            DispatchQueue.main.async {
                if let vc = AppDelegate.shared()?.currentTopViewController() {
                    vc.present(confirm, animated: true, completion: nil)
                }
                else {
                    self.leaveActiveDispatchGroup()
                }
            }
        }

        dispatch.wait()

        // Clean up observer
        DispatchQueue.main.async {
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }

        if send {
            return event
        }

        return nil
    }
    
    /// Leaves the active dispatch group exactly once. Called from alert action handlers
    /// and from the willResignActive notification observer to unblock Sentry's thread.
    @objc private func leaveActiveDispatchGroup() {
        guard let group = activeDispatchGroup.take() else {
            return
        }
        
        group.leave()
    }

    private func redact(exceptionDescription: String) -> String {
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
        
        let em = BusinessInjector.ui.entityManager
        var idList: Set<String> = []
        
        em.performAndWait {
            guard let contacts = em.entityFetcher.contactEntities() else {
                return
            }
            
            for contact in contacts {
                idList.insert(contact.identity)
            }
        }
        
        for i in 0..<linesArray.count {
            for k in keys {
                if linesArray[i].contains(k) {
                    let range = linesArray[i].range(of: k)!
                    linesArray[i] = linesArray[i][..<range.lowerBound] + "***redacted***"
                }
            }
            for id in idList {
                if linesArray[i].contains(id) {
                    linesArray[i] = linesArray[i].replacingOccurrences(of: id, with: "***redacted***")
                }
            }
        }

        return linesArray.joined(separator: "\n")
    }
    
    /// Is Sentry enabled or not dependent on is file "SENTRY_NOT_ENABLED" exists in App documents directory. When the
    /// App crashes on start because of Sentry start handler, can the file adding per iTunes to disable it.
    ///
    /// - Returns: true -> start Sentry crash handler
    private static func isEnabled() -> Bool {
        !FileUtility.shared
            .fileExists(at: FileUtility.shared.appDocumentsDirectory?.appendingPathComponent(sentryNotEnabled))
    }
}
