import CocoaLumberjackSwift
import Keychain
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework

// MARK: - OnboardingRestoreSafeManagerDelegate

protocol OnboardingRestoreSafeManagerDelegate: AnyObject {
    func didFail(with error: Error)
}

// MARK: - OnboardingRestoreSafeInformation

struct OnboardingRestoreSafeInformation {
    struct Server {
        let user: String?
        let password: String?
        let url: String?
    }
    
    let identity: String
    let password: String
    let server: Server?
    let customServer: Server?
    let restoreIdentityOnly: Bool
    let activateSafeAnyway: Bool
}

// MARK: - SafeRestorePreparation

/// Returned by `prepareRestore(with:)` and consumed by
/// `performRestore(preparation:remoteSecretManager:)`.
/// Carries everything produced in phase 1 (backup download + identity restore)
/// that phase 2 (migrations + Safe restore) needs.
struct SafeRestorePreparation {
    let safeBackupData: SafeJsonParser.SafeBackupData
    let identity: String
    let password: String
    let server: OnboardingRestoreSafeInformation.Server?
    let customServer: OnboardingRestoreSafeInformation.Server?
    let restoreIdentityOnly: Bool
    let activateSafeAnyway: Bool
}

// MARK: - SafeRestoring

/// The two phases of a Safe restore, split so the caller can resolve the remote secret in between.
@MainActor
protocol SafeRestoring {
    /// Phase 1: downloads the backup and restores the identity store. No remote secret is needed yet.
    ///
    /// - Returns: A `SafeRestorePreparation` to be passed to `performRestore(preparation:remoteSecretManager:)`.
    func prepareRestore(with info: OnboardingRestoreSafeInformation) async throws -> SafeRestorePreparation

    /// Phase 2: runs migrations, restores Safe data, and activates Safe.
    ///
    /// Requires the remote secret to have been resolved externally and passed in.
    func performRestore(
        preparation: SafeRestorePreparation,
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) async throws
}

// MARK: - OnboardingRestoreSafeManager

@MainActor
final class OnboardingRestoreSafeManager: SafeRestoring {
    let mdm: BootstrapMDMSetupProtocol
    let flavorService: AppFlavorService
    let licenseStore: () -> LicenseStore
    let myIdentityStore: () -> MyIdentityStore
    private(set) weak var delegate: OnboardingRestoreSafeManagerDelegate?
    
    init(
        mdm: BootstrapMDMSetupProtocol? = nil,
        flavorService: AppFlavorService = AppFlavorService(),
        licenseStore: @escaping () -> LicenseStore = LicenseStore.shared,
        myIdentityStore: @escaping () -> MyIdentityStore = MyIdentityStore.shared,
        delegate: OnboardingRestoreSafeManagerDelegate? = nil
    ) {
        self.mdm = mdm ?? BootstrapMDMAdapter()
        self.flavorService = flavorService
        self.licenseStore = licenseStore
        self.myIdentityStore = myIdentityStore
        self.delegate = delegate
    }
    
    // MARK: - Phase 1: Prepare

    func prepareRestore(with info: OnboardingRestoreSafeInformation) async throws -> SafeRestorePreparation {
        DDLogNotice("[ThreemaSafe Restore] Restore started")

        /// Download the safe backup and parse it
        let safeBackupDataDownloader = SafeBackupDataDownloader()
        let safeBackupData = try await safeBackupDataDownloader.getSafeBackupData(
            identity: info.identity,
            safePassword: info.password,
            serverUser: info.server?.user,
            serverPassword: info.server?.password,
            server: info.server?.url
        )

        DDLogNotice("[ThreemaSafe Restore] Preparing to restore identity from backup")

        /// Extract client key — needed to restore the identity store
        guard
            let clientKeyString = safeBackupData.user?.privatekey,
            let clientKey = Data(base64Encoded: clientKeyString)
        else {
            DDLogError("[ThreemaSafe Restore] Failed to extract and encode client key from backup")
            throw SafeError.RestoreError.invalidClientKey
        }

        /// Restore identity store with backup data
        DDLogNotice("[ThreemaSafe Restore] Restoring identity store with backup data")
        let myIdentityStore = myIdentityStore()
        do {
            try await myIdentityStore.restoreFromBackup(
                identity: info.identity,
                clientKey: clientKey
            )

            /// Fetch server group and other info
            let serverAPIConnector = ServerAPIConnector()
            try await serverAPIConnector.update(myIdentityStore: myIdentityStore)
        }
        catch {
            DDLogError(
                "[ThreemaSafe Restore] Failed to restore identity store from backup with error: \(error)"
            )
            throw error
        }

        return SafeRestorePreparation(
            safeBackupData: safeBackupData,
            identity: info.identity,
            password: info.password,
            server: info.server,
            customServer: info.customServer,
            restoreIdentityOnly: info.restoreIdentityOnly,
            activateSafeAnyway: info.activateSafeAnyway
        )
    }
    
    // MARK: - Phase 2: Perform

    func performRestore(
        preparation: SafeRestorePreparation,
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) async throws {
        try await SetupApp.runDatabaseMigrationIfNeeded(
            remoteSecretManager: remoteSecretManager
        )
        
        let businessInjector = BusinessInjector(
            remoteSecretManager: remoteSecretManager
        )

        try await SetupApp.runAppMigrationIfNeeded(
            businessInjector: businessInjector
        )

        DDLogNotice("[ThreemaSafe Restore] Beginning ThreemaSafe restore")

        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: businessInjector.groupManager,
            myIdentityStore: businessInjector.myIdentityStore,
            phoneNumberNormalizer: PhoneNumberNormalizer()
        )

        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeAPIService: SafeApiService()
        )

        try await safeManager.startRestore(
            safeBackupData: preparation.safeBackupData,
            onlyIdentity: preparation.restoreIdentityOnly
        )

        /// Immediately activate Safe.
        /// In general we don't activate Safe if we restore with existing data, because this would immediately
        /// override the existing Safe backup. (Otherwise this might lead to unexpected behavior, if for some
        /// reason, the data backup actually missed some/all of the user data as experienced by the developer
        /// before)
        if !preparation.restoreIdentityOnly || preparation.activateSafeAnyway {
            DDLogNotice("[ThreemaSafe Restore] Activating ThreemaSafe")
            try await safeManager.activate(
                identity: preparation.identity,
                safePassword: preparation.password,
                customServer: preparation.customServer?.url,
                serverUser: preparation.customServer?.user,
                serverPassword: preparation.customServer?.password,
                server: preparation.server?.url,
                maxBackupBytes: nil,
                retentionDays: nil
            )
        }
        else {
            /// Show Threema Safe-Intro
            businessInjector.userSettings.safeIntroShown = false
            /// Trigger backup
            NotificationCenter.default.post(
                name: NSNotification.Name(kSafeBackupTrigger),
                object: nil
            )
        }

        DDLogNotice("[ThreemaSafe Restore] Restoring ThreemaSafe done")
    }
}
