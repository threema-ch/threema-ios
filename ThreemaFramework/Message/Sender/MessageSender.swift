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

public class MessageSender: NSObject, MessageSenderProtocol {
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
                doOnlyReflect: false,
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
            let messageID = abstractMessage.messageID.hexString
            if abstractMessage.noDeliveryReceiptFlagSet() {
                DDLogVerbose("Do not send delivery receipt (noDeliveryReceiptFlagSet) for message ID: \(messageID)")
                seal.fulfill_()
            }
            else {
                DDLogVerbose("Sending delivery receipt for message ID: \(messageID)")
                let deliveryReceipt = DeliveryReceiptMessage()
                deliveryReceipt.receiptType = UInt8(DELIVERYRECEIPT_MSGRECEIVED)
                deliveryReceipt.receiptMessageIDs = [abstractMessage.messageID!]
                deliveryReceipt.fromIdentity = myIdentityStore.identity
                deliveryReceipt.toIdentity = abstractMessage.fromIdentity

                let task = TaskDefinitionSendAbstractMessage(message: deliveryReceipt)
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
    }

    /// Send read receipt for one to one chat messages
    /// - Parameters:
    ///   - messages: Send read receipts for this messages
    ///   - toIdentity: Group of the messages
    public func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaIdentity) async {
        let doSendReadReceipt = await entityManager.perform {
            // Is multi device not activated and not sending read receipt to contact, then nothing is to do
            let contactEntity = self.entityManager.entityFetcher.contact(for: toIdentity)
            return !(!self.doSendReadReceipt(to: contactEntity) && !self.serverConnector.isMultiDeviceActivated)
        }

        if doSendReadReceipt {
            await sendReceipt(
                for: messages,
                receiptType: UInt8(DELIVERYRECEIPT_MSGREAD),
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
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        guard let group = groupManager.getGroup(toGroupIdentity.id, creator: toGroupIdentity.creator) else {
            DDLogError("Group not found for \(toGroupIdentity)")
            return
        }

        await sendReceipt(
            for: messages,
            receiptType: UInt8(DELIVERYRECEIPT_MSGREAD),
            toGroup: group
        )
    }

    public func sendUserAck(for message: BaseMessage, toIdentity: ThreemaIdentity) async {
        let receiptType = UInt8(DELIVERYRECEIPT_MSGUSERACK)
        await sendReceipt(for: [message], receiptType: receiptType, toIdentity: toIdentity)
        await updateForContact(receiptType: receiptType, in: message)
    }

    public func sendUserAck(for message: BaseMessage, toGroup: Group) async {
        await sendReceipt(for: [message], receiptType: UInt8(DELIVERYRECEIPT_MSGUSERACK), toGroup: toGroup)
        await updateForGroup(receiptType: .acknowledged, in: message)
    }

    public func sendUserDecline(for message: BaseMessage, toIdentity: ThreemaIdentity) async {
        let receiptType = UInt8(DELIVERYRECEIPT_MSGUSERDECLINE)
        await sendReceipt(for: [message], receiptType: receiptType, toIdentity: toIdentity)
        await updateForContact(receiptType: receiptType, in: message)
    }

    public func sendUserDecline(for message: BaseMessage, toGroup: Group) async {
        await sendReceipt(for: [message], receiptType: UInt8(DELIVERYRECEIPT_MSGUSERDECLINE), toGroup: toGroup)
        await updateForGroup(receiptType: .declined, in: message)
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
                doOnlyReflect: false,
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
        receiptType: UInt8,
        toIdentity: ThreemaIdentity
    ) async {
        // Get message ID's and receipt dates for sending
        guard let msgIDAndReadDate = await entityManager.perform({
            var msgIDAndReadDate = [Data: Date?]()
            for message in messages {
                guard let contactEntity = message.conversation.contact else {
                    continue
                }

                if toIdentity != contactEntity.identity {
                    DDLogError("Bad from identity encountered while sending receipt")
                }
                else if receiptType == UInt8(DELIVERYRECEIPT_MSGREAD), message.noDeliveryReceiptFlagSet() {
                    DDLogWarn("Do not send receipt (noDeliveryReceiptFlagSet) for message ID: \(message.id.hexString)")
                }
                else {
                    msgIDAndReadDate[message.id] = receiptType == UInt8(DELIVERYRECEIPT_MSGREAD) ? message
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

                            let task = TaskDefinitionSendDeliveryReceiptsMessage(
                                fromIdentity: self.myIdentityStore.identity,
                                toIdentity: toIdentity,
                                receiptType: receiptType,
                                receiptMessageIDs: receiptMessageIDs,
                                receiptReadDates: receiptReadDates
                            )
                            self.taskManager.add(taskDefinition: task) { _, error in
                                if let error {
                                    DDLogError("Task to send read receipts failed: \(error)")
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
        receiptType: UInt8,
        toGroup: Group
    ) async {
        // Get message ID's and receipt dates for sending
        guard let msgIDAndReadDate = await entityManager.perform({
            var msgIDAndReadDate = [Data: Date?]()
            for message in messages {
                if toGroup.groupID != message.conversation.groupID {
                    DDLogError("Bad from group encountered while sending receipt")
                }
                else if receiptType != UInt8(DELIVERYRECEIPT_MSGREAD),
                        receiptType != UInt8(DELIVERYRECEIPT_MSGUSERACK),
                        receiptType != UInt8(DELIVERYRECEIPT_MSGUSERDECLINE) {
                    DDLogWarn("Do not send receipt type \(receiptType) for message ID: \(message.id.hexString)")
                }
                else {
                    msgIDAndReadDate[message.id] = receiptType == UInt8(DELIVERYRECEIPT_MSGREAD) ? message
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

                            let task = TaskDefinitionSendGroupDeliveryReceiptsMessage(
                                group: toGroup,
                                from: self.myIdentityStore.identity,
                                to: Array(toGroup.allMemberIdentities),
                                receiptType: receiptType,
                                receiptMessageIDs: receiptMessageIDs,
                                receiptReadDates: receiptReadDates
                            )
                            self.taskManager.add(taskDefinition: task) { _, error in
                                if let error {
                                    DDLogError("Task to send read receipts failed: \(error)")
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

    private func updateForContact(receiptType: UInt8, in message: BaseMessage) async {
        guard receiptType != UInt8(DELIVERYRECEIPT_MSGUSERACK) || receiptType != UInt8(DELIVERYRECEIPT_MSGUSERDECLINE)
        else {
            return
        }

        await entityManager.performSave {
            let ack = receiptType == UInt8(DELIVERYRECEIPT_MSGUSERACK)

            message.userack = NSNumber(booleanLiteral: ack)
            message.userackDate = Date()

            if message.id == message.conversation.lastMessage?.id {
                message.conversation.lastMessage = message
            }
        }
    }

    private func updateForGroup(receiptType: GroupDeliveryReceipt.DeliveryReceiptType, in message: BaseMessage) async {
        await entityManager.performSave {
            let groupDeliveryReceipt = GroupDeliveryReceipt(
                identity: MyIdentityStore.shared().identity,
                deliveryReceiptType: receiptType,
                date: Date()
            )

            message.add(groupDeliveryReceipt: groupDeliveryReceipt)

            if message.id == message.conversation.lastMessage?.id {
                message.conversation.lastMessage = message
            }
        }
    }
}

extension MessageSender {
    @objc public func sendUserAckObjc(for message: BaseMessage, toIdentity: ThreemaIdentity) {
        Task {
            await sendUserAck(for: message, toIdentity: toIdentity)
        }
    }

    @objc public func sendUserAckObjc(for message: BaseMessage, toGroup: Group) {
        Task {
            await sendUserAck(for: message, toGroup: toGroup)
        }
    }

    @objc public func sendUserDeclineObjc(for message: BaseMessage, toIdentity: ThreemaIdentity) {
        Task {
            await sendUserDecline(for: message, toIdentity: toIdentity)
        }
    }

    @objc public func sendUserDeclineObjc(for message: BaseMessage, toGroup: Group) {
        Task {
            await sendUserDecline(for: message, toGroup: toGroup)
        }
    }
}
