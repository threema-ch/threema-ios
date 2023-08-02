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

import CocoaLumberjackSwift
import CoreLocation
import Foundation
import PromiseKit

public final class MessageSender: NSObject, MessageSenderProtocol {
    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let groupManager: GroupManagerProtocol
    private let taskManager: TaskManagerProtocol
    private let entityManager: EntityManager

    init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        groupManager: GroupManagerProtocol,
        taskManager: TaskManagerProtocol,
        entityManager: EntityManager
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.groupManager = groupManager
        self.taskManager = taskManager
        self.entityManager = entityManager

        super.init()
    }

    @objc public convenience init(entityManager: EntityManager) {
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            userSettings: UserSettings.shared(),
            groupManager: GroupManager(entityManager: entityManager),
            taskManager: TaskManager(),
            entityManager: entityManager
        )
    }

    @objc override public convenience init() {
        let entityManager = EntityManager()
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            userSettings: UserSettings.shared(),
            groupManager: GroupManager(entityManager: entityManager),
            taskManager: TaskManager(),
            entityManager: entityManager
        )
    }

    @objc public func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessage?) -> Void)?
    ) {
        guard let newMessage = entityManager.performAndWaitSave({
            var message: TextMessage?

            guard let messageConversation = self.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? Conversation else {
                return message
            }

            var remainingBody: NSString?
            let quoteMessageID = QuoteUtil.parseQuoteV2(fromMessage: text, remainingBody: &remainingBody)

            message = self.entityManager.entityCreator.textMessage(for: messageConversation)
            if let quoteMessageID {
                message?.quotedMessageID = quoteMessageID
                message?.text = remainingBody as String?
            }
            else {
                message?.text = text
            }

            if let requestID {
                message?.webRequestID = requestID
            }

            return message
        })
        else {
            DDLogError("Create text message failed")
            return
        }

        let group = groupManager.getGroup(conversation: conversation)
        if let group {
            groupManager.periodicSyncIfNeeded(for: group)
        }

        let task = TaskDefinitionSendBaseMessage(
            message: newMessage,
            group: group,
            sendContactProfilePicture: !quickReply
        )

        if let completion {
            taskManager.add(taskDefinition: task) { task, error in
                if let error {
                    DDLogError("Error while sending message \(error)")
                }
                if let task = task as? TaskDefinitionSendBaseMessage,
                   let message = self.entityManager.entityFetcher.message(
                       with: task.messageID,
                       conversation: conversation
                   ) {
                    completion(message)
                }
                else {
                    completion(nil)
                }
            }
        }
        else {
            taskManager.add(taskDefinition: task)
        }

        donateInteractionForOutgoingMessage(in: conversation)
    }

    @objc public func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: Conversation
    ) {
        guard let newMessage = entityManager.performAndWaitSave({
            var message: LocationMessage?

            guard let messageConversation = self.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? Conversation else {
                return message
            }

            message = self.entityManager.entityCreator.locationMessage(for: messageConversation)
            message?.latitude = NSNumber(floatLiteral: coordinates.latitude)
            message?.longitude = NSNumber(floatLiteral: coordinates.longitude)
            message?.accuracy = NSNumber(floatLiteral: accuracy)
            message?.poiName = poiName
            message?.poiAddress = poiAddress

            return message
        })
        else {
            DDLogError("Create location message failed")
            return
        }

        let group = groupManager.getGroup(conversation: conversation)
        if let group {
            groupManager.periodicSyncIfNeeded(for: group)
        }

        // We replace \n with \\n to conform to specs
        let formattedAddress = newMessage.poiAddress?.replacingOccurrences(of: "\n", with: "\\n")

        taskManager.add(
            taskDefinition: TaskDefinitionSendLocationMessage(
                poiAddress: formattedAddress,
                message: newMessage,
                group: group,
                sendContactProfilePicture: true
            )
        )

        donateInteractionForOutgoingMessage(in: conversation)
    }

    @objc public func sendBallotMessage(for ballot: Ballot) {
        guard BallotMessageEncoder.passesSanityCheck(ballot) else {
            DDLogError("Ballot did not pass sanity check. Do not send.")
            return
        }

        var conversation: Conversation!

        guard let newMessage = entityManager.performAndWaitSave({
            var message: BallotMessage?

            guard let messageBallot = self.entityManager.entityFetcher.getManagedObject(by: ballot.objectID) as? Ballot
            else {
                return message
            }

            conversation = messageBallot.conversation

            message = self.entityManager.entityCreator.ballotMessage(for: conversation)
            message?.ballot = messageBallot

            return message
        })
        else {
            DDLogError("Create ballot message failed")
            return
        }

        let group = groupManager.getGroup(conversation: conversation)
        if let group {
            groupManager.periodicSyncIfNeeded(for: group)
        }

        taskManager.add(
            taskDefinition: TaskDefinitionSendBaseMessage(
                message: newMessage,
                group: group,
                sendContactProfilePicture: false
            )
        )

        donateInteractionForOutgoingMessage(in: conversation)
    }

    @objc public func sendBallotVoteMessage(for ballot: Ballot) {
        guard BallotMessageEncoder.passesSanityCheck(ballot) else {
            DDLogError("Ballot did not pass sanity check. Do not send.")
            return
        }

        let group = groupManager.getGroup(conversation: ballot.conversation)
        if let group {
            groupManager.periodicSyncIfNeeded(for: group)
        }

        taskManager.add(
            taskDefinition: TaskDefinitionSendBallotVoteMessage(
                ballot: ballot,
                group: group,
                sendContactProfilePicture: false
            )
        )

        donateInteractionForOutgoingMessage(in: ballot.conversation)
    }

    public func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool, completion: (() -> Void)?) {
        taskManager.add(
            taskDefinition: TaskDefinitionSendAbstractMessage(
                message: abstractMessage,
                isPersistent: isPersistent
            )
        ) { _, _ in
            completion?()
        }
    }

    @objc public func sendMessage(baseMessage: BaseMessage) {
        taskManager.add(
            taskDefinition: TaskDefinitionSendBaseMessage(
                message: baseMessage,
                group: nil,
                sendContactProfilePicture: false
            )
        )
    }

    public func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> Promise<Void> {
        Promise { seal in
            guard let messageID = abstractMessage.messageID else {
                seal.fulfill_()
                return
            }

            var excludeFromSending = [Data]()
            if abstractMessage.noDeliveryReceiptFlagSet() {
                DDLogWarn(
                    "Exclude from sending receipt (noDeliveryReceiptFlagSet) for message ID: \(messageID.hexString)"
                )
                excludeFromSending.append(messageID)
            }

            let task = TaskDefinitionSendDeliveryReceiptsMessage(
                fromIdentity: myIdentityStore.identity,
                toIdentity: abstractMessage.fromIdentity,
                receiptType: .received,
                receiptMessageIDs: [messageID],
                receiptReadDates: [Date](),
                excludeFromSending: excludeFromSending
            )
            taskManager.add(taskDefinition: task) { _, error in
                if let error {
                    seal.reject(error)
                }
                else {
                    seal.fulfill_()
                }
            }
        }
    }

    /// Send read receipt for one to one chat messages
    /// - Parameters:
    ///   - messages: Send read receipts for this messages
    ///   - toIdentity: Group of the messages
    public func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaIdentity) async {
        let doSendReadReceipt = await entityManager.perform {
            // Is multi device not activated and not sending read receipt to contact, then nothing is to do
            let contactEntity = self.entityManager.entityFetcher.contact(for: toIdentity)
            return !(!self.doSendReadReceipt(to: contactEntity) && !self.userSettings.enableMultiDevice)
        }

        if doSendReadReceipt {
            await sendReceipt(
                for: messages,
                receiptType: .read,
                toIdentity: toIdentity
            )
        }
    }

    /// Send read receipt for group messages (only is Multi Device activated)
    /// - Parameters:
    ///   - messages: Send read receipts for this messages
    ///   - toGroupIdentity: Group of the messages
    public func sendReadReceipt(for messages: [BaseMessage], toGroupIdentity: GroupIdentity) async {
        // Is multi device not activated do sending (reflect only) read receipt to group
        guard userSettings.enableMultiDevice else {
            return
        }

        guard let group = groupManager.getGroup(toGroupIdentity.id, creator: toGroupIdentity.creator) else {
            DDLogError("Group not found for \(toGroupIdentity)")
            return
        }

        await sendReceipt(
            for: messages,
            receiptType: .read,
            toGroup: group
        )
    }

    public func sendUserAck(for message: BaseMessage, toIdentity: ThreemaIdentity) async {
        await updateUserReaction(on: message, with: .ack)
        await sendReceipt(for: [message], receiptType: .ack, toIdentity: toIdentity)
    }

    public func sendUserAck(for message: BaseMessage, toGroup: Group) async {
        await updateUserReaction(on: message, with: .acknowledged)
        await sendReceipt(for: [message], receiptType: .ack, toGroup: toGroup)
    }

    public func sendUserDecline(for message: BaseMessage, toIdentity: ThreemaIdentity) async {
        await updateUserReaction(on: message, with: .decline)
        await sendReceipt(for: [message], receiptType: .decline, toIdentity: toIdentity)
    }

    public func sendUserDecline(for message: BaseMessage, toGroup: Group) async {
        await updateUserReaction(on: message, with: .declined)
        await sendReceipt(for: [message], receiptType: .decline, toGroup: toGroup)
    }

    @objc public func sendTypingIndicator(typing: Bool, toIdentity: ThreemaIdentity) {
        guard entityManager.performAndWait({
            guard let contactEntity = self.entityManager.entityFetcher.contact(for: toIdentity) else {
                return false
            }

            return self.doSendTypingIndicator(to: contactEntity)
        })
        else {
            return
        }

        DDLogVerbose("Sending typing indicator \(typing ? "on" : "off") to \(toIdentity)")

        let typingIndicatorMessage = TypingIndicatorMessage()
        typingIndicatorMessage.typing = typing
        typingIndicatorMessage.toIdentity = toIdentity

        taskManager.add(
            taskDefinition: TaskDefinitionSendAbstractMessage(
                message: typingIndicatorMessage,
                isPersistent: false
            )
        )
    }

    public func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool {
        guard let contactEntity else {
            return false
        }

        return (userSettings.sendReadReceipts && contactEntity.readReceipt == .default)
            || contactEntity.readReceipt == .send
    }

    public func doSendReadReceipt(to conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }

        return doSendReadReceipt(to: conversation.contact)
    }

    public func doSendTypingIndicator(to contactEntity: ContactEntity?) -> Bool {
        guard let contactEntity else {
            return false
        }

        return (userSettings.sendTypingIndicator && contactEntity.typingIndicator == .default) || contactEntity
            .typingIndicator == .send
    }

    @objc public func doSendTypingIndicator(to conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }

        return doSendTypingIndicator(to: conversation.contact)
    }

    public func sanitizeAndSendText(_ rawText: String, in conversation: Conversation) {
        DispatchQueue.global(qos: .userInitiated).async {
            let trimmedText = ThreemaUtility.trimCharacters(in: rawText)
            let splitMessages = ThreemaUtilityObjC.getTrimmedMessages(trimmedText)

            if let splitMessages = splitMessages as? [String] {
                for splitMessage in splitMessages {
                    DispatchQueue.main.async {
                        self.sendTextMessage(
                            text: splitMessage,
                            in: conversation,
                            quickReply: false
                        )
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    self.sendTextMessage(
                        text: trimmedText,
                        in: conversation,
                        quickReply: false
                    )
                }
            }
        }
    }

    // MARK: Donate interaction

    func donateInteractionForOutgoingMessage(in conversation: Conversation) {
        donateInteractionForOutgoingMessage(in: conversation.objectID)
            .done { donated in
                if donated {
                    DDLogVerbose("[Intents] Successfully donated interaction for conversation")
                }
                else {
                    DDLogVerbose("[Intents] Could not donate interaction for conversation")
                }
            }
    }

    func donateInteractionForOutgoingMessage(
        in conversationManagedObjectID: NSManagedObjectID,
        backgroundEntityManager: EntityManager = EntityManager(withChildContextForBackgroundProcess: true)
    ) -> Guarantee<Bool> {
        firstly {
            Guarantee { $0(userSettings.allowOutgoingDonations) }
        }
        .then { doDonateInteractions -> Guarantee<Bool> in
            Guarantee<Bool> { seal in
                guard doDonateInteractions else {
                    DDLogVerbose("Donations are disabled by the user")
                    seal(false)
                    return
                }

                let backgroundGroupManager = GroupManager(entityManager: backgroundEntityManager)

                backgroundEntityManager.performBlockAndWait {
                    guard let conversation = backgroundEntityManager.entityFetcher
                        .existingObject(with: conversationManagedObjectID) as? Conversation else {
                        let msg = "Could not donate interaction because object is not a conversation"
                        DDLogError(msg)
                        assertionFailure(msg)

                        seal(false)
                        return
                    }

                    guard conversation.conversationCategory != .private else {
                        DDLogVerbose("Do not donate for private conversations")
                        seal(false)
                        return
                    }

                    if conversation.isGroup(),
                       let group = backgroundGroupManager.getGroup(conversation: conversation) {
                        _ = IntentCreator(
                            userSettings: self.userSettings,
                            entityManager: backgroundEntityManager
                        )
                        .donateInteraction(for: group).done {
                            seal(true)
                        }.catch { _ in
                            seal(false)
                        }
                    }
                    else {
                        guard let contact = conversation.contact else {
                            seal(false)
                            return
                        }
                        _ = IntentCreator(
                            userSettings: self.userSettings,
                            entityManager: backgroundEntityManager
                        )
                        .donateInteraction(for: contact).done {
                            seal(true)
                        }.catch { _ in
                            seal(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: Private functions

    private func sendReceipt(
        for messages: [BaseMessage],
        receiptType: ReceiptType,
        toIdentity: ThreemaIdentity
    ) async {
        // Get message ID's and receipt dates for sending and exclude from sending if noDeliveryReceiptFlagSet
        guard let (msgIDAndReadDate, excludeFromSending) = await entityManager.perform({
            var msgIDAndReadDate = [Data: Date?]()
            var excludeFromSending = [Data]()
            for message in messages {
                guard let contactEntity = message.conversation.contact else {
                    continue
                }

                if toIdentity != contactEntity.identity {
                    DDLogError("Bad from identity encountered while sending receipt")
                }
                else {
                    msgIDAndReadDate[message.id] = receiptType == .read ? message
                        .readDate : nil

                    if message.noDeliveryReceiptFlagSet() {
                        DDLogWarn(
                            "Exclude from sending receipt (noDeliveryReceiptFlagSet) for message ID: \(message.id.hexString)"
                        )
                        excludeFromSending.append(message.id)
                    }
                }
            }
            return (msgIDAndReadDate, excludeFromSending)
        }), !msgIDAndReadDate.isEmpty else {
            return
        }

        await withTaskGroup(of: Void.self, body: { taskGroup in
            // Chunks messages to max count of 800 ID's per delivery message receipt task, so that not exceeds max
            // message size.
            let chunkedKeys = Array(msgIDAndReadDate.keys).chunked(into: 800)

            for keys in chunkedKeys {
                taskGroup.addTask {
                    await withCheckedContinuation { continuation in
                        var receiptMessageIDs = [Data]()
                        var receiptReadDates = [Date]()

                        for key in keys {
                            receiptMessageIDs.append(key)
                            if let readDate = msgIDAndReadDate[key] as? Date {
                                receiptReadDates.append(readDate)
                            }
                        }

                        if !receiptMessageIDs.isEmpty {
                            DDLogVerbose("Sending delivery receipt for message IDs: \(receiptMessageIDs)")

                            let taskSendDeliveryReceipts = TaskDefinitionSendDeliveryReceiptsMessage(
                                fromIdentity: self.myIdentityStore.identity,
                                toIdentity: toIdentity,
                                receiptType: receiptType,
                                receiptMessageIDs: receiptMessageIDs,
                                receiptReadDates: receiptReadDates,
                                excludeFromSending: excludeFromSending
                            )

                            self.taskManager.add(taskDefinition: taskSendDeliveryReceipts) { task, error in
                                if let error {
                                    if case TaskManagerError.flushedTask = error {
                                        return continuation.resume()
                                    }

                                    DDLogError("\(task) to send read receipts failed: \(error)")
                                    return
                                }
                                return continuation.resume()
                            }
                        }
                        else {
                            return continuation.resume()
                        }
                    }
                }
            }
        })
    }

    private func sendReceipt(
        for messages: [BaseMessage],
        receiptType: ReceiptType,
        toGroup: Group
    ) async {
        // Get message ID's and receipt dates for sending
        guard let msgIDAndReadDate = await entityManager.perform({
            var msgIDAndReadDate = [Data: Date?]()
            for message in messages {
                if toGroup.groupID != message.conversation.groupID {
                    DDLogError("Bad from group encountered while sending receipt")
                }
                else if receiptType != .read,
                        receiptType != .ack,
                        receiptType != .decline {
                    DDLogWarn("Do not send receipt type \(receiptType) for message ID: \(message.id.hexString)")
                }
                else {
                    msgIDAndReadDate[message.id] = receiptType == .read ? message
                        .readDate : nil
                }
            }
            return msgIDAndReadDate
        }), !msgIDAndReadDate.isEmpty else {
            return
        }

        await withTaskGroup(of: Void.self, body: { taskGroup in
            // Chunks messages to max count of 800 ID's per delivery message receipt task, so that not exceeds max
            // message size.
            let chunkedKeys = Array(msgIDAndReadDate.keys).chunked(into: 800)

            for keys in chunkedKeys {
                taskGroup.addTask {
                    await withCheckedContinuation { continuation in
                        var receiptMessageIDs = [Data]()
                        var receiptReadDates = [Date]()

                        for key in keys {
                            receiptMessageIDs.append(key)
                            if let readDate = msgIDAndReadDate[key] as? Date {
                                receiptReadDates.append(readDate)
                            }
                        }

                        if !receiptMessageIDs.isEmpty {
                            DDLogVerbose("Sending delivery receipt for message IDs: \(receiptMessageIDs)")

                            let taskSendDeliveryReceipts = TaskDefinitionSendGroupDeliveryReceiptsMessage(
                                group: toGroup,
                                from: self.myIdentityStore.identity,
                                to: Array(toGroup.allMemberIdentities),
                                receiptType: receiptType,
                                receiptMessageIDs: receiptMessageIDs,
                                receiptReadDates: receiptReadDates
                            )
                            self.taskManager.add(taskDefinition: taskSendDeliveryReceipts) { task, error in
                                if let error {
                                    if case TaskManagerError.flushedTask = error {
                                        return continuation.resume()
                                    }

                                    DDLogError("\(task) to send read receipts failed: \(error)")
                                    return
                                }
                                return continuation.resume()
                            }
                        }
                        else {
                            return continuation.resume()
                        }
                    }
                }
            }
        })
    }

    private func updateUserReaction(on message: BaseMessage, with receiptType: ReceiptType) async {
        guard receiptType != .ack || receiptType != .decline else {
            return
        }

        await entityManager.performSave {
            let ack = receiptType == .ack

            message.userack = NSNumber(booleanLiteral: ack)
            message.userackDate = Date()

            if message.id == message.conversation.lastMessage?.id {
                message.conversation.lastMessage = message
            }
        }
    }

    private func updateUserReaction(
        on message: BaseMessage,
        with groupReceiptType: GroupDeliveryReceipt.DeliveryReceiptType
    ) async {
        await entityManager.performSave {
            let groupDeliveryReceipt = GroupDeliveryReceipt(
                identity: MyIdentityStore.shared().identity,
                deliveryReceiptType: groupReceiptType,
                date: Date()
            )

            message.add(groupDeliveryReceipt: groupDeliveryReceipt)

            if message.id == message.conversation.lastMessage?.id {
                message.conversation.lastMessage = message
            }
        }
    }
}
