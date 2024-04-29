//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import ThreemaEssentials

public protocol UserNotificationManagerProtocol {
    func userNotificationContent(_ pendingUserNotification: PendingUserNotification) -> UserNotificationContent?
    func testNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    func applyContent(
        _ from: UserNotificationContent,
        _ to: inout UNMutableNotificationContent,
        _ silent: Bool,
        _ baseMessage: BaseMessage?
    )
}

public class UserNotificationManager: UserNotificationManagerProtocol {
    private let settingsStore: SettingsStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private let contactStore: ContactStoreProtocol
    private let groupManager: GroupManagerProtocol
    private let entityManager: EntityManager
    private let isWorkApp: Bool
    
    public init(
        _ settingsStore: SettingsStoreProtocol,
        _ userSettings: UserSettingsProtocol,
        _ myIdentityStore: MyIdentityStoreProtocol,
        _ pushSettingManager: PushSettingManagerProtocol,
        _ contactStore: ContactStoreProtocol,
        _ groupManager: GroupManagerProtocol,
        _ entityManager: EntityManager,
        _ isWorkApp: Bool
    ) {
        self.settingsStore = settingsStore
        self.userSettings = userSettings
        self.myIdentityStore = myIdentityStore
        self.pushSettingManager = pushSettingManager
        self.contactStore = contactStore
        self.groupManager = groupManager
        self.entityManager = entityManager
        self.isWorkApp = isWorkApp
    }
    
    // MARK: - Public functions
    
    /// Get the best infos for user notification on the basis of the threema push, abstract or base (DB) message.
    ///
    /// - Parameter pendingUserNotification: Incoming processing message
    /// - Returns: User notification content or `nil` if should no user notification should be shown or if the user
    ///            notification is handled otherwise
    public func userNotificationContent(_ pendingUserNotification: PendingUserNotification)
        -> UserNotificationContent? {
        
        // We run some Pre-Checks, regardless of state
        guard shouldShowPush(for: pendingUserNotification) else {
            return nil
        }
        
        // We begin assembling the content
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        // Set group infos if they are available
        if let (groupID, groupCreator) = groupInfos(for: pendingUserNotification) {
            userNotificationContent.groupID = groupID
            userNotificationContent.groupCreator = groupCreator
        }

        let fromName = fromName(for: pendingUserNotification)
            
        // Set the name
        userNotificationContent.fromName = fromName
        
        // Set the title
        if settingsStore.pushShowPreview {
            userNotificationContent.title = titleWithPreview(
                for: pendingUserNotification,
                fromName: fromName
            )
        }
        else {
            userNotificationContent.title = fromName
        }
        
        // Set the body
        if settingsStore.pushShowPreview {
            userNotificationContent.body = bodyWithPreview(
                for: pendingUserNotification,
                fromName: fromName
            )
        }
        else {
            userNotificationContent.body = bodyWithoutPreview(for: pendingUserNotification)
        }
        
        // Add thumbnail attachment if file, image or video message
        if settingsStore.pushShowPreview, let (name, url) = addAttachment(for: pendingUserNotification) {
            userNotificationContent.attachmentName = name
            userNotificationContent.attachmentURL = url
        }
        
        return userNotificationContent
    }
    
    /// Get content for test notification.
    /// - Parameter payload: Information about test push
    /// - Returns: User notification for user notification center
    public func testNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        var pushText = "PushTest"
        if let aps = payload["aps"] as? [AnyHashable: Any] {
            if let alert = aps["alert"] {
                pushText = "\(pushText): \(alert)"
            }
        }
        let notificationContent = UNMutableNotificationContent()
        notificationContent.body = pushText

        if let pushSound = userSettings.pushSound, pushSound != "none" {
            notificationContent
                .sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound + ".caf"))
        }

        notificationContent.badge = 999

        return notificationContent
    }
    
    /// Get content for threema web notification.
    /// - Parameter payload: Information about threema web push
    /// - Returns: User notification for user notification center
    public func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = BundleUtil.localizedString(forKey: "notification.threemaweb.connect.title")
        notificationContent.body = BundleUtil.localizedString(forKey: "notification.threemaweb.connect.body")
        notificationContent.userInfo = payload

        if let pushSound = userSettings.pushSound, pushSound != "none" {
            notificationContent
                .sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound + ".caf"))
        }

        return notificationContent
    }
    
    /// Apply user notification to notification content.
    ///
    /// - Parameter from: User notification content data
    /// - Parameter to: Effective notification content for notification center
    /// - Parameter silent: If false than sound will played for the notification
    public func applyContent(
        _ from: UserNotificationContent,
        _ to: inout UNMutableNotificationContent,
        _ silent: Bool,
        _ baseMessage: BaseMessage?
    ) {
        
        var pushSound: String = from.categoryIdentifier.elementsEqual("GROUP") ? userSettings
            .pushGroupSound : userSettings.pushSound
        
        if from.isGroupCallStartMessage() {
            pushSound = "threema_best"
        }
        
        to.title = from.title ?? ""
        to.body = from.body ?? ""
        
        let isPrivate = isPrivate(content: from)
        
        if isPrivate {
            to.title = BundleUtil.localizedString(forKey: "private_message_label")
            to.body = ""
        }
        
        if !pushSound.elementsEqual("none") && !silent {
            to.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(pushSound).caf"))
        }
        
        if !isPrivate, let attachmentName = from.attachmentName, let attachmentURL = from.attachmentURL {
            if let attachment = try? UNNotificationAttachment(
                identifier: attachmentName,
                url: attachmentURL,
                options: nil
            ) {
                to.attachments.append(attachment)
            }
        }

        let unreadMessages = UnreadMessages(entityManager: entityManager, taskManager: TaskManager())
        var badge = unreadMessages.totalCount()
        
        // Update app badge, +1 if message is not saved in core data
        if from.stage == .initial || from.stage == .abstract {
            badge += 1
        }
        to.badge = NSNumber(integerLiteral: badge)
        
        to.userInfo = from.userInfo
        
        if from.categoryIdentifier.elementsEqual("SINGLE") || from.categoryIdentifier.elementsEqual("GROUP") {
            to.categoryIdentifier = userSettings.pushDecrypt ? from.categoryIdentifier : ""
        }
        else {
            to.categoryIdentifier = from.categoryIdentifier
            to.categoryIdentifier = from.categoryIdentifier
        }
        
        // Group notifications
        if from.categoryIdentifier.elementsEqual("SINGLE") {
            to.threadIdentifier = "SINGLE-\(from.senderID!)"
        }
        else if from.categoryIdentifier.elementsEqual("GROUP"),
                let groupID = from.groupID, let groupCreator = from.groupCreator {
            
            to.threadIdentifier = "GROUP-\(groupID)-\(groupCreator)"
        }
    }
    
    // MARK: - Private functions
    
    private func saveAttachment(
        _ image: ImageData,
        _ id: String,
        _ stage: UserNotificationStage
    ) -> (name: String, url: URL)? {
        guard let imageData = image.data else {
            return nil
        }
        
        if let tmpDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last {
            let attachmentDirectory = "\(tmpDirectory)/PushImages"
            let attachmentName = "PushImage_\(id)_\(stage)"
            let attachmentURL = URL(fileURLWithPath: "\(attachmentDirectory)/\(attachmentName).jpg")
            
            let fileManager = FileManager.default
            
            do {
                if !fileManager.fileExists(atPath: attachmentDirectory) {
                    try fileManager.createDirectory(
                        at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true),
                        withIntermediateDirectories: false,
                        attributes: nil
                    )
                }
                if fileManager.fileExists(atPath: attachmentURL.absoluteString) {
                    try fileManager.removeItem(at: attachmentURL)
                }
                
                try imageData.write(to: attachmentURL, options: .completeFileProtectionUntilFirstUserAuthentication)
                
                return (name: attachmentName, url: attachmentURL)
            }
            catch {
                DDLogError("Could not save attachment: \(error.localizedDescription)")
            }
        }
        else {
            DDLogError("Could not find cache directory.")
        }
        
        return nil
    }
    
    private func shouldShowPush(for pendingUserNotification: PendingUserNotification) -> Bool {
        
        // Are push even enabled?
        if !pushSettingManager.canMasterDndSendPush() {
            return false
        }
        
        // Is sender blocked?
        guard let senderIdentity = pendingUserNotification.senderIdentity,
              !userSettings.blacklist.contains(senderIdentity) else {
            return false
        }
        
        // Is blockUnknown active?
        if entityManager.entityFetcher.contact(for: senderIdentity) == nil, userSettings.blockUnknown {
            return false
        }
        
        // AbstractMessage checks
        if let abstractMessage = pendingUserNotification.abstractMessage {
            
            if abstractMessage is GroupCallStartMessage,
               !BusinessInjector().settingsStore.enableThreemaGroupCalls {
                return false
            }
            
            guard abstractMessage.flagShouldPush(), !abstractMessage.flagImmediateDeliveryRequired(),
                  !abstractMessage.flagIsVoIP() else {
                return false
            }
        }
        
        // Are we still member?
        if let groupMessage = pendingUserNotification.abstractMessage as? AbstractGroupMessage {
            guard let group = groupManager.getGroup(groupMessage.groupID, creator: groupMessage.groupCreator),
                  !group.didLeave, !group.didForcedLeave else {
                return false
            }
        }
        
        // BaseMessage checks
        if let flags = pendingUserNotification.baseMessage?.flags {
            guard flags.intValue & Int(MESSAGE_FLAG_SEND_PUSH) != 0,
                  flags.intValue & Int(MESSAGE_FLAG_IMMEDIATE_DELIVERY) == 0 else {
                return false
            }
        }
        
        // We can show a notification
        return true
    }
    
    private func groupInfos(for pendingUserNotification: PendingUserNotification)
        -> (groupID: String, groupCreator: String)? {
        if let baseMessage = pendingUserNotification.baseMessage,
           let conversation = baseMessage.conversation,
           let group = entityManager.entityFetcher.groupEntity(for: conversation) {
            return (group.groupID.base64EncodedString(), group.groupCreator ?? MyIdentityStore.shared().identity)
        }
        else if let abstractMessage = pendingUserNotification.abstractMessage as? AbstractGroupMessage {
            return (abstractMessage.groupID.base64EncodedString(), abstractMessage.groupCreator)
        }
        return nil
    }
    
    private func fromName(for pendingUserNotification: PendingUserNotification) -> String {
        if let senderIdentity = pendingUserNotification.senderIdentity,
           let senderContact = entityManager.entityFetcher.contact(for: senderIdentity) {
            // We only show nickname for restrictive notifications, otherwise we always use the display name.
            switch settingsStore.notificationType {
            case .restrictive:
                return senderContact.publicNickname ?? senderIdentity
            case .balanced, .complete:
                return senderContact.displayName
            }
        }
        else {
            return nickname(for: pendingUserNotification)
        }
    }
    
    private func nickname(for pendingUserNotification: PendingUserNotification) -> String {
        if let baseMessage = pendingUserNotification.baseMessage,
           let conversation = baseMessage.conversation {
            if conversation.isGroup() {
                if let contact = entityManager.entityFetcher.contact(for: pendingUserNotification.senderIdentity),
                   let publicNickname = contact.publicNickname {
                    return publicNickname
                }
            }
            else {
                if let contact = conversation.contact,
                   let publicNickname = contact.publicNickname {
                    return publicNickname
                }
            }
        }
        return pendingUserNotification.senderIdentity ?? "unknown".localized
    }
    
    private func titleWithPreview(for pendingUserNotification: PendingUserNotification, fromName: String) -> String {
        if let baseMessage = pendingUserNotification.baseMessage,
           let isGroup = pendingUserNotification.isGroupMessage, isGroup {
            return baseMessage.conversation.groupName ?? fromName
        }
        else if pendingUserNotification.abstractMessage != nil {
            if let isGroup = pendingUserNotification.isGroupMessage, isGroup {
                if let groupCallStartMessage = pendingUserNotification.abstractMessage as? GroupCallStartMessage {
                    if let groupConversation = entityManager.entityFetcher.conversation(
                        for: groupCallStartMessage.groupID,
                        creator: groupCallStartMessage.groupCreator
                    ) {
                        return groupConversation.groupName ?? "new_message_unknown_group".localized
                    }
                    else {
                        return fromName
                    }
                }
                else {
                    return BundleUtil.localizedString(forKey: "new_group_message")
                }
            }
            else {
                return fromName
            }
        }
        return fromName
    }
    
    private func bodyWithPreview(for pendingUserNotification: PendingUserNotification, fromName: String) -> String {
        if let baseMessage = pendingUserNotification.baseMessage {
            if let isGroup = pendingUserNotification.isGroupMessage, isGroup {
                if settingsStore.notificationType == .complete {
                    return TextStyleUtils.makeMentionsString(forText: baseMessage.previewText())
                }
                else {
                    return TextStyleUtils.makeMentionsString(forText: "\(fromName): \(baseMessage.previewText())")
                }
            }
            else {
                return TextStyleUtils.makeMentionsString(forText: baseMessage.previewText())
            }
        }
        if let abstractMessage = pendingUserNotification.abstractMessage {
            if abstractMessage is AbstractGroupMessage {
                if abstractMessage is GroupCallStartMessage {
                    switch settingsStore.notificationType {
                    case .restrictive, .balanced:
                        return String.localizedStringWithFormat(
                            "group_call_notification_body_preview".localized,
                            fromName
                        )
                    case .complete:
                        return abstractMessage.pushNotificationBody()
                    }
                }
                else {
                    return "\(fromName): \(abstractMessage.pushNotificationBody()!)"
                }
            }
            else {
                return abstractMessage.pushNotificationBody()
            }
        }
        else {
            let key = pendingUserNotification.isGroupMessage ?? false ? "new_group_message" : "new_message"
            return key.localized
        }
    }
    
    private func bodyWithoutPreview(for pendingUserNotification: PendingUserNotification) -> String {
        if let abstractMessage = pendingUserNotification.abstractMessage, abstractMessage is GroupCallStartMessage {
            return abstractMessage.pushNotificationBody()
        }
        else {
            let key = pendingUserNotification.isGroupMessage ?? false ? "new_group_message" : "new_message"
            return key.localized
        }
    }
    
    private func isPrivate(content: UserNotificationContent) -> Bool {
        if let senderID = content.senderID,
           let conversation = entityManager.entityFetcher.conversation(forIdentity: senderID) {
            return conversation.conversationCategory == .private
        }
        return false
    }
    
    private func addAttachment(for pendingUserNotification: PendingUserNotification) -> (name: String?, url: URL?)? {
        guard let baseMessage = pendingUserNotification.baseMessage, pendingUserNotification.stage == .final else {
            return nil
        }
        var image: ImageData? = (baseMessage as? FileMessageEntity)?.thumbnail
        if image == nil {
            image = (baseMessage as? VideoMessageEntity)?.thumbnail
        }
        if image == nil {
            image = (baseMessage as? ImageMessageEntity)?.image
        }
        
        if let image,
           let attachment = saveAttachment(
               image,
               baseMessage.id.hexString,
               pendingUserNotification.stage
           ) {
            
            return (attachment.name, attachment.url)
        }
        
        return nil
    }
}
