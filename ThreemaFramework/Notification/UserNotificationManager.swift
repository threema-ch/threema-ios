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
        silent: Bool
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
    private let isReactionNotificationsEnabled: Bool

    public init(
        settingsStore: SettingsStoreProtocol,
        userSettings: UserSettingsProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        pushSettingManager: PushSettingManagerProtocol,
        contactStore: ContactStoreProtocol,
        groupManager: GroupManagerProtocol,
        entityManager: EntityManager,
        isWorkApp: Bool,
        fileUtility: FileUtilityProtocol = FileUtility.shared,
        isReactionNotificationsEnabled: Bool = ThreemaEnvironment.enableReactionNotifications
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
        self.isReactionNotificationsEnabled = isReactionNotificationsEnabled
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
            userNotificationContent.body = bodyWithPreview(for: pendingUserNotification)
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
        silent: Bool
    ) {
        
        var pushSound: String = from.categoryIdentifier.elementsEqual("GROUP") ? userSettings
            .pushGroupSound : userSettings.pushSound
        
        if from.isGroupCallStartMessage() {
            pushSound = "threema_gc"
        }
        
        to.title = from.title ?? ""
        to.body = from.body ?? ""
        
        let isPrivate = isPrivate(content: from)
        
        if isPrivate {
            to.title = from.isReactionMessage() ? #localize("private_reaction_label") : #localize(
                "private_message_label"
            )
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
            // Reactions get no actions: replying and reacting would both act on our own message
            to.categoryIdentifier = userSettings.pushDecrypt && !from.isReactionMessage() ? from
                .categoryIdentifier : ""
        }
        else {
            to.categoryIdentifier = from.categoryIdentifier
            to.categoryIdentifier = from.categoryIdentifier
        }
        
        // Group notifications
        if from.categoryIdentifier.elementsEqual("SINGLE") {
            // TODO: Remove this force unwrap, it is on the path of every 1:1 notification, reactions included
            to.threadIdentifier = "SINGLE-\(from.senderID!)"
        }
        else if from.categoryIdentifier.elementsEqual("GROUP"),
                let groupID = from.groupID, let groupCreator = from.groupCreator {
            
            to.threadIdentifier = "GROUP-\(groupID)-\(groupCreator)"
        }
    }
    
    /// Body of an in-app banner about the reactions to a message of ours
    ///
    /// Follows the same rules as a notification, e.g. the reaction settings or blocked contacts. Unlike a rich
    /// notification it always names who reacted, because nothing is shown next to the title of an in-app banner.
    /// - Parameter pendingUserNotification: Pending notification about a reaction
    /// - Returns: Body of the banner, `nil` if none may be shown
    public func inAppReactionBannerBody(for pendingUserNotification: PendingUserNotification) -> String? {
        // Only reactions to our own messages are announced, the same as for the notification. Taking a reaction back
        // is nothing to announce either, the notification is only updated or removed for it.
        guard pendingUserNotification.baseMessage?.isOwnMessage == true,
              !pendingUserNotification.isReactionWithdrawal,
              shouldShowPush(for: pendingUserNotification) else {
            return nil
        }

        if pendingUserNotification.abstractMessage is ReactionMessage {
            return reactionBodyForOneToOne(pendingUserNotification: pendingUserNotification)
        }
        else if pendingUserNotification.abstractMessage is GroupReactionMessage {
            return reactionBodyForGroup(pendingUserNotification: pendingUserNotification, showsLastReactorName: false)
        }

        return nil
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
           !PredefinedContacts(rawValue: senderIdentity).isSpecialContact {
            return false
        }
        
        // AbstractMessage checks
        if let abstractMessage = pendingUserNotification.abstractMessage {
            
            if let groupCallStartMessage = abstractMessage as? GroupCallStartMessage {
                guard BusinessInjector().settingsStore.enableThreemaGroupCalls else {
                    return false
                }

                // The call might have ended before we were able to process its start message, e.g. because we were
                // offline for a while. Processing peeks the SFU, so by now we know if it did.
                guard !groupCallStartMessage.callEnded else {
                    DDLogNotice("[Push] Do not show a notification for a group call that is no longer running")
                    return false
                }
            }

            // Delete or edit message it self can't show notification, but can delete/edit existing notification. Also
            // reactions get special treatment.
            if !(
                abstractMessage is DeleteMessage ||
                    abstractMessage is DeleteGroupMessage ||
                    abstractMessage is EditMessage ||
                    abstractMessage is EditGroupMessage ||
                    abstractMessage is ReactionMessage ||
                    abstractMessage is GroupReactionMessage
            ) {
                guard abstractMessage.canShowUserNotification(), !abstractMessage.flagImmediateDeliveryRequired(),
                      !abstractMessage.flagIsVoIP() else {
                    return false
                }
            }
            
            if abstractMessage is ReactionMessage || abstractMessage is GroupReactionMessage {
                guard isReactionNotificationsEnabled else {
                    return false
                }

                if abstractMessage is ReactionMessage, !userSettings.reactionNotificationsOneToOneEnabled {
                    return false
                }

                if abstractMessage is GroupReactionMessage, !userSettings.reactionNotificationsGroupEnabled {
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
            name(for: senderContact, identity: senderIdentity)
        }
        else {
            nickname(for: pendingUserNotification)
        }
    }

    /// Name of a contact as it may be shown in a notification
    /// - Parameters:
    ///   - contact: Contact to get the name of
    ///   - identity: Identity of the contact, shown if there is no name to show
    /// - Returns: Name for the notification
    private func name(for contact: ContactEntity, identity: String) -> String {
        // We only show nickname for restrictive notifications, otherwise we always use the display name.
        switch settingsStore.notificationType {
        case .restrictive:
            contact.publicNickname ?? identity
        case .balanced, .complete:
            contact.displayName
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
    
    private func bodyWithPreview(for pendingUserNotification: PendingUserNotification) -> String {
        // We have a previewable base message
        if let previewableMessage = pendingUserNotification.baseMessage as? PreviewableMessage {
            bodyWithPreview(for: previewableMessage, of: pendingUserNotification)
        }
        // We only have an abstract message
        else if let abstractMessage = pendingUserNotification.abstractMessage {
            bodyWithPreview(for: abstractMessage, of: pendingUserNotification)
        }
        // No info available, we fallback to defaults
        else {
            if let isGroupMessage = pendingUserNotification.isGroupMessage, isGroupMessage {
                #localize("new_group_message")
            }
            else {
                #localize("new_message")
            }
        }
    }
    
    private func bodyWithPreview(
        for previewableMessage: PreviewableMessage,
        of pendingUserNotification: PendingUserNotification
    ) -> String {
        // If we have a base message, and the abstract message is a reaction message, we handle it specially
        if pendingUserNotification.abstractMessage is ReactionMessage {
            return reactionBodyForOneToOne(pendingUserNotification: pendingUserNotification)
        }
        else if pendingUserNotification.abstractMessage is GroupReactionMessage {
            // A rich notification shows the name of the person that reacted last next to the group name
            return reactionBodyForGroup(
                pendingUserNotification: pendingUserNotification,
                showsLastReactorName: settingsStore.notificationType == .complete
            )
        }
        
        // A normal push for a base message
        return previewableMessage.previewAttributedText(for: .pushNotification, settingsStore: settingsStore).string
    }
    
    private func bodyWithPreview(
        for abstractMessage: AbstractMessage,
        of pendingUserNotification: PendingUserNotification
    ) -> String {
        // Non group messages are straight forward
        if !(abstractMessage is AbstractGroupMessage) {
            return abstractMessage.pushNotificationBody()
        }
    
        let fromName = fromName(for: pendingUserNotification)
        
        // Non group call messages
        if !(abstractMessage is GroupCallStartMessage) {
            return "\(fromName): \(abstractMessage.pushNotificationBody(), default: #localize("new_group_message"))"
        }
        
        // Group call messages need special attention
        switch settingsStore.notificationType {
        case .restrictive, .balanced:
            let date = DateFormatter.shortStyleTimeNoDate(abstractMessage.date)
            return String.localizedStringWithFormat(
                #localize("group_call_notification_body_preview"),
                fromName,
                date
            )
            
        case .complete:
            return abstractMessage.pushNotificationBody()
        }
    }
    
    // MARK: - Emoji reaction body
    
    // MARK: 1-to-1
    
    private func reactionBodyForOneToOne(pendingUserNotification: PendingUserNotification) -> String {
        guard let reactionMessage = pendingUserNotification.abstractMessage as? ReactionMessage,
              let messageID = reactionMessage.decoded?.messageID.littleEndianData else {
            return #localize("new_reaction")
        }
        
        // Everything read from the message and its reactions must happen on the queue of their context
        return entityManager.performAndWait {
            guard let messageInfo = self.messageInfoForReactionContent(
                pendingUserNotification: pendingUserNotification,
                reactionMessage: reactionMessage,
                messageID: messageID
            ) else {
                return #localize("new_reaction")
            }
            let (message, messageReactions) = messageInfo

            guard let emojis = self.compactedEmojiString(for: messageReactions),
                  let preview = message.quotedPreviewText(for: .pushNotification) else {
                return #localize("new_reaction")
            }

            let localizedReaction = String.localizedStringWithFormat(
                #localize("new_message_reacted_with_one_to_one"),
                emojis
            )

            return "\(localizedReaction) \(preview)"
        }
    }
    
    // MARK: Group
    
    /// - Parameters:
    ///   - pendingUserNotification: Pending notification about a reaction
    ///   - showsLastReactorName: Pass `true` if the name of the person that reacted last is already shown elsewhere,
    /// thus must not be repeated in the body
    private func reactionBodyForGroup(
        pendingUserNotification: PendingUserNotification,
        showsLastReactorName: Bool
    ) -> String {
        guard let reactionMessage = pendingUserNotification.abstractMessage as? GroupReactionMessage,
              let messageID = reactionMessage.decoded?.messageID.littleEndianData else {
            return #localize("new_reaction")
        }
        
        // Everything read from the message and its reactions must happen on the queue of their context
        return entityManager.performAndWait {
            guard let messageInfo = self.messageInfoForReactionContent(
                pendingUserNotification: pendingUserNotification,
                reactionMessage: reactionMessage,
                messageID: messageID
            ) else {
                return #localize("new_reaction")
            }
            let (message, messageReactions) = messageInfo

            // Each reactor once, the one that reacted last comes first. Own reactions (creator is `nil`) are always
            // read and thus never part of this.
            var reactorIdentities = [String]()
            for reaction in messageReactions.sorted(using: KeyPathComparator(\.date, order: .reverse)) {
                guard let identity = reaction.creator?.identity, !reactorIdentities.contains(identity) else {
                    continue
                }
                reactorIdentities.append(identity)
            }

            let senderString: String
            switch reactorIdentities.count {
            case 1:
                guard let emojis = self.compactedEmojiString(for: messageReactions) else {
                    return #localize("new_reaction")
                }

                senderString =
                    if showsLastReactorName {
                        String.localizedStringWithFormat(#localize("new_message_reacted_with_one_to_one"), emojis)
                    }
                    else {
                        String.localizedStringWithFormat(
                            #localize("new_message_reacted_one_member"),
                            self.senderName(for: reactorIdentities[0]),
                            emojis
                        )
                    }

            case 2:
                senderString =
                    if showsLastReactorName {
                        String.localizedStringWithFormat(
                            #localize("new_message_reacted_and_one_member"),
                            self.senderName(for: reactorIdentities[1])
                        )
                    }
                    else {
                        String.localizedStringWithFormat(
                            #localize("new_message_reacted_two_members"),
                            self.senderName(for: reactorIdentities[0]),
                            self.senderName(for: reactorIdentities[1])
                        )
                    }

            case 3...:
                // The last reactor is named, all others are counted
                senderString =
                    if showsLastReactorName {
                        String.localizedStringWithFormat(
                            #localize("new_message_reacted_and_n_members"),
                            reactorIdentities.count - 1
                        )
                    }
                    else {
                        String.localizedStringWithFormat(
                            #localize("new_message_reacted_n_members"),
                            self.senderName(for: reactorIdentities[0]),
                            reactorIdentities.count - 1
                        )
                    }

            default:
                // There is nobody we could attribute the reactions to
                return #localize("new_reaction")
            }

            guard let preview = message.quotedPreviewText(for: .pushNotification) else {
                return #localize("new_reaction")
            }

            return "\(senderString) \(preview)"
        }
    }
    
    // MARK: General emoji body helpers

    /// Number of emojis shown in a notification before the rest is truncated away
    static let maxShownEmojis = 3

    /// Emojis of the given reactions, newest first. Everything beyond `maxShownEmojis` is replaced by the number of
    /// remaining emojis.
    /// - Parameter reactions: Reactions to show the emojis of
    /// - Returns: Emojis for the notification body or `nil` if there is no emoji to show
    func compactedEmojiString(for reactions: [MessageReactionEntity]) -> String? {
        let emojis = reactions
            .sorted(using: KeyPathComparator(\.date, order: .reverse))
            .compactMap { $0.emoji?.rawValue }

        guard !emojis.isEmpty else {
            return nil
        }

        guard emojis.count > Self.maxShownEmojis else {
            return emojis.joined()
        }

        return String.localizedStringWithFormat(
            #localize("new_message_reacted_emojis_truncated"),
            emojis.prefix(Self.maxShownEmojis).joined(),
            emojis.count - Self.maxShownEmojis
        )
    }

    /// Name of the person that reacted, shown the same way as the name of somebody sending a message
    /// - Parameter identity: Identity of the person that reacted
    /// - Returns: Name for the notification, the identity if we don't know the person
    func senderName(for identity: String) -> String {
        entityManager.performAndWait {
            guard let contact = self.entityManager.entityFetcher.contactEntity(for: identity) else {
                return identity
            }

            return self.name(for: contact, identity: identity)
        }
    }
    
    /// Message a reaction is about and its unread reactions
    ///
    /// Must be called on the queue of the context of `entityManager`, and the result must only be used there.
    /// - Parameters:
    ///   - pendingUserNotification: Pending notification about the reaction
    ///   - reactionMessage: Reaction that came in
    ///   - messageID: ID of the message that was reacted to
    /// - Returns: Message and its unread reactions, `nil` if the message can't be found or can't be previewed
    private func messageInfoForReactionContent(
        pendingUserNotification: PendingUserNotification,
        reactionMessage: AbstractMessage,
        messageID: Data
    ) -> (PreviewableMessage, [MessageReactionEntity])? {
        let message: BaseMessageEntity? =
            if let baseMessageObjectID = pendingUserNotification.baseMessage?.objectID {
                // The message the notification is about already, loaded again because it may belong to another context
                entityManager.entityFetcher.existingObject(with: baseMessageObjectID) as? BaseMessageEntity
            }
            else if let conversation = entityManager.existingConversationSenderReceiver(
                for: reactionMessage,
                myIdentity: myIdentityStore.identity
            ).conversation {
                entityManager.entityFetcher.message(with: messageID, in: conversation)
            }
            else {
                nil
            }

        guard let message,
              let previewableMessage = message as? PreviewableMessage,
              let reactions = entityManager.entityFetcher.unreadMessageReactionEntities(for: message) else {
            return nil
        }

        return (previewableMessage, reactions)
    }

    private func bodyWithoutPreview(for pendingUserNotification: PendingUserNotification) -> String {
        if let abstractMessage = pendingUserNotification.abstractMessage, abstractMessage is GroupCallStartMessage {
            abstractMessage.pushNotificationBody()
        }
        else {
            if pendingUserNotification.abstractMessage is ReactionMessage || pendingUserNotification.abstractMessage is GroupReactionMessage {
                #localize("new_reaction")
            }
            else {
                pendingUserNotification.isGroupMessage ?? false ? #localize("new_group_message") : #localize(
                    "new_message"
                )
            }
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
