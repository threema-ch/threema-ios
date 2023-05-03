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
import SwiftUI

/// Contains all options of modal than can be displayed on app launch in **order** they get checked in
public enum LaunchModalType {
    
    // Persistent
    case cancelledMultiDeviceWizard
    case safeForcePassword
    case notificationReminder
    case notificationTypeSelection
    case safeSetupInfo
    case betaFeedback
    
    /// The view controller belonging to a modal
    func viewController(delegate: LaunchModalManagerDelegate) -> UIViewController {
        switch self {
        case .cancelledMultiDeviceWizard:
            MultiDeviceWizardManager.shared.continueWizard()
            return MultiDeviceWizardManager.shared.wizardViewController()
            
        case .safeForcePassword:
            let storyBoard = AppDelegate.getMyIdentityStoryboard()
            let safeSetupNavigationController = storyBoard?
                .instantiateViewController(withIdentifier: "SafeIntroNavigationController") as! UINavigationController
            if let mdmSetup = MDMSetup(setup: false),
               mdmSetup.isSafeBackupForce() {
                safeSetupNavigationController.isModalInPresentation = true
            }
            
            let safeSetupPasswordViewController = safeSetupNavigationController
                .topViewController as! SafeSetupPasswordViewController
            safeSetupPasswordViewController.launchModalDelegate = delegate
            safeSetupPasswordViewController.isForcedBackup = true
            return safeSetupNavigationController
            
        case .notificationReminder:
            return UIHostingController(rootView: NotificationReminderView())
            
        case .notificationTypeSelection:
            return UIHostingController(rootView: NotificationTypeSelectionView())
            
        case .safeSetupInfo:
            let storyBoard = AppDelegate.getMyIdentityStoryboard()
            let safeIntroViewController = storyBoard!
                .instantiateViewController(withIdentifier: "SafeIntroViewController") as! SafeIntroViewController
            safeIntroViewController.launchModalDelegate = delegate
            return safeIntroViewController
            
        case .betaFeedback:
            return UIHostingController(rootView: BetaFeedbackView())
        }
    }
}
