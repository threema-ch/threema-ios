import FileUtility
import Foundation
import GroupCalls
import Keychain
import PushKit
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

// MARK: - LaunchError

struct LaunchRemoteSecretError: Error, LocalizedError {
    enum Code {
        case timeout
        case blocked
        case mismatch
        case general(Error)
        
        var isRetryable: Bool {
            switch self {
            case .timeout, .general, .mismatch:
                true
            case .blocked:
                false
            }
        }
    }
    
    let code: Code
    let enableDeletion: Bool
    
    var isRetryable: Bool {
        self.code.isRetryable
    }
    
    var localizedTitle: String {
        switch self.code {
        case .timeout:
            #localize("rs_view_disconnected_title")
        case .blocked:
            #localize("rs_view_locked_title")
        case .mismatch:
            #localize("rs_view_mismatch_title")
        case .general:
            #localize("rs_view_failed_title")
        }
    }
    
    var errorDescription: String? {
        switch self.code {
        case .timeout:
            #localize("rs_view_disconnected_description")
        case .blocked:
            #localize("rs_view_locked_description")
        case .mismatch:
            #localize("rs_view_mismatch_description")
        case .general:
            #localize("rs_view_failed_description")
        }
    }
}

enum LaunchError: Error, LocalizedError {
    case databaseMigrationFailed(Error)
    case remoteSecretSetupFailed(LaunchRemoteSecretError)
    case encryptedDataDetected
    case keychainError
    case appDelegateNotAvailable

    var isRetryable: Bool {
        switch self {
        case .databaseMigrationFailed, .keychainError:
            true
        case .encryptedDataDetected, .appDelegateNotAvailable:
            false
        case let .remoteSecretSetupFailed(error):
            error.isRetryable
        }
    }

    var errorDescription: String? {
        switch self {
        case .databaseMigrationFailed:
            #localize("launch_error_database_migration_failed")
        case .keychainError:
            #localize("launch_error_keychain_error")
        case let .remoteSecretSetupFailed(error):
            error.errorDescription
        case .encryptedDataDetected:
            #localize("launch_error_encrypted_data_detected")
        case .appDelegateNotAvailable:
            #localize("launch_error_app_delegate_not_available")
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
        case needsPasscode(AppDependencyContainer)

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

    typealias AppSetupStateResolver = () -> (state: AppSetupState, unavailable: AppSetup.StateUnavailableReason?)

    private let bootstrap: BootstrapContainer

    private let loadThreemaIdentity: () throws -> ThreemaIdentity?

    private let resolveAppSetupState: AppSetupStateResolver

    /// How often the identity keychain read is repeated before concluding the identity is genuinely
    /// gone. See ``isIdentityConfirmedMissing()``.
    private let missingIdentityConfirmationAttempts: Int

    /// Delay between identity confirmation reads.
    private let missingIdentityConfirmationDelay: Duration?

    /// Stored between `run()` returning `.needsRemoteSecretFetch` and the
    /// subsequent `continueAfterRemoteSecretFetch(remoteSecretManager:)` call.
    private var resolver: RemoteSecretResolver?
    
    private var remoteSecretFailureCount = 0
    private let remoteSecretDeleteOptionThreshold = 5

    init(
        bootstrap: BootstrapContainer,
        loadThreemaIdentity: @escaping () throws -> ThreemaIdentity? = {
            try KeychainManager.loadThreemaIdentity()
        },
        resolveAppSetupState: @escaping AppSetupStateResolver = {
            AppSetup.resolveState()
        },
        missingIdentityConfirmationAttempts: Int = 5,
        missingIdentityConfirmationDelay: Duration? = .milliseconds(250)
    ) {
        self.bootstrap = bootstrap
        self.loadThreemaIdentity = loadThreemaIdentity
        self.resolveAppSetupState = resolveAppSetupState
        self.missingIdentityConfirmationAttempts = max(1, missingIdentityConfirmationAttempts)
        self.missingIdentityConfirmationDelay = missingIdentityConfirmationDelay
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
            if try await isIdentityConfirmedMissing() {
                // We end up here after an iOS data backup restore, because the ID won't be around. In that case we
                // reset the configuration for the previous ID, which also resets the `AppSetup` `state`

                // We always delete all ID configurations, because the restored ID might not be the same ID that was
                // used with this configuration before
                bootstrap.bootstrapIdentityStore.store.removeIdentityUserDefaults()
            }
        }
        catch {
            return .failed(.keychainError)
        }

        // Whenever the state key is absent (a first launch, or `removeIdentityUserDefaults()` above having just
        // cleared it) reading the setup state recomputes it from the keychain. That read can fail even though
        // the two reads above succeeded: they are separate calls, and `isKeychainLocked` reports everything but
        // `errSecInteractionNotAllowed` as unlocked. A failed read yields `.notSetup`, which is
        // indistinguishable from a genuine fresh install and would both authorize the keychain cleanup below
        // and send a fully set up user into onboarding, where creating an ID makes the mistake permanent.
        //
        // So resolve it once, up front, and route "cannot tell" to a retryable screen instead of an
        // irreversible path. Once this passes, the recomputed state has been persisted, so the reads further
        // down hit the stored value and cannot come back undetermined.
        let (appSetupState, stateUnavailable) = resolveAppSetupState()
        switch stateUnavailable {
        case nil:
            break
        case .protectedDataUnavailable?:
            return .protectedDataUnavailable
        case .keychainUnreadable?:
            return .failed(.keychainError)
        }

        // If a user deletes an RS-enabled app from the Home Screen all information is still in the keychain, but
        // there is no preexisting data (and thus the `AppSetupState` is `notSetup`). In this case we delete all
        // RS-related data in keychain. As soon as `AppSetupState` is not `notSetup` anymore an ID was created or
        // restored and any potential new RS created. Thus we don't delete anything.
        // TODO: (IOS-6025) Can we generalize this cleanup?
        do {
            if KeychainManager.hasRemoteSecretInStore(),
               !bootstrap.appLaunchManager.hasPreexistingDatabaseFile,
               appSetupState == .notSetup {
                try KeychainManager.deleteAllEncryptedItems()
                try KeychainManager.deleteRemoteSecret()
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
            isRemoteSecretEnabledByMDM: {
                fatalError("Unreachable: isRemoteSecretEnabledByMDM is never consulted once setup is completed")
            },
            flavorService: AppFlavorService(),
            hasPreexistingData: bootstrap.appLaunchManager.hasPreexistingDatabaseFile
        )
        self.resolver = resolver

        do {
            let result = try await resolver.resolve()

            switch result {
            case let .ready(remoteSecretManager, keychainManager):
                remoteSecretFailureCount = 0
                return await continueAfterRemoteSecret(
                    resolver: resolver,
                    remoteSecretManager: remoteSecretManager,
                    keychainManager: keychainManager
                )

            case .needsFetch:
                remoteSecretFailureCount = 0
                return .needsRemoteSecretFetch

            case .encryptedDataDetected:
                remoteSecretFailureCount += 1
                return .failed(.encryptedDataDetected)
            }
        }
        catch RemoteSecretResolver.ResolverError.blocked {
            return remoteSecretFailed(with: .blocked)
        }
        catch RemoteSecretResolver.ResolverError.timeout {
            return remoteSecretFailed(with: .timeout)
        }
        catch RemoteSecretResolver.ResolverError.mismatch {
            return remoteSecretFailed(with: .mismatch)
        }
        catch {
            return remoteSecretFailed(with: .general(error))
        }
    }

    /// Confirms whether the Threema identity is *genuinely* absent from the keychain.
    ///
    /// A single `nil` read is not trusted. While protected data is becoming available (e.g. right
    /// after tapping an "open to fetch" push while the Notification Extension is still accessing the
    /// keychain), an existing identity item can transiently read as `errSecItemNotFound`, even though
    /// `isKeychainLocked` (which only detects `errSecInteractionNotAllowed`) reports the keychain as
    /// unlocked. Because the caller reacts to a missing identity by permanently resetting
    /// `AppSetupState`, a transient miss would force a fully set up app into onboarding forever.
    ///
    /// The read is therefore repeated: a device restore keeps the identity missing across every
    /// attempt, whereas a transient clears. Returns `true` only if every attempt reads `nil`. A
    /// keychain *error* is rethrown (so it is routed to `.failed(.keychainError)`), never mistaken for
    /// a genuinely missing identity.
    func isIdentityConfirmedMissing() async throws -> Bool {
        for attempt in 0..<missingIdentityConfirmationAttempts {
            if try loadThreemaIdentity() != nil {
                return false
            }

            let isLastAttempt = attempt == missingIdentityConfirmationAttempts - 1
            if !isLastAttempt, let missingIdentityConfirmationDelay {
                try? await Task.sleep(for: missingIdentityConfirmationDelay)
            }
        }

        return true
    }

    /// Continues launch sequence after the coordinator has fetched the RemoteSecret.
    ///
    /// Called by `RootCoordinator` after presenting `RemoteSecretInitializeViewsManager`
    /// and receiving the fetched `RemoteSecretManagerProtocol`.
    func continueAfterRemoteSecretFetch(
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) async -> LaunchResult {
        guard let resolver else {
            return remoteSecretFailed(with: .general(RemoteSecretResolver.ResolverError.missingInfo))
        }

        do {
            let (remoteSecretManager, keychainManager) = try resolver.continueAfterFetch(
                remoteSecretManager: remoteSecretManager
            )
            return await continueAfterRemoteSecret(
                resolver: resolver,
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager
            )
        }
        catch {
            return remoteSecretFailed(with: .general(error))
        }
    }

    // MARK: - Private

    private func continueAfterRemoteSecret(
        resolver: any RemoteSecretResolving,
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) async -> LaunchResult {
        RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)

        do {
            try await SetupApp.runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretManager)
            
            let businessInjector = BusinessInjector(remoteSecretManager: remoteSecretManager)
            
            try await SetupApp.runAppMigrationIfNeeded(businessInjector: businessInjector)
            
            // TODO: (IOS-6555) Validate if this is the correct point for the sync
            try resolver.syncKeychain(with: keychainManager)

            let passcodeLock = KKPasscodeLockAdapter()
            
            let newMessageToaster = NewMessageToaster(
                previewSetting: UserSettings.shared(),
                bannerPresenter: DefaultNotificationBannerPresenter(),
                pushSettingManager: businessInjector.pushSettingManager,
                entityManager: businessInjector.entityManager,
                notificationCenter: .default
            )
            
            let appLaunchTask = AppLaunchTasks(businessInjector: businessInjector)
            appLaunchTask.run(launchEvent: .didFinishLaunching)
            
            guard let applicationDelegate = ApplicationDelegate.delegate else {
                return .failed(.appDelegateNotAvailable)
            }
            
            let notificationDelegateProxy = applicationDelegate.notificationDelegateProxy
            let notificationManager = NotificationManagerFactory(
                businessInjector: businessInjector
            ).make()
            
            let notificationHandler = NotificationHandler(
                notificationManager: notificationManager,
                notificationResponseFactory: NotificationResponseFactory(businessInjector: businessInjector),
                serverConnector: businessInjector.serverConnector,
                isAppActive: {
                    SharedAppProvider.isAppActive
                },
                showNotificationSettings: {
                    SceneDelegate.current?.rootCoordinator?.appCoordinator?.showNotificationSettings()
                }
            )
            // Deliberately NOT attached to the proxy here: a notification response
            // queued during a cold start (tap on a push) would be replayed into a
            // UI that does not exist yet. `RootCoordinator.goToApp` attaches the
            // handler once the app UI is installed.
            
            let container = AppDependencyContainerHelper.makeAndPrepareContainer(
                businessInjector: businessInjector,
                remoteSecretManager: remoteSecretManager,
                keychainManager: keychainManager,
                bootstrap: bootstrap,
                passcodeLock: passcodeLock,
                newMessageToaster: newMessageToaster,
                notificationHandler: notificationHandler,
                notificationManager: notificationManager,
                safeManager: SafeManager(groupManager: businessInjector.groupManager)
            )

            // Unblocks the follow-up work of a VoIP push that arrived during this launch. Before
            // the passcode gate on purpose: the message processor is registered by now, so an
            // incoming call can connect even while the passcode screen is up.
            notificationDelegateProxy.businessDidBecomeReady()

            guard !passcodeLock.isPasscodeRequired() else {
                return .needsPasscode(container)
            }

            return .ready(container)
        }
        catch {
            return .failed(.databaseMigrationFailed(error))
        }
    }
    
    private func remoteSecretFailed(with code: LaunchRemoteSecretError.Code) -> LaunchResult {
        if code.isRetryable {
            remoteSecretFailureCount += 1
        }
        
        return .failed(.remoteSecretSetupFailed(
            LaunchRemoteSecretError(
                code: code,
                enableDeletion: remoteSecretFailureCount > remoteSecretDeleteOptionThreshold
            )
        ))
    }
}
