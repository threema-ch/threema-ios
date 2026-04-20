import ThreemaFramework

// MARK: - BootstrapMDMSetupProtocol

@MainActor
protocol BootstrapMDMSetupProtocol: AnyObject {
    var mdmSetup: MDMSetup { get }
    var disableBackups: Bool { get }
    var isSafeRestoreForced: Bool { get }
    var isSafeRestoreDisabled: Bool { get }
    var hasIDBackup: Bool { get }
    var idBackup: String? { get }
    var idBackupPassword: String? { get }
    var skipWizard: Bool { get }
    var isSafeBackupDisabled: Bool { get }
    var isSafeBackupForced: Bool { get }
    var isSafeBackupPasswordPreset: Bool { get }
    var isSafeBackupServerPreset: Bool { get }
    var safePassword: String? { get }
    var safeServerURL: String? { get }
    var safeServerUsername: String? { get }
    var safeServerPassword: String? { get }

    func loadIDCreationValues()
    func loadRenewableValues()
    func restoreIDBackup() async throws
}

// MARK: - BootstrapMDMAdapter

@MainActor
final class BootstrapMDMAdapter: NSObject, BootstrapMDMSetupProtocol {
    
    enum Error: Swift.Error {
        case restoreIDBackupFailed
    }
    
    // MARK: - Properties
    
    let mdmSetup: MDMSetup
    private let appLaunchManager: AppLaunchManagerProtocol
    
    // MARK: - Computed Properties
    
    var disableBackups: Bool {
        mdmSetup.disableBackups()
    }
    
    var isSafeRestoreForced: Bool {
        mdmSetup.isSafeRestoreForce()
    }
    
    var isSafeRestoreDisabled: Bool {
        mdmSetup.isSafeRestoreDisable()
    }
    
    var hasIDBackup: Bool {
        mdmSetup.hasIDBackup()
    }
    
    var idBackup: String? {
        mdmSetup.idBackup as String?
    }
    
    var idBackupPassword: String? {
        mdmSetup.idBackupPassword as String?
    }
    
    var skipWizard: Bool {
        mdmSetup.skipWizard()
    }
    
    var isSafeBackupDisabled: Bool {
        mdmSetup.isSafeBackupDisable()
    }
    
    var isSafeBackupForced: Bool {
        mdmSetup.isSafeBackupForce()
    }
    
    var isSafeBackupPasswordPreset: Bool {
        mdmSetup.isSafeBackupPasswordPreset()
    }
    
    var isSafeBackupServerPreset: Bool {
        mdmSetup.isSafeBackupServerPreset()
    }
    
    var safePassword: String? {
        mdmSetup.safePassword()
    }
    
    var safeServerURL: String? {
        mdmSetup.safeServerURL()
    }
    
    var safeServerUsername: String? {
        mdmSetup.safeServerUsername()
    }
    
    var safeServerPassword: String? {
        mdmSetup.safeServerPassword()
    }
    
    // MARK: - Initialization
    
    init(
        mdmSetup: MDMSetup,
        appLaunchManager: AppLaunchManagerProtocol
    ) {
        self.mdmSetup = mdmSetup
        self.appLaunchManager = appLaunchManager
    }
    
    // MARK: - Methods
    
    func loadIDCreationValues() {
        mdmSetup.loadIDCreationValues()
    }
    
    func loadRenewableValues() {
        mdmSetup.loadRenewableValues()
    }
    
    func restoreIDBackup() async throws {
        try await withCheckedThrowingContinuation { continuation in
            mdmSetup.restoreIDBackup(
                onCompletion: {
                    continuation.resume()
                },
                onError: { error in
                    continuation.resume(
                        throwing: error ?? Error.restoreIDBackupFailed
                    )
                }
            )
        }
    }
}
