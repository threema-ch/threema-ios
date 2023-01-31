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

final class PushNotificationReminderViewController: NSObject {
    
    @MainActor
    static func create() -> ModalNavigationController {
        let topSymbol = UIImage(systemName: "exclamationmark.bubble.fill")?.withTint(Colors.red)
            .withRenderingMode(.alwaysOriginal)
        
        let configuration = ModalInfoController.UIConfiguration(
            navigationBarTitle: BundleUtil.localizedString(forKey: "push_reminder_title"),
            topSymbol: topSymbol,
            title: BundleUtil.localizedString(forKey: "push_reminder_title"),
            description: viewDescriptionText()
        )
        
        let primaryAction = ModalInfoController.Action(
            title: BundleUtil.localizedString(forKey: "push_reminder_set_now"),
            action: PushNotificationReminderViewController.primaryAction
        )
        
        let secondaryAction = ModalInfoController.Action(
            title: BundleUtil.localizedString(forKey: "push_reminder_not_now"),
            action: PushNotificationReminderViewController.secondaryAction
        )
        
        AppGroup.userDefaults().set(Date(), forKey: "PushReminderShowDate")
        
        let modalInfoController = ModalInfoController(
            configuration: configuration,
            mainAction: primaryAction,
            secondaryAction: secondaryAction
        )
        
        let modalNavigationController = ModalNavigationController()
        modalNavigationController.showDoneButton = true
        modalNavigationController.pushViewController(modalInfoController, animated: false)
        
        return modalNavigationController
    }
    
    @MainActor
    private static func viewDescriptionText() -> String {
        String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "push_reminder_message"),
            ThreemaApp.currentName,
            ThreemaApp.currentName,
            ThreemaApp.currentName
        )
    }
    
    private static func primaryAction() {
        #if compiler(>=5.7)
            var settingsURL: URL
            if #available(iOS 16.0, *) {
                settingsURL = URL(string: UIApplication.openNotificationSettingsURLString)!
            }
            else {
                // Fallback on earlier versions
                settingsURL = URL(string: UIApplication.openSettingsURLString)!
            }
            UIApplication.shared.open(settingsURL)
        #else
            let settingsURL = URL(string: UIApplication.openSettingsURLString)!
            UIApplication.shared.open(settingsURL)
        #endif
    }
    
    private static func secondaryAction() {
        AppGroup.userDefaults().set(true, forKey: "PushReminderDoNotShowAgain")
    }
}
