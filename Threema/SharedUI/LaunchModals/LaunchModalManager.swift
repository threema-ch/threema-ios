import Foundation
import RemoteSecretProtocol
import SwiftUI
import ThreemaFramework

@MainActor
final class LaunchModalManager {
    // MARK: - Private types

    /// Contains all options of modal than can be displayed on app launch in the **order** they get checked in
    private enum LaunchModalType {
        case safeForcePassword
        case notificationReminder
        case notificationTypeSelection
        case safeSetupInfo
        case showIdentityThisDeviceOnly
        case remoteSecretActivate
        case remoteSecretDeactivate
    }

    // MARK: - Public properties

    static let shared = LaunchModalManager()

    // MARK: - Private properties

    private lazy var appFlavorService = AppFlavorService()
    private lazy var groupManager = BusinessInjector.ui.groupManager
    private lazy var myIdentityStore = BusinessInjector.ui.myIdentityStore
    private lazy var safeAPIService = SafeApiService()
    private lazy var safeConfigManager = SafeConfigManager()
    private lazy var serverApiConnector = ServerAPIConnector()
    private lazy var userSettings = BusinessInjector.ui.userSettings

    private lazy var mdmSetup: MDMSetup = {
        let mdmSetup = MDMSetup()
        if mdmSetup == nil {
            assertionFailure("MDMSetup is nil")
        }
        return mdmSetup!
    }()

    private lazy var safeManager = SafeManager(
        safeConfigManager: safeConfigManager,
        safeStore: safeStore,
        safeAPIService: safeAPIService
    )

    private lazy var safeStore = SafeStore(
        safeConfigManager: safeConfigManager,
        serverApiConnector: serverApiConnector,
        groupManager: groupManager,
        myIdentityStore: myIdentityStore,
        phoneNumberNormalizer: PhoneNumberNormalizer()
    )
    
    private var remoteSecretManager: RemoteSecretManagerProtocol {
        RemoteSecretProvider.remoteSecretManager
    }

    private var topViewController: UIViewController {
        let topViewController = SharedAppProvider.currentTopViewController
        
        guard let topViewController else {
            assertionFailure("Error: Could not get top view controller.")
            return .init()
        }
        
        return topViewController
    }
    
    private var isBeingDisplayed = false
    
    // Ensure that remote secret reminder and local network check is only shown once
    private var didShowRemoteSecretReminder = false
    private var didCheckLocalNetwork = false

    // MARK: - Public methods

    /// Checks if there is a launch view that needs to be displayed and does so modally if there is one
    func checkLaunchModals() {
        Task {
            guard !isBeingDisplayed else {
                DDLogNotice("Skip checking for launch modals as one is already shown")
                return
            }
            
            isBeingDisplayed = true

            guard let modalType = await resolveModalType() else {
                // No more launch modals to show
                self.isBeingDisplayed = false

                if mdmSetup.existsMdmKey(MDM_KEY_SAFE_PASSWORD) {
                    NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupPasswordCheck), object: nil)
                }
                return
            }

            switch modalType {
            case .safeForcePassword:
                showThreemaSafePasswordScreen()

            case .safeSetupInfo:
                showThreemaSafeIntroScreen()

            case .notificationReminder:
                showNotificationReminder()

            case .notificationTypeSelection:
                showNotificationTypeSelection()

            case .showIdentityThisDeviceOnly:
                showIdentityThisDeviceOnly()
                
            case .remoteSecretActivate:
                showRemoteSecret(type: .activate)

            case .remoteSecretDeactivate:
                showRemoteSecret(type: .deactivate)
            }
        }
    }

    // MARK: - Private methods

    private func resolveModalType() async -> LaunchModalType? {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return nil
        }

        if checkForceMDMSafeBackup() {
            return .safeForcePassword
        }
        else if await UserReminder.checkPushReminder() {
            return .notificationReminder
        }
        else if await UserReminder.isPushEnabled(),
                !AppGroup.userDefaults().bool(forKey: Constants.showedNotificationTypeSelectionView) {
            return .notificationTypeSelection
        }
        else if checkSafeInfo() {
            return .safeSetupInfo
        }
        else if checkCanShowIdentityThisDeviceOnly() {
            return .showIdentityThisDeviceOnly
        }
        else if checkRemoteSecretActivate() {
            return .remoteSecretActivate
        }
        else if checkRemoteSecretDeactivate() {
            return .remoteSecretDeactivate
        }
        else if RecordPermission.access == .undetermined {
            // We ask mic permission to improve the UX for calls
            await RecordPermission.requestPermission()
            didDismiss()
            return nil
        }
        // Check this always as last
        else if didCheckLocalNetwork == false {
            // We ask for local network permission to improve the UX for calls
            LocalNetworkPermissionChecker().checkLocalNetworkPermission { _ in
                // no-op
            }
            didCheckLocalNetwork = true
            didDismiss()
            return nil
        }
        else {
            return nil
        }
    }
    
    // MARK: Checks

    private func checkForceMDMSafeBackup() -> Bool {
        if !safeManager.isActivated, mdmSetup.isSafeBackupForce(), mdmSetup.safePassword() == nil {
            return true
        }
        
        return false
    }
    
    private func checkSafeInfo() -> Bool {
        if !mdmSetup.isSafeBackupForce(),
           !mdmSetup.isSafeBackupDisable(),
           !safeManager.isActivated,
           !userSettings.safeIntroShown,
           !TargetManager.isBusinessApp {
            return true
        }
        
        return false
    }
    
    private func checkRemoteSecretActivate() -> Bool {
        (didShowRemoteSecretReminder == false) &&
            (mdmSetup.enableRemoteSecret() && remoteSecretManager.isRemoteSecretEnabled == false)
    }
    
    private func checkRemoteSecretDeactivate() -> Bool {
        (didShowRemoteSecretReminder == false) &&
            (mdmSetup.enableRemoteSecret() == false && remoteSecretManager.isRemoteSecretEnabled)
    }
    
    private func checkCanShowIdentityThisDeviceOnly() -> Bool {
        guard !UserSettings.shared().didShowIdentityThisDeviceOnly,
              let thisDeviceOnly = try? BusinessInjector.ui.keychainManager.isIdentityThisDeviceOnly(),
              thisDeviceOnly
        else {
            return false
        }
        
        return !(
            mdmSetup.existsMdmKey(MDM_KEY_DISABLE_IOS_SYSTEM_BACKUPS_ID_KEY_INCLUSION) || mdmSetup.disableBackups() || mdmSetup
                .disableSystemBackups()
        )
    }
    
    // MARK: Show modal
    
    private func didDismiss() {
        isBeingDisplayed = false
        checkLaunchModals()
    }

    private func showThreemaSafePasswordScreen() {
        let model = ThreemaSafePasswordViewModel(
            appFlavor: appFlavorService,
            myIdentityStore: myIdentityStore,
            safeConfigManager: safeConfigManager,
            safeManager: safeManager,
            mdmSetup: mdmSetup
        )

        let view = ThreemaSafePasswordView(model: model)
        let vc = UIHostingController(rootView: view)
        let navC = UINavigationController(rootViewController: vc)
        navC.isModalInPresentation = true

        topViewController.present(navC, animated: true)

        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true) { [weak self] in
                self?.didDismiss()
            }
        }
        
        model.onFinish = { [weak self] in
            self?.topViewController.dismiss(animated: true) { [weak self] in
                self?.didDismiss()
            }
        }
    }

    private func showThreemaSafeIntroScreen() {
        let model = ThreemaSafeIntroViewModel(appFlavor: appFlavorService, userSettings: userSettings)
        let view = ThreemaSafeIntroView(model: model)
        let vc = UIHostingController(rootView: view)
        let navC = UINavigationController(rootViewController: vc)

        topViewController.present(navC, animated: true)

        model.onCancel = { [weak self] in
            self?.userSettings.safeIntroShown = true
            self?.topViewController.dismiss(animated: true) { [weak self] in
                self?.didDismiss()
            }
        }

        model.onConfirm = { [weak self] in
            self?.topViewController.dismiss(animated: false) { [weak self] in
                self?.showThreemaSafePasswordScreen()
            }
        }
    }

    private func showNotificationReminder() {
        let notificationReminderView = NotificationReminderView { [weak self] in
            self?.didDismiss()
        }
        let vc = UIHostingController(rootView: notificationReminderView)
        topViewController.present(vc, animated: true)
    }

    private func showNotificationTypeSelection() {
        let notificationTypeSelectionView = NotificationTypeSelectionView { [weak self] in
            self?.didDismiss()
        }
        let vc = UIHostingController(rootView: notificationTypeSelectionView)
        topViewController.present(vc, animated: true)
    }

    private func showRemoteSecret(type: RemoteSecretActivateDeactivateViewModel.ViewType) {
        let model = RemoteSecretActivateDeactivateViewModel(type: type) { [weak self] in
            self?.didShowRemoteSecretReminder = true
            self?.didDismiss()
        }
        let view = RemoteSecretActivateDeactivateView(viewModel: model)
        let vc = UIHostingController(rootView: view)
        topViewController.present(vc, animated: true)
    }

    private func showIdentityThisDeviceOnly() {
        let view = IdentityThisDeviceOnlyDecisionView(businessInjector: BusinessInjector.ui) { [weak self] in
            self?.didDismiss()
        }
        let vc = UIHostingController(rootView: view)
        topViewController.present(vc, animated: true)
    }
}
