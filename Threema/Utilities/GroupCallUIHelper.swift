//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import GroupCalls

@objc class GroupCallUIHelper: NSObject {
    @objc func setGlobalGroupCallsManagerSingletonUIDelegate() {
        GlobalGroupCallsManagerSingleton.shared.uiDelegate = self
    }
}

// MARK: - GroupCallManagerSingletonUIDelegate

extension GroupCallUIHelper: GroupCallManagerSingletonUIDelegate {
    func showViewController(_ viewController: GroupCallViewController) {
        Task { @MainActor in
            AppDelegate.shared().currentTopViewController().present(viewController, animated: true)
        }
    }
    
    func showAlert(for groupCallError: GroupCallErrorProtocol) {
        Task { @MainActor in
            UIAlertTemplate.showAlert(
                owner: AppDelegate.shared().currentTopViewController(),
                title: BundleUtil.localizedString(forKey: groupCallError.alertTitleKey),
                message: BundleUtil.localizedString(forKey: groupCallError.alertMessageKey)
            )
        }
    }
    
    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        contactImage: UIImage,
        identifier: String
    ) {
        // No toast if disabled or passcode showing
        if !UserSettings.shared().inAppPreview ||
            AppDelegate.shared().isAppLocked {
            return
        }
        
        let pushSettingManager = PushSettingManager(UserSettings.shared(), LicenseStore.requiresLicenseKey())
        if !pushSettingManager.canMasterDndSendPush() {
            return
        }
        
        let entityManager = BusinessInjector().entityManager
        guard entityManager.performAndWait({
            if let conversation = entityManager.entityFetcher
                .getManagedObject(by: conversationManagedObjectID) as? Conversation,
                let pushSetting = pushSettingManager.find(forConversation: conversation) {
                
                // We show a notification anyways when notify when mentioned is set to true
                if !pushSetting.mentions, !pushSetting.canSendPush() {
                    return false
                }
            }
            
            return true
        }) else {
            return
        }

        // Is this for the currently visible conversation?
        DispatchQueue.main.async {
            if let mainTabBar = AppDelegate.getMainTabBarController(),
               let viewControllers = mainTabBar.viewControllers {
                if viewControllers.count <= kChatTabBarIndex {
                    return
                }
                let chatNavVc = viewControllers[Int(kChatTabBarIndex)] as! UINavigationController
                if let curChatVc = chatNavVc.topViewController as? ChatViewController,
                   curChatVc.conversation.objectID == conversationManagedObjectID {
                    if UIAccessibility.isVoiceOverRunning,
                       !curChatVc.isRecording(),
                       !curChatVc.isPlayingAudioMessage() {
                        let accessibilityText =
                            "\(BundleUtil.localizedString(forKey: "new_message_accessibility"))\(body)"
                        UIAccessibility.post(notification: .announcement, argument: accessibilityText)
                    }
                    return
                }
            }
            NotificationBannerHelper.newBannerForStartGroupCall(
                conversationManagedObjectID: conversationManagedObjectID,
                title: title,
                body: body,
                contactImage: contactImage,
                identifier: identifier
            )
        }
    }
}
