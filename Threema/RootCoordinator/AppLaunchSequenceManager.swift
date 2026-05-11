import FileUtility
import Foundation
import Keychain
import RemoteSecretProtocol
import ThreemaFramework
import ThreemaMacros

// MARK: - LaunchError

enum LaunchError: Error, LocalizedError {
    case databaseMigrationFailed(Error)
    case remoteSecretSetupFailed(Error)
    case encryptedDataDetected
    case keychainError

    var isRetryable: Bool {
        switch self {
        case .databaseMigrationFailed, .remoteSecretSetupFailed, .keychainError:
            true
        case .encryptedDataDetected:
            false
        }
    }

    var errorDescription: String {
        switch self {
        case .databaseMigrationFailed:
            #localize("launch_error_database_migration_failed")
        case .keychainError:
            #localize("launch_error_keychain_error")
        case .remoteSecretSetupFailed:
            #localize("launch_error_remote_secret_setup_failed")
        case .encryptedDataDetected:
            #localize("launch_error_encrypted_data_detected")
        }
    }
}

// MARK: - AppLaunchSequenceManager

/// Manages the app launch sequence, determining what state the app should be in.
/// UI-agnostic — only determines state and returns results.
/// RootCoordinator handles all UI transitions based on these results.
@MainActor
final class AppLaunchSequenceManager {
    
    // MARK: LaunchResult
    
    enum LaunchResult {
        /// App needs onboarding (no identity)
        case needsOnboarding

        /// App needs passcode entry before continuing
        case needsPasscode(BusinessInjectorProtocol)

        /// Protected data unavailable (device locked)
        case protectedDataUnavailable

        /// RemoteSecret credentials exist in keychain but the key must be fetched
        /// from the server. Requires UI: spinner + error recovery screens.
        /// After fetch completes, call `continueAfterRemoteSecretFetch(remoteSecretManager:)`.
        case needsRemoteSecretFetch

        /// App fully ready
        case ready(AppDependencyContainer)

        /// Unrecoverable error
        case failed(LaunchError)
    }

    private let bootstrap: BootstrapContainer

    /// Stored between `run()` returning `.needsRemoteSecretFetch` and the
    /// subsequent `continueAfterRemoteSecretFetch(remoteSecretManager:)` call.
    private var resolver: RemoteSecretResolver?

    init(bootstrap: BootstrapContainer) {
        self.bootstrap = bootstrap
    }

    // MARK: - Launch Sequence

    /// Runs the initial launch sequence to determine app state.
    func run() async -> LaunchResult {
        // Check if keychain is locked (device locked, protected data unavailable)
        if bootstrap.bootstrapKeychainManager.isKeychainLocked {
            return .protectedDataUnavailable
        }

        // After a device restore, UserDefaults (including AppSetup.state) survive but keychain
        // items marked "this device only" (e.g. identity) do not. Reset identity user defaults
        // if the identity is missing so isAppSetupCompleted returns false and onboarding is shown.
        do {
            if try KeychainManager.loadThreemaIdentity() == nil {
                // We always delete all ID configurations, because the restored ID might not be the same ID that was
                // used with this configuration before
                bootstrap.bootstrapIdentityStore.store.removeIdentityUserDefaults()
            }
        }
        catch {
            return .failed(.keychainError)
        }

        guard bootstrap.appLaunchManager.isAppSetupCompleted else {
            return .needsOnboarding
        }

        let resolver = RemoteSecretResolver(
            appLaunchManager: bootstrap.appLaunchManager,
            licenseStore: bootstrap.licenseStore.store,
            myIdentityStore: bootstrap.bootstrapIdentityStore.store,
            mdmSetup: bootstrap.bootstrapMDM.mdmSetup,
            flavorService: AppFlavorService(),
            hasPreexistingData: bootstrap.appLaunchManager.hasPreexistingDatabaseFile
        )
        self.resolver = resolver

        do {
            let result = try await resolver.resolve()

            switch result {
            case let .ready(remoteSecretManager, keychainManager):
                return await continueAfterRemoteSecret(
                    remoteSecretManager: remoteSecretManager,
                    keychainManager: keychainManager
                )

            case .needsFetch:
                return .needsRemoteSecretFetch

            case .encryptedDataDetected:
                return .failed(.encryptedDataDetected)
            }
        }
        catch {
            return .failed(.remoteSecretSetupFailed(error))
        }
    }

    /// Continues launch sequence after the coordinator has fetched the RemoteSecret.
    ///
    /// Called by `RootCoordinator` after presenting `RemoteSecretInitializeViewsManager`
    /// and receiving the fetched `RemoteSecretManagerProtocol`.
    func continueAfterRemoteSecretFetch(
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) async -> LaunchResult {
        guard let resolver else {
            return .failed(.remoteSecretSetupFailed(RemoteSecretResolver.ResolverError.missingInfo))
        }

        do {
            let (remoteSecretManager, keychainManager) = try resolver.continueAfterFetch(
                remoteSecretManager: remoteSecretManager
            )
            return await continueAfterRemoteSecret(
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            )
        }
        catch {
            return .failed(.remoteSecretSetupFailed(error))
        }
    }

    // MARK: - Private

    private func continueAfterRemoteSecret(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) async -> LaunchResult {
        RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

        do {
            try await SetupApp.runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretManager)
            try await SetupApp.runAppMigrationIfNeeded()

            let businessInjector = BusinessInjector(remoteSecretManager: remoteSecretManager)

            let container = AppDependencyContainer(
                businessInjector: businessInjector,
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager,
                bootstrap: bootstrap,
                wcSessionManager: WCSessionManagerAdapter()
            )
            return .ready(container)
        }
        catch {
            return .failed(.databaseMigrationFailed(error))
        }
    }
}
