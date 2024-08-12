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
import ThreemaProtocols

public final class MessageSender: NSObject, MessageSenderProtocol {
    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let groupManager: GroupManagerProtocol
    private let taskManager: TaskManagerProtocol
    private let entityManager: EntityManager
    private let blobManager: BlobManagerProtocol
    private let blobMessageSender: BlobMessageSender
    
    // MARK: - Lifecycle
    
    init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        groupManager: GroupManagerProtocol,
        taskManager: TaskManagerProtocol,
        entityManager: EntityManager,
        blobManger: BlobManagerProtocol,
        blobMessageSender: BlobMessageSender
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.groupManager = groupManager
        self.taskManager = taskManager
        self.entityManager = entityManager
        self.blobManager = blobManger
        self.blobMessageSender = blobMessageSender
        
        super.init()
    }
    
    convenience init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        groupManager: GroupManagerProtocol,
        taskManager: TaskManagerProtocol,
        entityManager: EntityManager
    ) {
        self.init(
            serverConnector: serverConnector,
            myIdentityStore: myIdentityStore,
            userSettings: userSettings,
            groupManager: groupManager,
            taskManager: taskManager,
            entityManager: entityManager,
            blobManger: BlobManager.shared,
            blobMessageSender: BlobMessageSender()
        )
    }
    
    convenience init(entityManager: EntityManager, taskManager: TaskManagerProtocol) {
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            userSettings: UserSettings.shared(),
            groupManager: GroupManager(entityManager: entityManager, taskManager: taskManager),
            taskManager: taskManager,
            entityManager: entityManager
        )
    }
    
    // MARK: - Type specific sending
    
    // MARK: Text

    @discardableResult
    public func sendTextMessage(
        containing text: String,
        in conversation: Conversation,
        sendProfilePicture: Bool = true,
        requestID: String? = nil
    ) async -> [TextMessage] {
        let trimmedText = ThreemaUtility.trimCharacters(in: text)
        let textsToSend = ThreemaUtility.trimMessageText(text: trimmedText)
        let textMessages = await createTextMessages(
            texts: textsToSend,
            conversation: conversation,
            requestID: requestID
        )
        let tasks = await createTasks(
            textMessages: textMessages,
            conversation: conversation,
            sendProfilePicture: sendProfilePicture
        )
        
        await executeSendTextMessageTasks(tasks)
        
        donateInteractionForOutgoingMessage(in: conversation)
        
        return textMessages
    }
    
    private func createTextMessages(
        texts: [String],
        conversation: Conversation,
        requestID: String?
    ) async -> [TextMessage] {
        var textMessages = [TextMessage]()
        
        for text in texts {
            let textMessage: TextMessage? = await entityManager.performSave {
                
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
                    
                    return message
                }
                return nil
            }
            
            if let textMessage {
                textMessages.append(textMessage)
            }
        }
        
        assert(
            texts.count == textMessages.count,
            "Could not create TextMessages for all texts. Texts=\(texts.count), TextMessages=\(textMessages.count)."
        )
        return textMessages
    }
    
    private func createTasks(
        textMessages: [TextMessage],
        conversation: Conversation,
        sendProfilePicture: Bool
    ) async -> [TaskDefinitionSendBaseMessage] {
        var tasks = [TaskDefinitionSendBaseMessage]()
        
        for textMessage in textMessages {
            let task = await entityManager.perform {
                var task: TaskDefinitionSendBaseMessage? = nil
                if let group = self.groupManager.getGroup(conversation: conversation) {
                    self.groupManager.periodicSyncIfNeeded(for: group)
                    let receivers = group.members.map(\.identity)
                    task = TaskDefinitionSendBaseMessage(
                        messageID: textMessage.id,
                        group: group,
                        receivers: receivers,
                        sendContactProfilePicture: sendProfilePicture
                    )
                }
                else if let receiver = textMessage.conversation.contact?.identity {
                    task = TaskDefinitionSendBaseMessage(
                        messageID: textMessage.id,
                        receiverIdentity: receiver,
                        sendContactProfilePicture: sendProfilePicture
                    )
                }
                
                return task
            }
            
            if let task {
                tasks.append(task)
            }
        }
        
        assert(
            textMessages.count == tasks.count,
            "Could not create Tasks for all TextMessages. TextMessages=\(textMessages.count), Tasks=\(tasks.count)."
        )
        return tasks
    }
    
    private func executeSendTextMessageTasks(_ sendBaseMessageTasks: [TaskDefinitionSendBaseMessage]) async {
        // The `TaskManager.add *MUST* be called in the right order.
        await withCheckedContinuation { continuation in
            var localContinuation: CheckedContinuation<Void, Never>? = continuation
            
            for sendBaseMessageTask in sendBaseMessageTasks {
                taskManager.add(taskDefinition: sendBaseMessageTask) { task, error in
                    if let error {
                        if case TaskManagerError.flushedTask = error {
                            assert(localContinuation != nil)
                            localContinuation?.resume()
                            localContinuation = nil
                        }

                        DDLogError("\(task) to send messages failed: \(error)")
                        return
                    }
                    
                    guard let task = task as? TaskDefinitionSendBaseMessage else {
                        assertionFailure("This must not happen.")
                        return
                    }
                    
                    if let last = sendBaseMessageTasks.last, last === task {
                        assert(localContinuation != nil)
                        localContinuation?.resume()
                        localContinuation = nil
                    }
                }
            }
        }
    }
    
    // MARK: - BlobMessage
    
    public func sendBlobMessage(
        for item: URLSenderItem,
        in conversationObjectID: NSManagedObjectID,
        correlationID: String?,
        webRequestID: String?
    ) async throws {
        // Check if we actually have data
        guard let data = item.getData() else {
            NotificationPresenterWrapper.shared.present(
                type: .sendingError,
                subtitle: BundleUtil.localizedString(forKey: "notification_sending_failed")
            )
            throw MessageSenderError.noData
        }
        
        // Check if the data is smaller than the max file size
        guard data.count < kMaxFileSize else {
            NotificationPresenterWrapper.shared.present(
                type: .sendingError,
                subtitle: BundleUtil.localizedString(forKey: "notification_sending_failed_subtitle_size")
            )
            throw MessageSenderError.tooBig
        }
        
        let em = entityManager
        // Create message
        let messageID = try await em.performSave {
            guard let localConversation = em.entityFetcher.existingObject(
                with: conversationObjectID
            ) as? Conversation else {
                throw MessageSenderError.unableToLoadConversation
            }
            
            let origin: BlobOrigin =
                if localConversation.isGroup(),
                let group = self.groupManager.getGroup(conversation: localConversation),
                group.isNoteGroup {
                    .local
                }
                else {
                    .public
                }
            
            let fileMessageEntity = try em.entityCreator.createFileMessageEntity(
                for: item,
                in: localConversation,
                with: origin,
                correlationID: correlationID,
                webRequestID: webRequestID
            )
            
            return fileMessageEntity.id
        }
        
        guard let messageID else {
            throw MessageSenderError.noID
        }
        
        // Fetch it again to get a non temporary objectID
        let fileMessageObjectID = try await em.perform {
            guard let localConversation = em.entityFetcher.existingObject(
                with: conversationObjectID
            ) as? Conversation else {
                throw MessageSenderError.unableToLoadConversation
            }
            
            guard let fileMessage = em.entityFetcher.message(
                with: messageID,
                conversation: localConversation
            ) as? FileMessageEntity else {
                throw MessageSenderError.unableToLoadMessage
            }
            
            return fileMessage.objectID
        }
        
        try await syncAndSendBlobMessage(with: fileMessageObjectID)
    }
    
    @available(*, deprecated, message: "Only use from Objective-C code")
    @objc public func sendBlobMessage(
        for item: URLSenderItem,
        inConversationWithID conversationID: NSManagedObjectID,
        correlationID: String?,
        webRequestID: String?,
        completion: ((Error?) -> Void)?
    ) {
        Task {
            do {
                try await sendBlobMessage(
                    for: item,
                    in: conversationID,
                    correlationID: correlationID,
                    webRequestID: webRequestID
                )
                completion?(nil)
            }
            catch {
                DDLogError("Could not create message and sync blobs due to: \(error)")
                completion?(error)
            }
        }
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

    // MARK: - Generic sending
    
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

    public func sendBaseMessage(with objectID: NSManagedObjectID, to receivers: MessageSenderReceivers) async {
        let isBlobData: Bool? = entityManager.performAndWaitSave {
            guard let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
            else {
                return nil
            }
            
            return baseMessage is BlobData
        }
    
        guard let isBlobData else {
            DDLogError("Unable to load message with object id \(objectID)")
            return
        }
        
        @Sendable func resetSendingErrorIfValid() {
            entityManager.performAndWaitSave {
                // We just checked above that a base message with this objectID exists
                guard let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
                else {
                    return
                }
                
                if baseMessage.isGroupMessage {
                    // 3. If `receivers` includes the list of group members requesting a re-send
                    //    of `message`², remove the _re-send requested_ mark on `message` [...]
                    switch receivers {
                    case .all:
                        baseMessage.sendFailed = false
                    case let .groupMembers(receivingMembers):
                        let rejectedByIdentities = Set(
                            baseMessage.rejectedBy?.map { ThreemaIdentity($0.identity) } ?? []
                        )
                        
                        if rejectedByIdentities.subtracting(receivingMembers).isEmpty {
                            baseMessage.sendFailed = false
                        }
                        else {
                            // For blob message this might be reset so we set it again
                            baseMessage.sendFailed = true
                        }
                    }
                }
                else {
                    // 2. Remove the _re-send requested_ mark on `message`
                    baseMessage.sendFailed = false
                }
            }
        }
        
        // Set error state if blob sync or sending task creation fails
        @Sendable func setSendingError() {
            entityManager.performAndWaitSave {
                // We just checked above that a base message with this objectID exists
                let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
                baseMessage?.sendFailed = true
            }
        }
        
        if isBlobData {
            do {
                try await syncAndSendBlobMessage(with: objectID, to: receivers)
                resetSendingErrorIfValid()
            }
            catch {
                DDLogError("Unable to send blob base message: \(error)")
                setSendingError()
            }
        }
        else {
            do {
                try sendNonBlobMessage(with: objectID, to: receivers)
                resetSendingErrorIfValid()
            }
            catch {
                DDLogError("Unable to send base message: \(error)")
                setSendingError()
            }
        }
    }

    public func sendDeleteMessage(with objectID: NSManagedObjectID, receiversExcluded: [Contact]?) throws {
        let (messageID, receiverIdentity, group) = try entityManager.performAndWait {
            guard let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
            else {
                throw MessageSenderError.unableToLoadMessage
            }

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
            throw MessageSenderError.sendingFailed
        }

        var e2eDeleteMessage = CspE2e_DeleteMessage()
        e2eDeleteMessage.messageID = try messageID.littleEndian()

        let task = TaskDefinitionSendDeleteEditMessage(
            receiverIdentity: receiverIdentity,
            group: group,
            deleteMessage: e2eDeleteMessage
        )

        if let group {
            if let receiversExcluded {
                task.receivingGroupMembers = Set(
                    group.members.filter { !receiversExcluded.contains($0) }
                        .map(\.identity.string)
                )
            }
        }

        taskManager.add(taskDefinition: task)
    }

    public func sendEditMessage(
        with objectID: NSManagedObjectID,
        rawText: String,
        receiversExcluded: [Contact]?
    ) throws {
        let trimmedText = ThreemaUtility.trimCharacters(in: rawText)
        guard trimmedText.data(using: .utf8)?.count ?? 0 <= kMaxMessageLen else {
            throw MessageSenderError.editedTextToLong
        }

        let (hasTextChanged, messageID, receiverIdentity, group) = try entityManager.performAndWaitSave {
            guard let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
            else {
                throw MessageSenderError.unableToLoadMessage
            }
            
            var hasTextChanged = false
            var previousText: String?
            
            // Save edited text
            if let textMessage = baseMessage as? TextMessage,
               textMessage.text != trimmedText {
                
                // Save history
                if let prevText = textMessage.text {
                    previousText = prevText
                }
                
                // Update message
                textMessage.text = trimmedText
                hasTextChanged = true
            }
            else if let fileMessage = baseMessage as? FileMessageEntity,
                    fileMessage.caption != trimmedText {
                
                // Save history
                if let previousCaption = fileMessage.caption {
                    previousText = previousCaption
                }
                
                // Update message
                fileMessage.caption = trimmedText
                fileMessage.json = FileMessageEncoder.jsonString(for: fileMessage)
                hasTextChanged = true
            }
            
            if hasTextChanged, let history = self.entityManager.entityCreator.messageHistoryEntry(for: baseMessage) {
                history.message = baseMessage
                history.editDate = baseMessage.lastEditedAt ?? baseMessage.date
                history.text = previousText
            }
            else {
                DDLogError("[MessageSender] Text did not change or could not create MessageHistoryEntry")
            }

            let messageID = baseMessage.id
            var receiverIdentity: ThreemaIdentity?
            let group = self.groupManager.getGroup(conversation: baseMessage.conversation)
            if group == nil {
                receiverIdentity = baseMessage.conversation.contact?.threemaIdentity
            }
            return (hasTextChanged, messageID, receiverIdentity, group)
        }

        assert(receiverIdentity != nil || group != nil)

        guard hasTextChanged else {
            return
        }

        guard let messageID else {
            DDLogError("Message ID is nil")
            throw MessageSenderError.sendingFailed
        }

        var e2eEditMessage = CspE2e_EditMessage()
        e2eEditMessage.messageID = try messageID.littleEndian()
        e2eEditMessage.text = ThreemaUtility.trimCharacters(in: rawText)

        let task = TaskDefinitionSendDeleteEditMessage(
            receiverIdentity: receiverIdentity,
            group: group,
            editMessage: e2eEditMessage
        )

        if let group {
            if let receiversExcluded {
                task.receivingGroupMembers = Set(
                    group.members.filter { !receiversExcluded.contains($0) }
                        .map(\.identity.string)
                )
            }
        }

        taskManager.add(taskDefinition: task)
    }

    // MARK: - Status update

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
    ///   - messages: Messages to send the read receipt for
    ///   - toIdentity: Receiver of the message
    public func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaIdentity) async {
        let doSendReadReceipt = await entityManager.perform {
            // If multi device not activated and if sending read receipt to contact is disabled, then there is nothing
            // to do
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
    ///   - messages: Messages to send the read receipt for
    ///   - toGroupIdentity: Group of the messages
    public func sendReadReceipt(for messages: [BaseMessage], toGroupIdentity: GroupIdentity) async {
        // Multi device must be activated to do the sending (reflect only) of the read receipt
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

    // MARK: - Donate interaction

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

    // - MARK: Private functions

    private func syncAndSendBlobMessage(
        with objectID: NSManagedObjectID,
        to receivers: MessageSenderReceivers = .all
    ) async throws {
        let result = try await blobManager.syncBlobsThrows(for: objectID)
        
        if result == .uploaded {
            try await blobMessageSender.sendBlobMessage(with: objectID, to: receivers)
        }
        else {
            DDLogError(
                "Sending blob message (\(objectID)) failed, because sync result was \(result) instead of .uploaded"
            )
            throw MessageSenderError.sendingFailed
        }
    }
    
    private func sendNonBlobMessage(with objectID: NSManagedObjectID, to receivers: MessageSenderReceivers) throws {
        let (messageID, receiverIdentity, group) = try getMessageIDAndReceiver(for: objectID)

        guard let messageID else {
            DDLogError("Message ID is nil")
            throw MessageSenderError.sendingFailed
        }

        if let group {
            let receiverIdentities: [ThreemaIdentity] =
                switch receivers {
                case .all:
                    group.members.map(\.identity)
                case let .groupMembers(identities):
                    identities
                }
            
            let taskDefinition = TaskDefinitionSendBaseMessage(
                messageID: messageID,
                group: group,
                receivers: receiverIdentities,
                sendContactProfilePicture: false
            )
            
            taskManager.add(taskDefinition: taskDefinition)
        }
        else if let receiverIdentity {
            let taskDefinition = TaskDefinitionSendBaseMessage(
                messageID: messageID,
                receiverIdentity: receiverIdentity.string,
                sendContactProfilePicture: false
            )
            
            taskManager.add(taskDefinition: taskDefinition)
        }
        else {
            DDLogError(
                "Unable to create task for non blob message (\(objectID)): Group and receiver identity are both nil."
            )
            throw MessageSenderError.sendingFailed
        }
    }

    private func getMessageIDAndReceiver(for objectID: NSManagedObjectID) throws
        -> (messageID: Data?, receiverIdentity: ThreemaIdentity?, group: Group?) {
        try entityManager.performAndWait {
            guard let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessage
            else {
                throw MessageSenderError.unableToLoadMessage
            }

            let messageID = baseMessage.id
            var receiverIdentity: ThreemaIdentity?
            let group = self.groupManager.getGroup(conversation: baseMessage.conversation)
            if group == nil {
                receiverIdentity = baseMessage.conversation.contact?.threemaIdentity
            }
            return (messageID, receiverIdentity, group)
        }
    }

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
                        var localContinuation: CheckedContinuation<Void, Never>? = continuation

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

                                // TODO: (IOS-4471) Check crashes are gone with this change
                                assert(localContinuation != nil)
                                localContinuation?.resume()
                                localContinuation = nil
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
                        var localContinuation: CheckedContinuation<Void, Never>? = continuation

                        var receiptMessageIDs = [Data]()
                        var receiptReadDates = [Date?]()

                        for key in keys {
                            receiptMessageIDs.append(key)
                            receiptReadDates.append(msgIDAndReadDate[key] as? Date)
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

                                // TODO: (IOS-4471) Check crashes are gone with this change
                                assert(localContinuation != nil)
                                localContinuation?.resume()
                                localContinuation = nil
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
        guard receiptType == .ack || receiptType == .decline else {
            return
        }

        await entityManager.performSave {
            guard message.deletedAt == nil else {
                return
            }
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
        guard groupReceiptType == .acknowledged || groupReceiptType == .declined else {
            return
        }
        
        await entityManager.performSave {
            guard message.deletedAt == nil else {
                return
            }
            
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
