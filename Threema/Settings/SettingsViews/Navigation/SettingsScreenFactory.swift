import DataBackup
import FileUtility
import Foundation
import Keychain
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UIKit

/// Builds the screen for a settings destination.
///
/// This is the only place settings screens are constructed. Actions
/// (`.betaFeedback`, `.channel`, `.invite`) have no screen and resolve to `nil`;
/// `SettingsCoordinator` handles them before they ever reach a navigation path.
@MainActor
final class SettingsScreenFactory {
    weak let coordinator: SettingsCoordinator?

    init(settingsStore: SettingsStore, coordinator: SettingsCoordinator) {
        self.settingsStore = settingsStore
        self.coordinator = coordinator
    }

    private lazy var appFlavorService = AppFlavorService()

    private lazy var encryptionKeyService: any BackupEncryptionKeyServiceProtocol = {
        guard appFlavorService.isSandbox || EnvironmentType.current == .testFlight,
              BusinessInjector.ui.userSettings.localBackupDebugRecoveryKeyEnabled else {
            return BackupEncryptionKeyService(keychainManager: BusinessInjector.ui.keychainManager)
        }

        return DebugBackupEncryptionKeyService(keychainManager: BusinessInjector.ui.keychainManager)
    }()

    private lazy var safeConfigManager = SafeConfigManager()
    private lazy var safeApiService = SafeApiService()
    private lazy var serverApiConnector = ServerAPIConnector()

    lazy var backupCreateManager = BackupCreateManager(
        myIdentityStore: BusinessInjector.ui.myIdentityStore,
        userSettings: BusinessInjector.ui.userSettings,
        entityManager: BusinessInjector.ui.entityManager,
        fileUtility: FileUtility.shared,
        encryptionKeyService: encryptionKeyService,
        userDefaults: AppGroup.userDefaults(),
        dateProvider: Date.init
    )

    private lazy var safeStore = SafeStore(
        safeConfigManager: safeConfigManager,
        serverApiConnector: serverApiConnector,
        groupManager: BusinessInjector.ui.groupManager,
        myIdentityStore: BusinessInjector.ui.myIdentityStore,
        phoneNumberNormalizer: PhoneNumberNormalizer()
    )

    private lazy var safeManager = SafeManager(
        safeConfigManager: safeConfigManager,
        safeStore: safeStore,
        safeAPIService: safeApiService
    )

    let settingsStore: SettingsStore

    private let mdmSetup = MDMSetup()!

    func make(_ destination: SettingsCoordinator.InternalDestination) -> UIViewController? {
        switch destination {
        case .betaFeedback, .channel, .invite, .coordinatorDemo:
            nil

        case .developer:
            UIHostingController(
                rootView: DeveloperSettingsView(
                    onStartCoordinatorDemo: { [weak coordinator] in coordinator?.show(.coordinatorDemo) }
                )
            )

        case .privacy:
            UIHostingController(rootView: PrivacySettingsView().environmentObject(settingsStore))

        case .appearance:
            UIHostingController(rootView: AppearanceSettingsView())

        case .notifications:
            UIHostingController(rootView: NotificationSettingsView().environmentObject(settingsStore))

        case .chat:
            UIHostingController(rootView: ChatSettingsView().environmentObject(settingsStore))

        case .media:
            UIHostingController(rootView: MediaSettingsView().environmentObject(settingsStore))

        case let .backups(destination):
            makeBackupsDestinationScreen(destination)

        case .storage:
            UIHostingController(
                rootView: StorageManagementView(model: .init(businessInjector: BusinessInjector.ui))
                    .environmentObject(settingsStore)
            )

        case .passcode:
            KKPasscodeSettingsViewController(style: .insetGrouped)

        case .calls:
            UIHostingController(rootView: CallSettingsView().environmentObject(settingsStore))

        case .desktop:
            UIHostingController(rootView: LinkedDevicesView().environmentObject(settingsStore))

        case .web:
            UIHostingController(rootView: ThreemaWebSettingsView())

        case .workInfo:
            SettingsWebViewViewController(
                url: ThreemaURLProvider.workInfo,
                title: #localize("settings_threema_work"),
                allowsContentJavaScript: true
            )

        case .workReferral:
            UIHostingController(rootView: WorkReferralView())

        case .support:
            SettingsWebViewViewController(
                url: ThreemaURLProvider.supportFAQ,
                title: #localize("settings_list_support_title"),
                allowsContentJavaScript: true
            )

        case .policy:
            SettingsWebViewViewController(
                url: ThreemaURLProvider.privacyPolicy,
                title: #localize("settings_list_privacy_policy_title")
            )

        case .tos:
            SettingsWebViewViewController(
                url: ThreemaURLProvider.termsOfService,
                title: #localize("settings_list_tos_title")
            )

        case .license:
            LicenseViewController()

        case .advanced:
            UIHostingController(rootView: AdvancedSettingsView().environmentObject(settingsStore))
        }
    }

    // MARK: Helpers

    private func makeBackupsDestinationScreen(
        _ destination: SettingsCoordinator.InternalDestination.BackupsDestination
    ) -> UIViewController? {
        switch destination {
        case .center:
            UIHostingController(rootView: makeBackupCenterScreen())

        case .recoveryKey:
            hidingBottomBar(UIHostingController(rootView: makeBackupRecoveryKeyScreen()))

        case .recoveryKeyConfirmation:
            hidingBottomBar(UIHostingController(rootView: makeBackupRecoveryKeyConfirmationScreen()))

        case .settings:
            hidingBottomBar(UIHostingController(rootView: makeLocalBackupSettingsScreen()))

        case .creation:
            hidingBottomBar(UIHostingController(rootView: makeCreatingBackupScreen()))

        case .details:
            UIHostingController(rootView: makeBackupDetailsScreen())

        case .threemaSafeDashboard:
            UIHostingController(rootView: makeThreemaSafeDashboardScreen())
        }
    }

    private func hidingBottomBar(_ viewController: UIViewController) -> UIViewController {
        viewController.hidesBottomBarWhenPushed = true
        return viewController
    }

    private func makeBackupCenterScreen() -> some View {
        let model = BackupCenterViewModel(
            appFlavor: appFlavorService,
            backupManager: backupCreateManager,
            safeManager: safeManager,
            safeConfigManager: safeConfigManager
        )

        model.onSafeButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.threemaSafeDashboard))
        }

        model.onLocalDataBackupDataButtonTapped = { [weak self] in
            guard let self, let coordinator = self.coordinator else {
                return
            }
            if backupCreateManager.lastBackup != nil {
                coordinator.show(.backups(.details))
            }
            else {
                coordinator.show(.backups(.recoveryKey))
            }
        }

        model.onSafeLearnMoreButtonTapped = { [weak self] in
            guard let self else {
                return
            }
            let model = ThreemaSafeLearnMoreViewModel(appFlavor: appFlavorService)
            let rootView = NavigationStack {
                LearnMoreSheetView(model: model)
            }
            let vc = UIHostingController(rootView: rootView)
            coordinator?.presentingViewController?.present(vc, animated: true)
        }

        model.onLocalDataBackupLearnMoreButtonTapped = { [weak self] in
            guard let self else {
                return
            }
            let model = LocalBackupLearnMoreViewModel()
            let rootView = NavigationStack {
                LearnMoreSheetView(model: model)
            }
            let vc = UIHostingController(rootView: rootView)
            coordinator?.presentingViewController?.present(vc, animated: true)
        }

        return BackupCenterView(model: model)
    }

    private func makeBackupRecoveryKeyScreen() -> some View {
        let model = LocalBackupRecoveryKeyViewModel(manager: backupCreateManager)

        model.onSaveButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.recoveryKeyConfirmation))
        }

        model.onDeleteKeyConfirmed = { [weak self] in
            guard let self, let coordinator else {
                return
            }
            coordinator.show(.backups(.center), animated: false)
            coordinator.show(.backups(.details))
        }

        model.onCreateNewKeyConfirmed = { [weak self] in
            guard let self, let coordinator else {
                return
            }
            coordinator.show(.backups(.center), animated: false)
            coordinator.show(.backups(.recoveryKey))
        }

        return LocalBackupRecoveryKeyView(model: model)
    }

    func makeRecoveryKeySheet(onCreateNewKeyButtonTapped: @escaping () -> Void) -> UIViewController {
        let model = LocalBackupRecoveryKeySheetViewModel(manager: backupCreateManager)
        let viewController = ContentSizedSheetHostingController(
            rootView: LocalBackupRecoveryKeySheetView(model: model)
        )

        model.onCloseButtonTapped = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }

        model.onCreateNewKeyButtonTapped = { [weak viewController] in
            viewController?.dismiss(animated: true) {
                onCreateNewKeyButtonTapped()
            }
        }

        model.onContentHeightChange = { [weak viewController] height in
            viewController?.contentHeightChanged(height)
        }

        viewController.modalPresentationStyle = .pageSheet
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [viewController.contentSizedDetent]
            sheet.prefersGrabberVisible = true
            sheet.largestUndimmedDetentIdentifier = viewController.contentSizedDetent.identifier
        }

        return viewController
    }

    private func makeBackupRecoveryKeyConfirmationScreen() -> some View {
        let model = LocalBackupRecoveryKeyConfirmationViewModel(manager: backupCreateManager)

        model.onContinueButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.settings))
        }

        return LocalBackupRecoveryKeyConfirmationView(model: model)
    }

    private func makeThreemaSafeDashboardScreen() -> some View {
        let model = ThreemaSafeDashboardViewModel(
            appFlavor: appFlavorService,
            myIdentityStore: BusinessInjector.ui.myIdentityStore,
            mdmSetup: mdmSetup,
            notificationCenter: NotificationCenter.default,
            safeConfigManager: safeConfigManager,
            safeManager: safeManager,
            safeStore: safeStore
        )

        return ThreemaSafeDashboardView(model: model)
    }

    private func makeLocalBackupSettingsScreen() -> some View {
        let model = LocalBackupSettingsViewModel(manager: backupCreateManager)

        model.onStartButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.creation))
        }

        model.onRecoveryKeyDetailsButtonTapped = { [weak self] in
            self?.coordinator?.showRecoveryKeySlideInConfirmation()
        }

        return LocalBackupSettingsView(model: model)
    }

    private func makeCreatingBackupScreen() -> some View {
        let model = LocalBackupCreateBackupViewModel(
            manager: backupCreateManager,
            userSettings: BusinessInjector.ui.userSettings
        )

        model.onCancelButtonTapped = { [weak self] in
            self?.coordinator?.setPath([.backups(.settings)], animated: true)
        }

        model.onContinueButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.details))
        }

        model.onDismissButtonTapped = { [weak self] in
            self?.coordinator?.setPath([.backups(.settings)], animated: true)
        }

        return LocalBackupCreateBackupView(model: model)
    }

    private func makeBackupDetailsScreen() -> some View {
        let model = LocalBackupDetailsViewModel(manager: backupCreateManager)

        model.onCreateButtonTapped = { [weak self] in
            guard let self, let coordinator else {
                return
            }
            if backupCreateManager.currentRecoveryKey.isDefault {
                coordinator.show(.backups(.settings))
            }
            else {
                coordinator.show(.backups(.recoveryKey))
            }
        }

        model.onKeyActionButtonTapped = { [weak self] in
            self?.coordinator?.show(.backups(.recoveryKey))
        }

        return LocalBackupDetailsView(model: model)
    }
}
