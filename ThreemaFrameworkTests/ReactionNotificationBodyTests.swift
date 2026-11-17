import FileUtility
import FileUtilityTestHelper
import Foundation
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
import ThreemaProtocols

@testable import ThreemaFramework

// The tests operate directly on a `mainQueueConcurrencyType` Core Data context (see `DatabaseContextMock`), so the
// whole suite must run on the main thread. See `PersistenceMigrationTests` for the full reasoning.
@MainActor
@Suite("Reaction notification body tests")
struct ReactionNotificationBodyTests {

    private let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
    private let groupCreator = "CREATOR1"
    private let reactedText = "Probably a long msg"
    private let emoji = "❤️"

    init() {
        AppGroup.setGroupID("group.ch.threema")

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(RemoteSecretManagerMock())
    }

    // MARK: - Tests

    @Test("One person reacting is named in the body, unless the rich notification shows the name already")
    func oneReactor() throws {
        let balanced = try notificationBody(reactorCount: 1, notificationType: .balanced)
        let complete = try notificationBody(reactorCount: 1, notificationType: .complete)

        // e.g. `John reacted ❤️ to: "Probably a long msg"`
        #expect(balanced == "new_message_reacted_one_member \"\(reactedText)\"")

        // e.g. `Reacted ❤️ to: "Probably a long msg"`, the name is shown by the system
        #expect(complete == "new_message_reacted_with_one_to_one \"\(reactedText)\"")
    }

    @Test("Two people reacting are both named, the last one only if the rich notification does not show it")
    func twoReactors() throws {
        let balanced = try notificationBody(reactorCount: 2, notificationType: .balanced)
        let complete = try notificationBody(reactorCount: 2, notificationType: .complete)

        // e.g. `Emily and John reacted to: "Probably a long msg"`
        #expect(balanced == "new_message_reacted_two_members \"\(reactedText)\"")

        // e.g. `And John reacted to: "Probably a long msg"`, Emily is shown by the system
        #expect(complete == "new_message_reacted_and_one_member \"\(reactedText)\"")
    }

    @Test("Three people reacting are counted, the last one is named only outside of rich notifications")
    func threeReactors() throws {
        let balanced = try notificationBody(reactorCount: 3, notificationType: .balanced)
        let complete = try notificationBody(reactorCount: 3, notificationType: .complete)

        // e.g. `Peter and 2 others reacted to: "Probably a long msg"`
        #expect(balanced == "new_message_reacted_n_members \"\(reactedText)\"")

        // e.g. `And 2 others reacted to: "Probably a long msg"`, Peter is shown by the system
        #expect(complete == "new_message_reacted_and_n_members \"\(reactedText)\"")
    }

    @Test("A reaction in a private chat says that a reaction came in, but not who reacted or to what")
    func privateChat() throws {
        let (privateManager, privateContent, _) = try notification(
            reactorCount: 2,
            notificationType: .balanced,
            isPrivateChat: true
        )
        // Each manager has its own database, where the group is private or not
        let (manager, content, _) = try notification(reactorCount: 2, notificationType: .balanced)

        var privateNotification = UNMutableNotificationContent()
        privateManager.applyContent(from: privateContent, to: &privateNotification, silent: true)

        #expect(privateNotification.title == "private_reaction_label")
        #expect(privateNotification.body.isEmpty)

        // Everywhere else the reactions are shown as usual
        var regularNotification = UNMutableNotificationContent()
        manager.applyContent(from: content, to: &regularNotification, silent: true)

        #expect(regularNotification.title != "private_reaction_label")
        #expect(regularNotification.body == "new_message_reacted_two_members \"\(reactedText)\"")
    }

    @Test("A reaction in a single chat names nobody in the body, the title already does", arguments: [
        NotificationType.balanced,
        .complete,
    ])
    func singleChat(notificationType: NotificationType) throws {
        let body = try #require(
            notification(reactorCount: 1, notificationType: notificationType, isGroupChat: false).content.body
        )

        // e.g. `Reacted ❤️ to: "Probably a long msg"`
        #expect(body == "new_message_reacted_with_one_to_one \"\(reactedText)\"")
    }

    @Test("Reactions in groups and single chats each follow their own setting")
    func settings() throws {
        let groupWithGroupSettingOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupSettingEnabled: false
        )
        let groupWithSingleSettingOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isOneToOneSettingEnabled: false
        )
        let singleWithSingleSettingOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupChat: false,
            isOneToOneSettingEnabled: false
        )
        let singleWithGroupSettingOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupChat: false,
            isGroupSettingEnabled: false
        )

        #expect(groupWithGroupSettingOff.content == nil)
        #expect(groupWithSingleSettingOff.content != nil)
        #expect(singleWithSingleSettingOff.content == nil)
        #expect(singleWithGroupSettingOff.content != nil)
    }

    @Test("A reactor is named like the sender of a message, honoring the restrictive notification type")
    func reactorName() throws {
        let restrictive = try notification(reactorCount: 1, notificationType: .restrictive).manager
        let balanced = try notification(reactorCount: 1, notificationType: .balanced).manager

        // Restrictive notifications only ever show the nickname
        #expect(restrictive.senderName(for: "REACTOR0") == "nick0")

        // Otherwise the name from the contact is shown
        let balancedName = balanced.senderName(for: "REACTOR0")
        #expect(balancedName != "nick0")
        #expect(balancedName != "REACTOR0")

        // Somebody we don't know is shown by their identity, never as an empty name
        #expect(balanced.senderName(for: "UNKNOWN1") == "UNKNOWN1")
        #expect(restrictive.senderName(for: "UNKNOWN1") == "UNKNOWN1")
    }

    @Test("The newest emojis come first, and too many are truncated")
    func emojis() throws {
        let manager = try notification(reactorCount: 1, notificationType: .balanced).manager

        let dbPreparer = TestDatabase().preparer
        let reactions = dbPreparer.save {
            let message = dbPreparer.createTextMessage(
                conversation: dbPreparer.createConversation(),
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )

            // Oldest first, so the emojis are expected in reversed order
            return ["👍", "❤️", "😂", "😮", "😢"].enumerated().map { index, emoji in
                dbPreparer.createMessageReactionEntity(
                    message: message,
                    reaction: emoji,
                    date: Date(timeIntervalSinceNow: TimeInterval(index))
                )
            }
        }

        #expect(manager.compactedEmojiString(for: []) == nil)
        #expect(manager.compactedEmojiString(for: Array(reactions.prefix(1))) == "👍")

        // Exactly as many as can be shown are not truncated, newest first
        let maxShown = Array(reactions.prefix(UserNotificationManager.maxShownEmojis))
        #expect(manager.compactedEmojiString(for: maxShown) == "😂❤️👍")

        // One more is truncated. The count itself can't be asserted here, because localized format strings don't
        // resolve in this target and drop their arguments.
        let oneTooMany = Array(reactions.prefix(UserNotificationManager.maxShownEmojis + 1))
        #expect(manager.compactedEmojiString(for: oneTooMany) == "new_message_reacted_emojis_truncated")
    }

    @Test("A reaction notification has no actions, but is grouped with the chat", arguments: [true, false])
    func noActions(isGroupChat: Bool) throws {
        let (manager, content, _) = try notification(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupChat: isGroupChat
        )

        var notification = UNMutableNotificationContent()
        manager.applyContent(from: content, to: &notification, silent: true)

        // Replying or reacting from here would act on our own message
        #expect(notification.categoryIdentifier.isEmpty)
        #expect(notification.threadIdentifier.hasPrefix(isGroupChat ? "GROUP-" : "SINGLE-"))
    }

    @Test("An in-app banner always names who reacted, even where the rich notification leaves it to the system")
    func inAppBanner() throws {
        let group = try notification(reactorCount: 2, notificationType: .complete)
        let single = try notification(reactorCount: 1, notificationType: .complete, isGroupChat: false)

        // The rich notification body would be `new_message_reacted_and_one_member`, a banner has no sender next to it
        #expect(
            group.manager.inAppReactionBannerBody(for: group.pendingUserNotification)
                == "new_message_reacted_two_members \"\(reactedText)\""
        )

        // In a single chat the chat name is the title of the banner already
        #expect(
            single.manager.inAppReactionBannerBody(for: single.pendingUserNotification)
                == "new_message_reacted_with_one_to_one \"\(reactedText)\""
        )
    }

    @Test("An in-app banner follows the same rules as the notification")
    func inAppBannerRules() throws {
        let settingOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupSettingEnabled: false
        )
        let featureOff = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isReactionNotificationsEnabled: false
        )

        #expect(settingOff.manager.inAppReactionBannerBody(for: settingOff.pendingUserNotification) == nil)
        #expect(featureOff.manager.inAppReactionBannerBody(for: featureOff.pendingUserNotification) == nil)
    }

    @Test("A reaction to somebody else's message shows no in-app banner", arguments: [true, false])
    func inAppBannerNotForOthersMessage(isGroupChat: Bool) throws {
        let othersMessage = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupChat: isGroupChat,
            isReactedMessageOwn: false
        )

        #expect(othersMessage.manager.inAppReactionBannerBody(for: othersMessage.pendingUserNotification) == nil)
    }

    @Test("Taking a reaction back shows no in-app banner, even if other reactions remain")
    func inAppBannerNotForWithdrawal() throws {
        // Two reactions are still there, the one coming in takes another one back
        let withdrawal = try notificationContent(reactorCount: 2, notificationType: .balanced, isWithdrawal: true)

        #expect(withdrawal.manager.inAppReactionBannerBody(for: withdrawal.pendingUserNotification) == nil)
    }

    @Test("A reaction notification carries the reacted message, so tapping it opens the chat there", arguments: [
        true,
        false,
    ])
    func reactedMessageID(isGroupChat: Bool) throws {
        let (_, content, pendingUserNotification) = try notification(
            reactorCount: 1,
            notificationType: .balanced,
            isGroupChat: isGroupChat
        )
        let reactedMessage = try #require(pendingUserNotification.baseMessage)

        #expect(
            content.userInfo["threema"]?[UserNotificationContent.reactedMessageIDKey] == reactedMessage.id.hexString
        )

        // A notification about the message itself opens the chat as usual
        let textMessage = BoxTextMessage()
        textMessage.fromIdentity = "REACTOR0"
        textMessage.messageID = reactedMessage.id
        let messageNotification = PendingUserNotification(key: "REACTOR0\(reactedMessage.id.hexString)")
        messageNotification.abstractMessage = textMessage
        messageNotification.baseMessage = reactedMessage

        #expect(
            UserNotificationContent(messageNotification)
                .userInfo["threema"]?[UserNotificationContent.reactedMessageIDKey] == nil
        )
    }

    @Test("Nothing is shown in builds where reaction notifications are not enabled")
    func featureNotEnabled() throws {
        let (_, content, _) = try notificationContent(
            reactorCount: 1,
            notificationType: .balanced,
            isReactionNotificationsEnabled: false
        )

        #expect(content == nil)
    }

    // MARK: - Helpers

    /// Body of the notification about a group message of ours that `reactorCount` people reacted to
    private func notificationBody(
        reactorCount: Int,
        notificationType: NotificationType
    ) throws -> String {
        try #require(notification(reactorCount: reactorCount, notificationType: notificationType).content.body)
    }

    /// Notification about a message of ours that `reactorCount` people reacted to, which must be shown
    private func notification(
        reactorCount: Int,
        notificationType: NotificationType,
        isPrivateChat: Bool = false,
        isGroupChat: Bool = true
    ) throws -> (
        manager: UserNotificationManager,
        content: UserNotificationContent,
        pendingUserNotification: PendingUserNotification
    ) {
        let (manager, content, pendingUserNotification) = try notificationContent(
            reactorCount: reactorCount,
            notificationType: notificationType,
            isPrivateChat: isPrivateChat,
            isGroupChat: isGroupChat
        )
        return try (manager, #require(content), pendingUserNotification)
    }

    /// Notification about a group message of ours that `reactorCount` people reacted to
    /// - Parameters:
    ///   - reactorCount: Number of people that reacted to our message
    ///   - notificationType: Notification type set by the user
    ///   - isPrivateChat: Pass `true` to mark the chat the message is in as private
    ///   - isGroupChat: Pass `false` for a single chat, which only allows one person reacting
    ///   - isReactionNotificationsEnabled: Whether the feature is enabled for the build. Always set here, so the tests
    /// don't depend on the flavor they run in.
    ///   - isOneToOneSettingEnabled: User setting for reactions in single chats
    ///   - isGroupSettingEnabled: User setting for reactions in group chats
    ///   - isWithdrawal: Pass `true` if the reaction that comes in takes a reaction back
    ///   - isReactedMessageOwn: Pass `false` if the message was written by the first person reacting instead of us
    /// - Returns: The manager, the content (`nil` if no notification is shown) and the pending notification
    private func notificationContent(
        reactorCount: Int,
        notificationType: NotificationType,
        isPrivateChat: Bool = false,
        isGroupChat: Bool = true,
        isReactionNotificationsEnabled: Bool = true,
        isOneToOneSettingEnabled: Bool = true,
        isGroupSettingEnabled: Bool = true,
        isWithdrawal: Bool = false,
        isReactedMessageOwn: Bool = true
    ) throws -> (
        manager: UserNotificationManager,
        content: UserNotificationContent?,
        pendingUserNotification: PendingUserNotification
    ) {
        precondition(isGroupChat || reactorCount == 1, "Only one other person can react in a single chat")

        let testDatabase = TestDatabase()
        let dbPreparer = testDatabase.preparer

        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.reactionNotificationsOneToOneEnabled = isOneToOneSettingEnabled
        userSettingsMock.reactionNotificationsGroupEnabled = isGroupSettingEnabled
        // Previews on, which is also what enables the notification actions
        userSettingsMock.pushDecrypt = true
        // Never `nil` in the app, `applyContent` unwraps them
        userSettingsMock.pushSound = "default"
        userSettingsMock.pushGroupSound = "default"

        var reactorContacts = [ContactEntity]()
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        var reactedMessage: BaseMessageEntity!

        dbPreparer.save {
            for index in 0..<reactorCount {
                let contact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: "REACTOR\(index)"
                )
                contact.setFirstName(to: "Reactor", sortOrderFirstName: true)
                contact.setLastName(to: "Number \(index)", sortOrderFirstName: true)
                contact.publicNickname = "nick\(index)"
                reactorContacts.append(contact)
            }

            if isGroupChat {
                let creatorContact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: groupCreator
                )

                groupEntity = dbPreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreator)
                conversation = dbPreparer.createConversation { conversation in
                    conversation.groupID = groupID
                    conversation.contact = creatorContact
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
            }
            else {
                conversation = dbPreparer.createConversation(contactEntity: reactorContacts[0])
            }

            if isPrivateChat {
                conversation.changeCategory(to: .private)
            }

            // The message that was reacted to is one of ours, unless asked otherwise
            reactedMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                text: reactedText,
                isOwn: isReactedMessageOwn,
                sender: isReactedMessageOwn ? nil : reactorContacts[0],
                remoteSentDate: isReactedMessageOwn ? nil : .now
            )

            // The person reacting last reacts last, so it gets the newest date
            for (index, contact) in reactorContacts.enumerated() {
                dbPreparer.createMessageReactionEntity(
                    message: reactedMessage,
                    reaction: emoji,
                    date: Date(timeIntervalSinceNow: TimeInterval(index)),
                    contact: contact
                )
            }
        }

        let groupManagerMock = GroupManagerMock()
        if isGroupChat {
            conversation.members = Set(reactorContacts)
            groupManagerMock.getGroupReturns.append(Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            ))
        }

        // The reaction of the person that reacted last is the one triggering the notification
        let lastReactor = try #require(reactorContacts.last)

        var cspReaction = CspE2e_Reaction()
        let emojiData = try #require(emoji.data(using: .utf8))
        cspReaction.action = isWithdrawal ? .withdraw(emojiData) : .apply(emojiData)
        cspReaction.messageID = try reactedMessage.id.littleEndian()

        let reactionMessage: AbstractMessage
        if isGroupChat {
            let groupReactionMessage = GroupReactionMessage()
            groupReactionMessage.groupID = groupID
            groupReactionMessage.groupCreator = groupCreator
            groupReactionMessage.decoded = cspReaction
            reactionMessage = groupReactionMessage
        }
        else {
            let singleReactionMessage = ReactionMessage()
            singleReactionMessage.decoded = cspReaction
            // Incoming. Only needed if there is no base message, then the chat is looked up through the sender.
            singleReactionMessage.toIdentity = myIdentityStoreMock.identity
            reactionMessage = singleReactionMessage
        }
        reactionMessage.fromIdentity = lastReactor.identity
        reactionMessage.messageID = BytesUtility.generateMessageID()

        let pendingUserNotification = PendingUserNotification(
            key: "\(lastReactor.identity)\(reactionMessage.messageID.hexString)"
        )
        pendingUserNotification.abstractMessage = reactionMessage
        pendingUserNotification.baseMessage = reactedMessage

        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.notificationType = notificationType
        settingsStoreMock.pushShowPreview = true

        let userNotificationManager = UserNotificationManager(
            settingsStore: settingsStoreMock,
            userSettings: userSettingsMock,
            myIdentityStore: myIdentityStoreMock,
            pushSettingManager: PushSettingManagerMock(),
            contactStore: ContactStoreMock(),
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager,
            isWorkApp: false,
            fileUtility: FileUtilityMock(),
            isReactionNotificationsEnabled: isReactionNotificationsEnabled
        )

        return (
            userNotificationManager,
            userNotificationManager.userNotificationContent(pendingUserNotification),
            pendingUserNotification
        )
    }
}
