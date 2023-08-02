//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

@objc public class LaunchModalManager: NSObject {
    
    @objc static let shared = LaunchModalManager()
    
    private lazy var safeConfigManager = SafeConfigManager()
    private lazy var safeStore = SafeStore(
        safeConfigManager: safeConfigManager,
        serverApiConnector: ServerAPIConnector(),
        groupManager: GroupManager()
    )
    private lazy var safeManager = SafeManager(
        safeConfigManager: safeConfigManager,
        safeStore: safeStore,
        safeApiService: SafeApiService()
    )
    
    /// Checks if there is a launch view that needs to be displayed and does so modally if there is one
    @objc func checkLaunchModals() {
        
        // Get root view and view to show
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootView = firstScene.windows.first?.rootViewController else {
            return
        }
        
        Task {
            guard let modalType = await resolveModalType() else {
                return
            }
            
            // Display view
            Task { @MainActor in
                rootView.present(modalType.viewController(delegate: self), animated: true)
            }
        }
    }
    
    @objc func showSafePassword() {
        // Display view
        Task { @MainActor in
            // Get root view and view to show
            guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootView = firstScene.windows.first?.rootViewController else {
                return
            }
            
            if let presentedViewController = rootView.presentedViewController {
                presentedViewController.dismiss(animated: false)
            }
            
            rootView.present(LaunchModalType.safeForcePassword.viewController(delegate: self), animated: true)
        }
    }
    
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
        else if checkSafeInto() {
            return .safeSetupInfo
        }
        else if ThreemaApp.current != .onPrem,
                !AppGroup.userDefaults().bool(forKey: Constants.showedTestFlightFeedbackViewKey),
                ThreemaEnvironment.env() != .appStore {
            return .betaFeedback
        }
        
        return nil
    }
    
    private func checkForceMDMSafeBackup() -> Bool {
        
        guard let mdmSetup = MDMSetup(setup: false) else {
            return false
        }
        
        if !safeManager.isActivated, mdmSetup.isSafeBackupForce(), mdmSetup.safePassword() == nil {
            return true
        }
        
        return false
    }
    
    private func checkSafeInto() -> Bool {
        
        guard let mdmSetup = MDMSetup(setup: false) else {
            return false
        }
        
        if !safeManager.isActivated, !mdmSetup.isSafeBackupForce(), !mdmSetup.isSafeBackupDisable(),
           !LicenseStore.shared().getRequiresLicenseKey(), !UserSettings.shared().safeIntroShown {
            return true
        }
        
        return false
    }
}

// MARK: - LaunchModalManagerDelegate

// TODO: (IOS-3251) Remove
extension LaunchModalManager: LaunchModalManagerDelegate {
    func didDismiss() {
        checkLaunchModals()
    }
}

// TODO: (IOS-3251) Remove
protocol LaunchModalManagerDelegate: AnyObject {
    func didDismiss()
}
