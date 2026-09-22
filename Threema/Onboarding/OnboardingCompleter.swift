import CocoaLumberjackSwift
import GroupCalls
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import UIKit

// MARK: - OnboardingCompleting

/// Runs the post-identity steps and assembles the app container.
///
/// This is the point where onboarding stops being about the identity and starts wiring up the running app,
/// so it is the heaviest part of the flow: migrations, the notification stack and a `BusinessInjector` over
/// the real database. Keeping it behind a protocol lets `OnboardingCoordinator` be tested without any of it.
///
/// Main actor isolated, because everything it touches already is: `BootstrapContainer`,
/// `OnboardingCompletionService`, `AppLaunchManagerProtocol` and `AppDependencyContainerHelper`.
@MainActor
protocol OnboardingCompleting {

    /// - Parameters:
    ///   - remoteSecretManager: The resolved remote secret manager.
    ///   - keychainManager: The keychain manager belonging to that remote secret.
    ///   - setupConfiguration: The user's choices when coming from the setup wizard. Pass `nil` when coming
    ///     from Safe restore, which has already run migrations and Safe activation.
    ///   - bootstrapMDM: The onboarding-scoped MDM setup, owned by `OnboardingCoordinator`.
    /// - Returns: The assembled container for the running app.
    func complete(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        setupConfiguration: SetupConfiguration?,
        bootstrapMDM: any BootstrapMDMSetupProtocol
    ) async throws -> AppDependencyContainer
}

// MARK: - OnboardingCompleter

@MainActor
final class OnboardingCompleter: OnboardingCompleting {

    enum CompletionError: Error {
        case appDelegateNotAvailable
    }

    private let bootstrap: BootstrapContainer

    init(bootstrap: BootstrapContainer) {
        self.bootstrap = bootstrap
    }

    // MARK: - OnboardingCompleting

    func complete(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol,
        setupConfiguration: SetupConfiguration?,
        bootstrapMDM: any BootstrapMDMSetupProtocol
    ) async throws -> AppDependencyContainer {
        let completionService = OnboardingCompletionService(
            bootstrapIdentityStore: bootstrap.bootstrapIdentityStore,
            licenseStore: bootstrap.licenseStore,
            bootstrapUserSettings: bootstrap.bootstrapUserSettings,
            bootstrapContactStore: bootstrap.bootstrapContactStore,
            bootstrapServerAPI: bootstrap.bootstrapServerAPI,
            bootstrapPhoneNumberNormalizer: bootstrap.bootstrapPhoneNumberNormalizer,
            bootstrapMDM: bootstrapMDM,
            safeComponentsFactory: LiveSafeComponentsFactory()
        )

        let businessInjector = BusinessInjector(
            remoteSecretManager: remoteSecretManager
        )

        // Migrations — idempotent, safe to call even if already run by performRestore
        try await completionService.runMigrationsAndSetup(
            remoteSecretManager: remoteSecretManager,
            businessInjector: businessInjector
        )

        // Wizard-specific steps — only when coming from the setup wizard
        if let config = setupConfiguration {
            completionService.persistNickname(config.nickname)
            try await completionService.linkEmail(config.linkEmail)
            try await completionService.linkPhoneNumber(config.linkPhoneNumber)
            try await completionService.syncContacts(
                config.syncContacts,
                userSettings: businessInjector.userSettings
            )
            try await completionService.enableSafe(
                businessInjector: businessInjector,
                keychainManager: keychainManager,
                safePassword: config.safePassword,
                safeCustomServer: config.safeCustomServer,
                safeServerUsername: config.safeServerUsername,
                safeServerPassword: config.safeServerPassword,
                safeMaxBackupBytes: config.safeMaxBackupBytes,
                safeRetentionDays: config.safeRetentionDays
            )
        }

        try await bootstrap.appLaunchManager.runPostOnboardingSetup()

        let newMessageToaster = NewMessageToaster(
            previewSetting: UserSettings.shared(),
            bannerPresenter: DefaultNotificationBannerPresenter(),
            pushSettingManager: businessInjector.pushSettingManager,
            entityManager: businessInjector.entityManager,
            notificationCenter: .default
        )

        // Runs its body synchronously behind a serial queue, i.e. on the main thread from here. It sits
        // between two main actor isolated awaits anyway, and onboarding shows a HUD across this stretch.
        let appLaunchTask = AppLaunchTasks(businessInjector: businessInjector)
        appLaunchTask.run(launchEvent: .didFinishLaunching)

        guard let applicationDelegate = ApplicationDelegate.delegate else {
            throw CompletionError.appDelegateNotAvailable
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
                Task { @MainActor in
                    let appCoordinator = SceneDelegate.current?.rootCoordinator?.appCoordinator
                    appCoordinator?.showNotificationSettings()
                }
            }
        )

        let appContainer = AppDependencyContainerHelper.makeAndPrepareContainer(
            businessInjector: businessInjector,
            remoteSecretManager: remoteSecretManager,
            keychainManager: keychainManager,
            bootstrap: bootstrap,
            passcodeLock: KKPasscodeLockAdapter(),
            newMessageToaster: newMessageToaster,
            notificationHandler: notificationHandler,
            notificationManager: notificationManager,
            safeManager: SafeManager(groupManager: businessInjector.groupManager)
        )

        // Attach only now: attaching marks the business layer as ready (see
        // `NotificationDelegateProxy.attach`), and `makeAndPrepareContainer` had to register the
        // message processor first so a released incoming call can have its offer delivered
        notificationDelegateProxy.attach(notificationHandler)

        return appContainer
    }
}
