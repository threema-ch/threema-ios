import CocoaLumberjackSwift
import FileUtility
import ThreemaFramework
import UIKit

// MARK: - AppLaunchManagerProtocol

@MainActor
protocol AppLaunchManagerProtocol: AnyObject {
    var isAppSetupCompleted: Bool { get }
    var hasPreexistingDatabaseFile: Bool { get }
    var isDatabaseEncrypted: Bool { get }
    var shouldDirectlyShowSetupWizard: Bool { get }
    var isBusinessApp: Bool { get }
    
    func runSetupForApplicationDelegateInitialization()
    func runSetupForApplicationDidFinishLaunchingWithOptions()
    
    /// Runs the pre-launch setup required before any UI can be presented.
    /// This includes: BG task registration, PromiseKit config, crypto init,
    /// theme setup, notification setup, etc.
    /// - Parameter window: The window to configure themes for
    func runLaunchSetup(window: UIWindow)
    
    /// Runs the post-onboarding setup steps after identity creation/restoration.
    func runPostOnboardingSetup() async throws
}

// MARK: - AppLaunchManagerAdapter

final class AppLaunchManagerAdapter: AppLaunchManagerProtocol {
    
    private var manager: AppLaunchManager {
        AppLaunchManager.shared
    }

    private var observers: [any NSObjectProtocol] = []
    
    var isAppSetupCompleted: Bool {
        manager.isAppSetupCompleted
    }
    
    var hasPreexistingDatabaseFile: Bool {
        AppSetup.hasPreexistingDatabaseFile
    }
    
    var isDatabaseEncrypted: Bool {
        DatabaseManager.isExistingDBEncrypted()
    }
    
    var shouldDirectlyShowSetupWizard: Bool {
        AppSetup.shouldDirectlyShowSetupWizard
    }
    
    var isBusinessApp: Bool {
        TargetManager.isBusinessApp
    }
    
    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func runSetupForApplicationDelegateInitialization() {
        AppLaunchManager.preLaunchSetup()
    }
    
    func runSetupForApplicationDidFinishLaunchingWithOptions() {
        ThreemaBGTaskManager.shared.registerTasks()

        UIApplication.shared.registerForRemoteNotifications()

        let categories = NotificationActionProvider().defaultCategories
        UNUserNotificationCenter.current().setNotificationCategories(categories)

        registerLifetimeObservers()
    }

    // MARK: - Lifetime Observers

    private func registerLifetimeObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: DatabaseContext.errorWhileProcessingManagedObject,
            object: nil,
            queue: .main,
            using: { notification in
                guard
                    let userInfo = notification.userInfo as? [String: Any],
                    let error = userInfo[DatabaseContext.errorKey] as? Error
                else {
                    return
                }
                ErrorHandler.abort(with: error)
            }
        ))
    }
    
    func runLaunchSetup(window: UIWindow) {
        // Initialize crypto
        _ = NaClCrypto.shared()
        
        // Setup server connector background state
        ServerConnector.shared().isAppInBackground = UIApplication.shared.applicationState == .background
        
        // Resolve theme
        Colors.resolveTheme()
        Colors.update(window: window)

        LogManager.clearLoggerOutput(for: .appLaunchFileLog)
        LogManager.addLogger(for: .appLaunchFileLog)
    }
    
    // MARK: - Post-Onboarding Setup
    
    func runPostOnboardingSetup() async throws {
        deleteBackupData()
        
        LogManager.clearLoggerOutput(for: .appSetupStepsFileLog)
        LogManager.addLogger(for: .appSetupStepsFileLog)

        if TargetManager.isBusinessApp {
            await runWorkDataUpdate()
        }
        
        try await runAppSetupSteps()
        
        LogManager.removeLogger(for: .appSetupStepsFileLog)

        AppSetup.state = .complete
        
        LogManager.clearLoggerOutput(for: .appSetupStepsFileLog)
    }
    
    // MARK: - Private Helpers
    
    private func deleteBackupData() {
        let fileUtility = FileUtility()
        
        guard
            let backupURL = fileUtility.appDocumentsDirectory?
            .appendingPathComponent("safe-backup.json")
        else {
            return
        }
        
        fileUtility.deleteIfExists(at: backupURL)
    }
    
    private func runWorkDataUpdate() async {
        do {
            let fetcher = BusinessInjector.ui.workDataFetcher
            try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        }
        catch {
            DDLogError("Error while checking for work data update post-onboarding: \(error)")
        }
    }
    
    private func runAppSetupSteps() async throws {
        try await AppSetupSteps().run()
    }
}
