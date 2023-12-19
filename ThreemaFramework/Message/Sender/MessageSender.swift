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
import ThreemaEssentials

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
        let (messageID, receiverIdentity, group) = entityManager.performAndWaitSave {
            var messageID: Data?
            var receiverIdentity: String?
            var group: Group?

            if let messageConversation = self.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? Conversation,
                let message = self.entityManager.entityCreator.textMessage(for: messageConversation) {

                var remainingBody: NSString?
                if let quoteMessageID = QuoteUtil.parseQuoteV2(fromMessage: text, remainingBody: &remainingBody) {
                    message.quotedMessageID = quoteMessageID
                    message.text = remainingBody as String?
                }
                else {
                    message.text = text
                }

                if let requestID {
                    message.webRequestID = requestID
                }

                messageID = message.id

                group = self.groupManager.getGroup(conversation: message.conversation)
                if let group {
                    self.groupManager.periodicSyncIfNeeded(for: group)
                }
                else {
                    receiverIdentity = message.conversation.contact?.identity
                }
            }

            return (messageID, receiverIdentity, group)
        }

        guard let messageID else {
            DDLogError("Create text message failed")
            return
        }

        let task = TaskDefinitionSendBaseMessage(
            messageID: messageID,
            receiverIdentity: receiverIdentity,
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
        let (messageID, receiverIdentity, group) = entityManager.performAndWaitSave {
            var messageID: Data?
            var receiverIdentity: String?
            var group: Group?

            if let messageConversation = self.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? Conversation,
                let message = self.entityManager.entityCreator.locationMessage(for: messageConversation) {

                message.latitude = NSNumber(floatLiteral: coordinates.latitude)
                message.longitude = NSNumber(floatLiteral: coordinates.longitude)
                message.accuracy = NSNumber(floatLiteral: accuracy)
                message.poiName = poiName
                message.poiAddress = poiAddress

                messageID = message.id

                group = self.groupManager.getGroup(conversation: message.conversation)
                if let group {
                    self.groupManager.periodicSyncIfNeeded(for: group)
                }
                else {
                    receiverIdentity = message.conversation.contact?.identity
                }
            }

            return (messageID, receiverIdentity, group)
        }

        guard let messageID else {
            DDLogError("Create location message failed")
            return
        }

        // We replace \n with \\n to conform to specs
        let formattedAddress = poiAddress?.replacingOccurrences(of: "\n", with: "\\n")

        taskManager.add(
            taskDefinition: TaskDefinitionSendLocationMessage(
                poiAddress: formattedAddress,
                messageID: messageID,
                receiverIdentity: receiverIdentity,
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

        let (messageID, receiverIdentity, group, conversation) = entityManager.performAndWaitSave {
            var messageID: Data?
            var receiverIdentity: ThreemaIdentity?
            var group: Group?
            var conversation: Conversation?

            if let messageBallot = self.entityManager.entityFetcher.getManagedObject(by: ballot.objectID) as? Ballot,
               let message = self.entityManager.entityCreator.ballotMessage(for: messageBallot.conversation) {

                message.ballot = messageBallot

                messageID = message.id

                group = self.groupManager.getGroup(conversation: message.conversation)
                if let group {
                    self.groupManager.periodicSyncIfNeeded(for: group)
                }
                else {
                    receiverIdentity = message.conversation.contact?.threemaIdentity
                }

                conversation = message.conversation
            }

            return (messageID, receiverIdentity, group, conversation)
        }

        guard let messageID else {
            DDLogError("Create ballot message failed")
            return
        }

        taskManager.add(
            taskDefinition: TaskDefinitionSendBaseMessage(
                messageID: messageID,
                receiverIdentity: receiverIdentity?.string,
                group: group,
                sendContactProfilePicture: false
            )
        )

        if let conversation {
            donateInteractionForOutgoingMessage(in: conversation)
        }
    }

    @objc public func sendBallotVoteMessage(for ballot: Ballot) {
        guard BallotMessageEncoder.passesSanityCheck(ballot) else {
            DDLogError("Ballot did not pass sanity check. Do not send.")
            return
        }

        let (ballotID, receiverIdentity, group, conversation) = entityManager.performAndWait {
            let ballotID = ballot.id

            var receiverIdentity: ThreemaIdentity?
            let group = self.groupManager.getGroup(conversation: ballot.conversation)
            if let group {
                self.groupManager.periodicSyncIfNeeded(for: group)
            }
            else {
                receiverIdentity = ballot.conversation.contact?.threemaIdentity
            }

            let conversation = ballot.conversation

            return (ballotID, receiverIdentity, group, conversation)
        }

        guard let ballotID else {
            DDLogError("Ballot ID is nil")
            return
        }

        taskManager.add(
            taskDefinition: TaskDefinitionSendBallotVoteMessage(
                ballotID: ballotID,
                receiverIdentity: receiverIdentity?.string,
                group: group,
                sendContactProfilePicture: false
            )
        )

        if let conversation {
            donateInteractionForOutgoingMessage(in: conversation)
        }
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
        let (messageID, receiverIdentity, group) = entityManager.performAndWait {
            let messageID = baseMessage.id
            var receiverIdentity: ThreemaIdentity?
            let group = self.groupManager.getGroup(conversation: baseMessage.conversation)
            if group == nil {
                receiverIdentity = baseMessage.conversation.contact?.threemaIdentity
            }
            return (messageID, receiverIdentity, group)
        }

        guard let messageID else {
            DDLogError("Message ID is nil")
            return
        }

        taskManager.add(
            taskDefinition: TaskDefinitionSendBaseMessage(
                messageID: messageID,
                receiverIdentity: receiverIdentity?.string,
                group: group,
                sendContactProfilePicture: false
            )
        )
    }

    public func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> Promise<Void> {
        Promise { seal in
            guard let messageID = abstractMessage.messageID, !abstractMessage.noDeliveryReceiptFlagSet() else {
                seal.fulfill_()
                return
            }

            let task = TaskDefinitionSendDeliveryReceiptsMessage(
                fromIdentity: myIdentityStore.identity,
                toIdentity: abstractMessage.fromIdentity,
                receiptType: .received,
                receiptMessageIDs: [messageID],
                receiptReadDates: [Date](),
                excludeFromSending: [Data]()
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
            let contactEntity = self.entityManager.entityFetcher.contact(for: toIdentity.string)
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

        guard let group = groupManager.getGroup(toGroupIdentity.id, creator: toGroupIdentity.creator.string) else {
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

    public func sendTypingIndicator(typing: Bool, toIdentity: ThreemaIdentity) {
        guard entityManager.performAndWait({
            guard let contactEntity = self.entityManager.entityFetcher.contact(for: toIdentity.string) else {
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
        typingIndicatorMessage.toIdentity = toIdentity.string

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
        let trimmedText = ThreemaUtility.trimCharacters(in: rawText)
        let splitMessages = ThreemaUtilityObjC.getTrimmedMessages(trimmedText)
        
        if let splitMessages = splitMessages as? [String] {
            for splitMessage in splitMessages {
                sendTextMessage(
                    text: splitMessage,
                    in: conversation,
                    quickReply: false
                )
            }
        }
        else {
            sendTextMessage(
                text: trimmedText,
                in: conversation,
                quickReply: false
            )
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

                if toIdentity != contactEntity.threemaIdentity {
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
                            if receiptType == .read {
                                if let readDate = msgIDAndReadDate[key] as? Date {
                                    receiptMessageIDs.append(key)
                                    receiptReadDates.append(readDate)
                                }
                            }
                            else {
                                receiptMessageIDs.append(key)
                            }
                        }

                        if !receiptMessageIDs.isEmpty {
                            DDLogVerbose("Sending delivery receipt for message IDs: \(receiptMessageIDs)")

                            let taskSendDeliveryReceipts = TaskDefinitionSendDeliveryReceiptsMessage(
                                fromIdentity: self.myIdentityStore.identity,
                                toIdentity: toIdentity.string,
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
