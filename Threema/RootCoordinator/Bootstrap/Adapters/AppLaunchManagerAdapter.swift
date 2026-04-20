import CocoaLumberjackSwift
import FileUtility
import PushKit
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
    
    func runLaunchSetup(window: UIWindow) {
        // Setup app group
        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        BundleUtil.mainBundle()?.bundleIdentifier.map(AppGroup.setAppID(_:))
        
        // Setup file utility
        FileUtilityObjCSetter.setInitialFileUtility()
        
        // Initialize logger
        #if DEBUG
            LogManager.initializeGlobalLogger(debug: true)
        #else
            LogManager.initializeGlobalLogger(debug: false)
        #endif
        
        // Log app version for debugging
        DebugLog.logAppVersion()
        
        // Register if database file exists (for setup state tracking)
        AppSetup.registerIfADatabaseFileExists()
        
        // Register background tasks
        _ = ThreemaBGTaskManager.shared
        
        // Configure PromiseKit
        PromiseKitConfiguration.configurePromiseKit()
        
        // Initialize crypto
        _ = NaClCrypto.shared()
        
        // Setup server connector background state
        ServerConnector.shared().isAppInBackground = UIApplication.shared.applicationState == .background
        
        // Resolve theme
        Colors.resolveTheme()
        Colors.update(window: window)
        
        // TODO: RootCoordinator: Move this to `AppCoordinator`.
        // Setup notification center delegate
        // Note: The delegate is set to SceneDelegate or handled separately
        // We just request authorization here
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.badge, .sound, .alert, .providesAppNotificationSettings]
        ) { _, _ in }
        
        // Setup VoIP push registry
        let pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry.desiredPushTypes = [.voIP]
        
        let logFile = LogManager.appLaunchLogFile
        LogManager.deleteLogFile(logFile)
        LogManager.addFileLogger(logFile)
    }
    
    // MARK: - Post-Onboarding Setup
    
    func runPostOnboardingSetup() async throws {
        deleteBackupData()
        
        let logFile = LogManager.appSetupStepsLogFile
        LogManager.deleteLogFile(logFile)
        LogManager.addFileLogger(logFile)
        
        if TargetManager.isBusinessApp {
            await runWorkDataUpdate()
        }
        
        try await runAppSetupSteps()
        
        LogManager.removeFileLogger(logFile)
        
        AppSetup.state = .complete
        
        LogManager.deleteLogFile(logFile)
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
        await withCheckedContinuation { continuation in
            WorkDataFetcher.checkUpdateWorkDataForce(
                true,
                onCompletion: {
                    continuation.resume()
                },
                onError: { error in
                    DDLogError("Error while checking for work data update post-onboarding: \(error ?? "N/A")")
                    
                    continuation.resume()
                }
            )
        }
    }
    
    private func runAppSetupSteps() async throws {
        try await AppSetupSteps().run()
    }
}
