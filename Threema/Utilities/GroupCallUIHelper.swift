//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaMacros

@objc class GroupCallUIHelper: NSObject {
    @objc func setGlobalGroupCallsManagerSingletonUIDelegate() {
        GlobalGroupCallManagerSingleton.shared.uiDelegate = self
    }
}

// MARK: - GroupCallManagerSingletonUIDelegate

extension GroupCallUIHelper: GroupCallManagerSingletonUIDelegate {
    func showViewController(_ viewController: GroupCallViewController) {
        Task { @MainActor in
            guard AppDelegate.isAlertViewShown() == nil else {
                DDLogError("[GroupCall] Do not show GroupCallViewController because an alert is being presented.")
                return
            }
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
    
    func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        let title = #localize("group_call_alert_full_title")
        let message =
            if let maxParticipants {
                String.localizedStringWithFormat(#localize("group_call_alert_full_message_count"), maxParticipants)
            }
            else {
                #localize("group_call_alert_full_message")
            }
        
        Task { @MainActor in
            UIAlertTemplate.showAlert(
                owner: AppDelegate.shared().currentTopViewController(),
                title: title,
                message: message
            ) { _ in
                onOK()
            }
        }
    }
    
    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    ) {
        // No toast if disabled or passcode showing
        if !UserSettings.shared().inAppPreview ||
            AppDelegate.shared().isAppLocked {
            return
        }
        
        let businessInjector = BusinessInjector()

        if !businessInjector.pushSettingManager.canMasterDndSendPush() {
            return
        }
        
        guard businessInjector.entityManager.performAndWait({
            if let conversation = businessInjector.entityManager.entityFetcher
                .getManagedObject(by: conversationManagedObjectID) as? ConversationEntity {
                if let group = businessInjector.groupManager.getGroup(conversation: conversation) {
                    // We show a notification anyways when notify when mentioned is set to true
                    if !group.pushSetting.mentioned, !group.pushSetting.canSendPush() {
                        return false
                    }
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
                            "\(#localize("new_message_accessibility"))\(body)"
                        UIAccessibility.post(notification: .announcement, argument: accessibilityText)
                    }
                    return
                }
            }
            NotificationBannerHelper.newBannerForStartGroupCall(
                conversationManagedObjectID: conversationManagedObjectID,
                title: title,
                body: body,
                identifier: identifier
            )
        }
    }
}
