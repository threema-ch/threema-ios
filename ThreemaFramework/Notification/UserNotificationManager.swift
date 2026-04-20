import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaEssentials
import ThreemaMacros

public protocol UserNotificationManagerProtocol {
    func userNotificationContent(_ pendingUserNotification: PendingUserNotification) -> UserNotificationContent?
    func testNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    func applyContent(
        from: UserNotificationContent,
        to: inout UNMutableNotificationContent,
        silent: Bool,
        baseMessage: BaseMessageEntity?
    )
}

public final class UserNotificationManager: UserNotificationManagerProtocol {
    private let settingsStore: SettingsStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private let contactStore: ContactStoreProtocol
    private let groupManager: GroupManagerProtocol
    private let entityManager: EntityManager
    private let isWorkApp: Bool
    private let fileUtility: FileUtilityProtocol
    
    public init(
        settingsStore: SettingsStoreProtocol,
        userSettings: UserSettingsProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        pushSettingManager: PushSettingManagerProtocol,
        contactStore: ContactStoreProtocol,
        groupManager: GroupManagerProtocol,
        entityManager: EntityManager,
        isWorkApp: Bool,
        fileUtility: FileUtilityProtocol = FileUtility.shared
    ) {
        self.settingsStore = settingsStore
        self.userSettings = userSettings
        self.myIdentityStore = myIdentityStore
        self.pushSettingManager = pushSettingManager
        self.contactStore = contactStore
        self.groupManager = groupManager
        self.entityManager = entityManager
        self.isWorkApp = isWorkApp
        self.fileUtility = fileUtility
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
        
        // Adds the thumbnail attachment if it is a file, image or video message. Note that we are only adding
        // attachment for the `final` stage.
        // This due to an error: If a notification with an attachment is removed for the `base` stage,
        // then the attachment for the `final` stage will not be displayed.
        if settingsStore.pushShowPreview,
           pendingUserNotification.stage == .final,
           let (name, url) = addAttachment(for: pendingUserNotification) {
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
        notificationContent.userInfo = payload

        return notificationContent
    }
    
    /// Get content for threema web notification.
    /// - Parameter payload: Information about threema web push
    /// - Returns: User notification for user notification center
    public func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = #localize("notification.threemaweb.connect.title")
        notificationContent.body = #localize("notification.threemaweb.connect.body")
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
        from: UserNotificationContent,
        to: inout UNMutableNotificationContent,
        silent: Bool,
        baseMessage: BaseMessageEntity?
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
            to.title = #localize("private_message_label")
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
        image: ImageDataEntity,
        id: String,
        stage: UserNotificationStage
    ) -> (name: String, url: URL)? {
        if let tmpDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last {
            let attachmentDirectory = "\(tmpDirectory)/PushImages"
            let attachmentDirectoryURL = URL(fileURLWithPath: attachmentDirectory)
            let attachmentName = "PushImage_\(id)_\(stage)"
            let attachmentURL = URL(fileURLWithPath: "\(attachmentDirectory)/\(attachmentName).jpg")
            
            do {
                if fileUtility.fileExists(at: attachmentDirectoryURL) == false {
                    try fileUtility.mkDir(
                        at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true),
                        withIntermediateDirectories: false,
                        attributes: nil
                    )
                }
                if fileUtility.fileExists(at: attachmentURL) {
                    try fileUtility.delete(at: attachmentURL)
                }
                
                /// This is the only exception to not using ``FileUtility`` to store something to disk.
                /// As we clean the push directory on each did become active, we're fine with this exception.
                try image.data.write(to: attachmentURL, options: .completeFileProtectionUntilFirstUserAuthentication)

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
        if entityManager.entityFetcher.contactEntity(for: senderIdentity) == nil,
           userSettings.blockUnknown,
           !PredefinedContacts(rawValue: senderIdentity).ignoreBlockUnknown {
            return false
        }
        
        // AbstractMessage checks
        if let abstractMessage = pendingUserNotification.abstractMessage {
            
            if abstractMessage is GroupCallStartMessage,
               !BusinessInjector().settingsStore.enableThreemaGroupCalls {
                return false
            }

            // Delete or edit message it self can't show notification, but can delete/edit existing notification
            if !(
                abstractMessage is DeleteMessage || abstractMessage is DeleteGroupMessage
                    || abstractMessage is EditMessage || abstractMessage is EditGroupMessage
            ) {
                guard abstractMessage.canShowUserNotification(), !abstractMessage.flagImmediateDeliveryRequired(),
                      !abstractMessage.flagIsVoIP() else {
                    return false
                }
            }
        }
        
        // Group checks
        if let groupMessage = pendingUserNotification.abstractMessage as? AbstractGroupMessage {
            guard let group = groupManager.getGroup(groupMessage.groupID, creator: groupMessage.groupCreator) else {
                return false
            }
            
            // Are we still member?
            guard !group.didLeave, !group.didForcedLeave else {
                return false
            }
            
            // Is sender still member?
            guard group.isMember(identity: groupMessage.fromIdentity) else {
                return false
            }
        }

        // TODO: (IOS-5090) Is this check necessary?
        // BaseMessageEntity checks
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
           let group = entityManager.entityFetcher.groupEntity(for: baseMessage.conversation) {
            return (group.groupID.base64EncodedString(), group.groupCreator ?? MyIdentityStore.shared().identity)
        }
        else if let abstractMessage = pendingUserNotification.abstractMessage as? AbstractGroupMessage {
            return (abstractMessage.groupID.base64EncodedString(), abstractMessage.groupCreator)
        }
        return nil
    }
    
    private func fromName(for pendingUserNotification: PendingUserNotification) -> String {
        if let senderIdentity = pendingUserNotification.senderIdentity,
           let senderContact = entityManager.entityFetcher.contactEntity(for: senderIdentity) {
            // We only show nickname for restrictive notifications, otherwise we always use the display name.
            switch settingsStore.notificationType {
            case .restrictive:
                senderContact.publicNickname ?? senderIdentity
            case .balanced, .complete:
                senderContact.displayName
            }
        }
        else {
            nickname(for: pendingUserNotification)
        }
    }
    
    private func nickname(for pendingUserNotification: PendingUserNotification) -> String {
        if let baseMessage = pendingUserNotification.baseMessage {
            if baseMessage.conversation.isGroup {
                if let senderIdentity = pendingUserNotification.senderIdentity,
                   let contact = entityManager.entityFetcher.contactEntity(for: senderIdentity),
                   let publicNickname = contact.publicNickname {
                    return publicNickname
                }
            }
            else {
                if let contact = baseMessage.conversation.contact,
                   let publicNickname = contact.publicNickname {
                    return publicNickname
                }
            }
        }
        return pendingUserNotification.senderIdentity ?? #localize("unknown")
    }
    
    private func titleWithPreview(for pendingUserNotification: PendingUserNotification, fromName: String) -> String {
        if let baseMessage = pendingUserNotification.baseMessage,
           let isGroup = pendingUserNotification.isGroupMessage, isGroup {
            return baseMessage.conversation.groupName ?? fromName
        }
        else if pendingUserNotification.abstractMessage != nil {
            if let isGroup = pendingUserNotification.isGroupMessage, isGroup {
                if let groupCallStartMessage = pendingUserNotification.abstractMessage as? GroupCallStartMessage {
                    
                    let groupIdentity = GroupIdentity(
                        id: groupCallStartMessage.groupID,
                        creator: ThreemaIdentity(groupCallStartMessage.groupCreator)
                    )
                    if let groupConversation = entityManager.entityFetcher.conversationEntity(
                        for: groupIdentity, myIdentity: MyIdentityStore.shared().identity
                    ) {
                        return groupConversation.groupName ?? #localize("new_message_unknown_group")
                    }
                    else {
                        return fromName
                    }
                }
                else {
                    return #localize("new_group_message")
                }
            }
            else {
                return fromName
            }
        }
        return fromName
    }
    
    private func bodyWithPreview(for pendingUserNotification: PendingUserNotification, fromName: String) -> String {
        if let baseMessage = pendingUserNotification.baseMessage as? PreviewableMessage {
            return baseMessage.previewAttributedText(for: .pushNotification, settingsStore: settingsStore).string
        }
        if let abstractMessage = pendingUserNotification.abstractMessage {
            if abstractMessage is AbstractGroupMessage {
                if abstractMessage is GroupCallStartMessage {
                    switch settingsStore.notificationType {
                    case .restrictive, .balanced:
                        return String.localizedStringWithFormat(
                            #localize("group_call_notification_body_preview"),
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
            return pendingUserNotification
                .isGroupMessage ?? false ? #localize("new_group_message") : #localize("new_message")
        }
    }
    
    private func bodyWithoutPreview(for pendingUserNotification: PendingUserNotification) -> String {
        if let abstractMessage = pendingUserNotification.abstractMessage, abstractMessage is GroupCallStartMessage {
            abstractMessage.pushNotificationBody()
        }
        else {
            pendingUserNotification.isGroupMessage ?? false ? #localize("new_group_message") : #localize("new_message")
        }
    }
    
    private func isPrivate(content: UserNotificationContent) -> Bool {
        if content.isGroupMessage {
            if let groupIDString = content.groupID,
               let groupID = Data(base64Encoded: groupIDString),
               let groupCreator = content.groupCreator,
               let conversation = entityManager.entityFetcher.conversationEntity(
                   for: GroupIdentity(id: groupID, creatorID: groupCreator),
                   myIdentity: myIdentityStore.identity
               ) {
                conversation.conversationCategory == .private
            }
            else {
                false
            }
        }
        else if let senderID = content.senderID,
                let conversation = entityManager.entityFetcher.conversationEntity(for: senderID) {
            conversation.conversationCategory == .private
        }
        else {
            false
        }
    }
    
    private func addAttachment(for pendingUserNotification: PendingUserNotification) -> (name: String?, url: URL?)? {
        guard let baseMessage = pendingUserNotification.baseMessage else {
            return nil
        }
        var image: ImageDataEntity? = (baseMessage as? FileMessageEntity)?.thumbnail
        if image == nil {
            image = (baseMessage as? VideoMessageEntity)?.thumbnail
        }
        if image == nil {
            image = (baseMessage as? ImageMessageEntity)?.image
        }
        
        if let image,
           let attachment = saveAttachment(
               image: image,
               id: baseMessage.id.hexString,
               stage: pendingUserNotification.stage
           ) {
            
            return (attachment.name, attachment.url)
        }
        
        return nil
    }
}
