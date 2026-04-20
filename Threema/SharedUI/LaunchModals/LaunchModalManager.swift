import Foundation
import SwiftUI

@MainActor
final class LaunchModalManager {
    // MARK: - Private types

    /// Contains all options of modal than can be displayed on app launch in the **order** they get checked in
    private enum LaunchModalType {
        case safeForcePassword
        case notificationReminder
        case notificationTypeSelection
        case safeSetupInfo
        case remoteSecretActivate
        case remoteSecretDeactivate
    }

    // MARK: - Public properties

    static let shared = LaunchModalManager()

    var isBeingDisplayed = false

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
        myIdentityStore: myIdentityStore
    )

    private var topViewController: UIViewController {
        guard let vc = AppDelegate.shared().currentTopViewController() else {
            assertionFailure("Error: Could not get top view controller.")
            return .init()
        }
        return vc
    }
    
    private var didCheckLocalNetworkForOnPrem = false

    // MARK: - Public methods

    /// Checks if there is a launch view that needs to be displayed and does so modally if there is one
    func checkLaunchModals() {
        Task {
            guard let modalType = await resolveModalType() else {
                // No more launch modals to show
                self.isBeingDisplayed = false

                if mdmSetup.existsMdmKey(MDM_KEY_SAFE_PASSWORD) {
                    NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupPasswordCheck), object: nil)
                }
                return
            }

            isBeingDisplayed = true

            switch modalType {
            case .safeForcePassword:
                showThreemaSafePasswordScreen()

            case .safeSetupInfo:
                showThreemaSafeIntroScreen()

            case .notificationReminder:
                showNotificationReminder()

            case .notificationTypeSelection:
                showNotificationTypeSelection()

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
        else if checkRemoteSecretActivate() {
            return .remoteSecretActivate
        }
        else if checkRemoteSecretDeactivate() {
            return .remoteSecretDeactivate
        }
        else if checkMicForOnPrem() {
            // We ask mic permission to improve the UX for calls
            await AVAudioApplication.requestRecordPermission()
            didDismiss()
            return nil
        }
        // Check this always as last
        else if checkNetworkForOnPrem() {
            // We ask for local network permission to improve the UX for calls
            LocalNetworkPermissionChecker().checkLocalNetworkPermission { _ in
                // no-op
            }
            didCheckLocalNetworkForOnPrem = true
            didDismiss()
            return nil
        }
        else {
            return nil
        }
    }

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
        guard let remoteSecretManager = AppLaunchManager.remoteSecretManager else {
            return false
        }
        
        return mdmSetup.enableRemoteSecret() && !remoteSecretManager.isRemoteSecretEnabled
    }
    
    private func checkRemoteSecretDeactivate() -> Bool {
        guard let remoteSecretManager = AppLaunchManager.remoteSecretManager else {
            return false
        }
        
        return !mdmSetup.enableRemoteSecret() && remoteSecretManager.isRemoteSecretEnabled
    }
    
    private func checkMicForOnPrem() -> Bool {
        TargetManager.isOnPrem && AVAudioApplication.shared.recordPermission == .undetermined
    }

    private func checkNetworkForOnPrem() -> Bool {
        guard TargetManager.isOnPrem else {
            return false
        }
        
        return didCheckLocalNetworkForOnPrem == false
    }

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
                self?.isBeingDisplayed = false
                self?.showThreemaSafePasswordScreen()
            }
        }
    }

    private func showNotificationReminder() {
        let vc = UIHostingController(rootView: NotificationReminderView())
        topViewController.present(vc, animated: true)
    }

    private func showNotificationTypeSelection() {
        let vc = UIHostingController(rootView: NotificationTypeSelectionView())
        topViewController.present(vc, animated: true)
    }

    private func showRemoteSecret(type: RemoteSecretActivateDeactivateViewModel.ViewType) {
        let model = RemoteSecretActivateDeactivateViewModel(type: type)
        let view = RemoteSecretActivateDeactivateView(viewModel: model)
        let vc = UIHostingController(rootView: view)
        topViewController.present(vc, animated: true)
    }
}
