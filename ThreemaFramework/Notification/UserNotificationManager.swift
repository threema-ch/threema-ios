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
    private let contactStore: ContactStoreProtocol
    private let groupManager: GroupManagerProtocol
    private let entityManager: EntityManager
    private let isWorkApp: Bool
    
    public init(
        _ settingsStore: SettingsStoreProtocol,
        _ userSettings: UserSettingsProtocol,
        _ contactStore: ContactStoreProtocol,
        _ groupManager: GroupManagerProtocol,
        _ entityManager: EntityManager,
        _ isWorkApp: Bool
    ) {
        self.settingsStore = settingsStore
        self.userSettings = userSettings
        self.contactStore = contactStore
        self.groupManager = groupManager
        self.entityManager = entityManager
        self.isWorkApp = isWorkApp
    }
    
    /// Get the best infos for user notification on the basis of the threema push, abstract or base (DB) message.
    ///
    /// - Parameter pendingUserNotification: Incoming processing message
    /// - Returns: User notification content or NULL if should no user notification should be shown or if the user
    ///            notification is handled otherwise
    public func userNotificationContent(_ pendingUserNotification: PendingUserNotification)
        -> UserNotificationContent? {
        
        guard let senderIdentity = pendingUserNotification.senderIdentity,
              !userSettings.blacklist.contains(senderIdentity) else {
            return nil
        }
        
        if let flagShouldPush = pendingUserNotification.abstractMessage?.flagShouldPush() {
            guard flagShouldPush else {
                return nil
            }
        }
        if let flagImmediateDeliveryRequired = pendingUserNotification.abstractMessage?
            .flagImmediateDeliveryRequired() {
            guard !flagImmediateDeliveryRequired else {
                return nil
            }
        }
        if let flagIsVoIP = pendingUserNotification.abstractMessage?.flagIsVoIP() {
            guard !flagIsVoIP else {
                return nil
            }
        }
        
        if let flags = pendingUserNotification.baseMessage?.flags {
            guard flags.intValue & Int(MESSAGE_FLAG_SEND_PUSH) != 0,
                  flags.intValue & Int(MESSAGE_FLAG_IMMEDIATE_DELIVERY) == 0 else {
                return nil
            }
        }
        
        let pushSettingManager = PushSettingManager(userSettings, isWorkApp)
        if !pushSettingManager.canMasterDndSendPush() {
            return nil
        }

        // If the notification is for a group, we check if it is for a group I did not leave. If so we don't show a
        // notification.
        if pendingUserNotification.isGroupMessage ?? false,
           let groupMessage = pendingUserNotification.abstractMessage as? AbstractGroupMessage {
            guard let group = groupManager.getGroup(groupMessage.groupID, creator: groupMessage.groupCreator),
                  !group.didLeave,
                  !group.didForcedLeave
            else {
                return nil
            }
        }

        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        // Set push setting
        if !userNotificationContent.isGroupMessage {
            userNotificationContent.pushSetting = pushSettingManager.find(forIdentity: userNotificationContent.senderID)
        }
        else if let baseMessage = pendingUserNotification.baseMessage {
            userNotificationContent.baseMessage = baseMessage
            userNotificationContent.groupID = entityManager.entityFetcher.groupEntity(for: baseMessage.conversation)?
                .groupID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            userNotificationContent.groupCreator = entityManager.entityFetcher
                .groupEntity(for: baseMessage.conversation)?.groupCreator ?? MyIdentityStore.shared().identity
            userNotificationContent.pushSetting = pushSettingManager.find(forConversation: baseMessage.conversation)
        }
            
        let notificationType = settingsStore.notificationType
        
        // Name
        // We only show nickname for restrictive notifications, otherwise we always use the display name.
        if let sender = entityManager.entityFetcher.contact(for: senderIdentity) {
            switch notificationType {
            case .restrictive:
                userNotificationContent.fromName = sender.publicNickname ?? senderIdentity
            case .balanced, .complete:
                userNotificationContent.fromName = sender.displayName
            }
        }
        else {
            guard !userSettings.blockUnknown else {
                return nil
            }
            
            userNotificationContent.fromName = nickname(for: pendingUserNotification)
        }
        
        // Body
        // We only hide the text if showPreview, is disabled
        if settingsStore.pushShowPreview {
            if let baseMessage = pendingUserNotification.baseMessage {
                // Apply content from base message
                if userNotificationContent.isGroupMessage {
                    userNotificationContent.title = baseMessage.conversation?.groupName ?? userNotificationContent
                        .fromName
                    // If we have create a communication notification, we don't add the name
                    if notificationType == .complete {
                        userNotificationContent.body = TextStyleUtils
                            .makeMentionsString(
                                forText: baseMessage.previewText()!
                            )
                    }
                    else {
                        userNotificationContent.body = TextStyleUtils
                            .makeMentionsString(
                                forText: "\(userNotificationContent.fromName!): \(baseMessage.previewText()!)"
                            )
                    }
                    
                    userNotificationContent.groupID = baseMessage.conversation.groupID!
                        .base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                }
                else {
                    userNotificationContent.title = userNotificationContent.fromName
                    userNotificationContent.body = TextStyleUtils
                        .makeMentionsString(forText: baseMessage.previewText())
                }
                    
                if pendingUserNotification.stage == .final {
                    // Add thumbnail attachment if file, image or video message
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
                            
                        userNotificationContent.attachmentName = attachment.name
                        userNotificationContent.attachmentURL = attachment.url
                    }
                }
            }
            else if let abstractMessage = pendingUserNotification.abstractMessage {
                // Apply content from abstract message
                if abstractMessage is AbstractGroupMessage {
                    userNotificationContent.title = BundleUtil.localizedString(forKey: "new_group_message")
                    userNotificationContent
                        .body = "\(userNotificationContent.fromName!): \(abstractMessage.pushNotificationBody()!)"
                }
                else {
                    userNotificationContent.title = userNotificationContent.fromName
                    userNotificationContent.body = abstractMessage.pushNotificationBody()
                }
            }
            
            else {
                let name = userNotificationContent.fromName ?? pendingUserNotification.senderIdentity ?? "unknown"
                userNotificationContent.title = name
                
                let key = pendingUserNotification.isGroupMessage ?? false ? "new_group_message" : "new_message"
                userNotificationContent.body = BundleUtil.localizedString(forKey: key)
            }
        }
        else {
            let name = userNotificationContent.fromName ?? pendingUserNotification.senderIdentity ?? "unknown"
            userNotificationContent.title = name
                
            let key = pendingUserNotification.isGroupMessage ?? false ? "new_group_message" : "new_message"
            userNotificationContent.body = BundleUtil.localizedString(forKey: key)
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
                DDLogError("Could not save attachement: \(error.localizedDescription)")
            }
        }
        else {
            DDLogError("Could not find cache directory.")
        }
        
        return nil
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
        
        let pushSound: String = from.categoryIdentifier.elementsEqual("GROUP") ? userSettings
            .pushGroupSound : userSettings.pushSound
        
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

        let unreadMessages = UnreadMessages(entityManager: entityManager)
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
            
            if let fromName = from.fromName {
                to.summaryArgument = fromName
            }
        }
    }
    
    private func isPrivate(content: UserNotificationContent) -> Bool {
        if let senderID = content.senderID,
           let conversation = entityManager.entityFetcher.conversation(forIdentity: senderID) {
            return conversation.conversationCategory == .private
        }
        return false
    }
}

// MARK: Private functions

extension UserNotificationManager {
    private func nickname(for pendingUserNotification: PendingUserNotification) -> String? {
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
        return pendingUserNotification.senderIdentity
    }
}
