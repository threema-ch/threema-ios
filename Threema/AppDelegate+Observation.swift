//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import SwiftUI
import ThreemaMacros

/// Use this extension to create and handle observers that live as long as the app is running.
extension AppDelegate {
    
    @objc func registerLifetimeObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(errorWhileProcessingManagedObject(notification:)),
            name: DatabaseContext.errorWhileProcessingManagedObject,
            object: nil
        )

        // MARK: ThreemaSafe

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(companyMDMSafePasswordCheck),
            name: Notification.Name(kSafeBackupPasswordCheck),
            object: nil
        )
        
        // MARK: Screenshot detection
        
        if TargetManager.isBusinessApp {
            // Since the app might not be ready at this point to handle MDM, we check for mdm once the observers are
            // triggered.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screenshotDetected),
                name: UIApplication.userDidTakeScreenshotNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didScreenRecording(_:)),
                name: UIScreen.capturedDidChangeNotification,
                object: nil
            )
        }
    }

    @objc private func errorWhileProcessingManagedObject(notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let error = userInfo[DatabaseContext.errorKey] as? Error
        else {
            return
        }

        ErrorHandler.abort(with: error)
    }

    // If a password was provided by the company MDM, or it has changed, we inform the user and pause Threema Safe
    // backups until the user accepts the new password
    @objc private func companyMDMSafePasswordCheck() {
        
        guard AppSetup.isCompleted else {
            return
        }
        
        let safeManager = SafeManager(groupManager: BusinessInjector.ui.groupManager)
        
        let mdmSetup = MDMSetup()
        let mdmSafeEnabled = mdmSetup?.safeEnable()?.boolValue ?? false
        let wasSafeActive = safeManager.isActivated || mdmSafeEnabled

        // Compare the passwords
        if safeManager.credentialsChanged(), wasSafeActive {
            
            // Alert
            let actionConfirm = UIAlertAction(
                title: #localize("threema_safe_company_mdm_password_changed_accept"),
                style: .default
            ) { _ in
                // User has accepted new password, change safe credentials
                safeManager.deactivate()
                
                safeManager.activateThroughMDM()
                
                // Navigate to safe settings
                let mainTabBarController = AppDelegate.getMainTabBarController() as? MainTabBarController
                mainTabBarController?.showThreemaSafe()
                
                // Show toast
                NotificationPresenterWrapper.shared.present(type: .safePasswordAccepted)
            }
                        
            Task.detached {
                Task { @MainActor in
                    // Do not show if an alert or launch modals are being shown
                    guard AppDelegate.isAlertViewShown() == nil, !LaunchModalManager.shared.isBeingDisplayed else {
                        return
                    }
                    
                    UIAlertTemplate.showTimedAlert(
                        owner: AppDelegate.shared().currentTopViewController(),
                        title: String.localizedStringWithFormat(
                            #localize("threema_safe_company_mdm_password_changed_title"),
                            TargetManager.localizedAppName
                        ),
                        message: #localize("threema_safe_company_mdm_password_changed_message"),
                        action1: UIAlertAction(title: #localize("cancel"), style: .cancel),
                        action2: actionConfirm,
                        enableActionsAfter: 5
                    )
                }
            }
        }
    }

    @objc private func screenshotDetected() {
        showScreenshotPrevention()
    }

    @objc private func didScreenRecording(_ notification: Notification) {
        if UIScreen.main.isCaptured {
            showScreenshotPrevention()
        }
    }

    private func showScreenshotPrevention() {
        guard TargetManager.isBusinessApp, MDMSetup().disableScreenshots() else {
            return
        }
        
        Task { @MainActor in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            let privacyView = UIHostingController(rootView: ScreenshotPreventionView()).view!
            
            privacyView.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(privacyView)

            NSLayoutConstraint.activate([
                privacyView.topAnchor.constraint(equalTo: window.topAnchor),
                privacyView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                privacyView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                privacyView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            ])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                privacyView.removeFromSuperview()
            }
        }
    }
}
