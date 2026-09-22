import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaMacros

enum GroupCallUIHelper {
    static func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    ) {
        // No toast if disabled
        if !UserSettings.shared().inAppPreview {
            return
        }

        let businessInjector = BusinessInjector.ui

        if !businessInjector.pushSettingManager.canMasterDndSendPush() {
            return
        }

        guard businessInjector.entityManager.performAndWait({
            if let conversation = businessInjector.entityManager.entityFetcher
                .managedObject(with: conversationManagedObjectID) as? ConversationEntity {
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
        Task { @MainActor in
            if let mainTabBar = SharedAppProvider.tabBarController,
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
