import CocoaLumberjackSwift
import Keychain
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework

// MARK: - OnboardingRestoreSafeManagerDelegate

protocol OnboardingRestoreSafeManagerDelegate: AnyObject {
    func didCompleteRestoreSafe()
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

// MARK: - OnboardingRestoreSafeManager

@MainActor
final class OnboardingRestoreSafeManager {
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

    /// Downloads the Safe backup and restores the identity store. No RS needed yet.
    ///
    /// - Returns: A `SafeRestorePreparation` to be passed to `performRestore(preparation:remoteSecretManager:)`.
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

    /// Runs migrations, restores Safe data, and activates Safe.
    ///
    /// Requires RS to have been resolved externally (by the coordinator) and passed in.
    /// In the legacy flow this is called from `startRestore(with:)` after resolving RS internally.
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

    // MARK: - Legacy: single-shot (non-coordinator flow)

    /// Legacy entry point used by `RestoreSafeViewController` in the non-coordinator flow.
    /// Calls `prepareRestore` + resolves RS internally + calls `performRestore`, then
    /// notifies `delegate` on completion or failure.
    func startRestore(with info: OnboardingRestoreSafeInformation) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else {
                return
            }

            do {
                let preparation = try await prepareRestore(with: info)

                let resolver = RemoteSecretResolver(
                    appLaunchManager: AppLaunchManagerAdapter(),
                    licenseStore: licenseStore(),
                    myIdentityStore: myIdentityStore(),
                    mdmSetup: mdm.mdmSetup,
                    flavorService: AppFlavorService(),
                    hasPreexistingData: info.restoreIdentityOnly
                )

                let remoteSecretManager: any RemoteSecretManagerProtocol
                do {
                    guard case let .ready(resolvedRemoteSecretManager, _) = try await resolver.resolve() else {
                        throw SafeError.restoreError(.remoteSecretError)
                    }
                    remoteSecretManager = resolvedRemoteSecretManager
                }
                catch {
                    DDLogError(
                        "[ThreemaSafe Restore] Failed to setup remote secret with error: \(error)"
                    )
                    throw SafeError.restoreError(.remoteSecretError)
                }

                RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

                try await performRestore(
                    preparation: preparation,
                    remoteSecretManager: remoteSecretManager
                )

                delegate?.didCompleteRestoreSafe()
            }
            catch {
                DDLogError("[ThreemaSafe Restore] Error: \(error)")
                delegate?.didFail(with: error)
            }
        }
    }
}
