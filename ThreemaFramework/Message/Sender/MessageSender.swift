//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import ThreemaMacros
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
        blobManager: BlobManagerProtocol,
        blobMessageSender: BlobMessageSender
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.groupManager = groupManager
        self.taskManager = taskManager
        self.entityManager = entityManager
        self.blobManager = blobManager
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
            blobManager: BlobManager.shared,
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
    
    // MARK: - TextMessage

    @discardableResult
    public func sendTextMessage(
        containing text: String,
        in conversation: ConversationEntity,
        sendProfilePicture: Bool = true,
        requestID: String? = nil
    ) async -> [TextMessageEntity] {
        
        // We handle messages sent to a distribution list separately
        if let distributionList = await (
            entityManager.perform {
                self.entityManager.entityFetcher.distributionListEntity(for: conversation)
            }
        ) {
            return await sendDistributionListTextMessage(text: text, to: distributionList)
        }

        let trimmedText = ThreemaUtility.trimCharacters(in: text)
        let textsToSend = ThreemaUtility.trimMessageText(text: trimmedText)
        
        let textMessages = await createTextMessages(
            texts: textsToSend,
            conversation: conversation,
            requestID: requestID,
            setConversationLastUpdate: true
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
    
    private func sendDistributionListTextMessage(
        text: String,
        to distributionList: DistributionListEntity,
        sendProfilePicture: Bool = true,
        requestID: String? = nil
    ) async -> [TextMessageEntity] {
        
        // Add message to distribution list conversation
        let trimmedText = ThreemaUtility.trimCharacters(in: text)
        let textsToSend = ThreemaUtility.trimMessageText(text: trimmedText)
        
        let conversation = await entityManager.perform {
            self.entityManager.entityFetcher.conversationEntity(forDistributionList: distributionList)
        }
        guard let conversation else {
            return []
        }
        
        // TODO: (IOS-4366) How should we display (state, etc.) these messages in the distribution list conversation?
        let distributionListMessages = await createTextMessages(
            texts: textsToSend,
            conversation: conversation,
            requestID: nil,
            setConversationLastUpdate: true
        )
                
        // Send message to all receiving conversations, this is mostly the same code as above for single conversations.
        var distributedMessages = [TextMessageEntity]()
        
        for receivingConversation in receivingConversations(for: distributionList) {
            
            let textMessages = await createTextMessages(
                texts: textsToSend,
                conversation: receivingConversation,
                requestID: requestID,
                setConversationLastUpdate: false,
                distributionListMessages: distributionListMessages
            )
            
            let tasks = await createTasks(
                textMessages: textMessages,
                conversation: receivingConversation,
                sendProfilePicture: sendProfilePicture
            )
            
            await executeSendTextMessageTasks(tasks)
            
            donateInteractionForOutgoingMessage(in: conversation)
            
            distributedMessages.append(contentsOf: textMessages)
        }
        
        return distributedMessages
    }
    
    private func createTextMessages(
        texts: [String],
        conversation: ConversationEntity,
        requestID: String?,
        setConversationLastUpdate: Bool,
        distributionListMessages: [TextMessageEntity]? = nil
    ) async -> [TextMessageEntity] {
        var textMessages = [TextMessageEntity]()
        
        for (index, text) in texts.enumerated() {
            let textMessage: TextMessageEntity? = await entityManager.performSave {
                
                if let messageConversation = self.entityManager.entityFetcher
                    .getManagedObject(by: conversation.objectID) as? ConversationEntity,
                    let message = self.entityManager.entityCreator.textMessageEntity(
                        for: messageConversation,
                        setLastUpdate: setConversationLastUpdate
                    ) {
                    
                    var remainingBody: NSString?
                    if let quoteMessageID = QuoteUtil.parseQuoteV2(fromMessage: text, remainingBody: &remainingBody) {
                        // swiftformat:disable:next acronyms
                        message.quotedMessageId = quoteMessageID
                        message.text = (remainingBody ?? "") as String
                    }
                    else {
                        message.text = text
                    }
                    
                    if let requestID {
                        // swiftformat:disable:next acronyms
                        message.webRequestId = requestID
                    }
                    
                    // Distribution list handling
                    if let distributionListMessages, index <= distributionListMessages.count {
                        message.distributionListMessage = distributionListMessages[index]
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
        textMessages: [TextMessageEntity],
        conversation: ConversationEntity,
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
                subtitle: #localize("notification_sending_failed")
            )
            throw MessageSenderError.noData
        }
        
        // Check if the data is smaller than the max file size
        guard data.count < kMaxFileSize else {
            NotificationPresenterWrapper.shared.present(
                type: .sendingError,
                subtitle: #localize("notification_sending_failed_subtitle_size")
            )
            throw MessageSenderError.tooBig
        }
        
        let em = entityManager
        // Create message
        let messageID = try await em.performSave {
            guard let localConversation = em.entityFetcher.existingObject(
                with: conversationObjectID
            ) as? ConversationEntity else {
                throw MessageSenderError.unableToLoadConversation
            }
            
            let origin: BlobOrigin =
                if localConversation.isGroup,
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
        
        // Fetch it again to get a non temporary objectID
        let fileMessageObjectID = try await em.perform {
            guard let localConversation = em.entityFetcher.existingObject(
                with: conversationObjectID
            ) as? ConversationEntity else {
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

    // MARK: - LocationMessage

    public func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: ConversationEntity
    ) async {
        
        // We handle messages sent to a distribution list separately
        if let distributionList = await (
            entityManager.perform {
                self.entityManager.entityFetcher.distributionListEntity(for: conversation)
            }
        ) {
            await sendDistributionListLocationMessage(
                coordinates: coordinates,
                accuracy: accuracy,
                poiName: poiName,
                poiAddress: poiAddress,
                to: distributionList
            )
            return
        }
        
        let locationMessage = await createLocationMessage(
            conversation: conversation,
            coordinates: coordinates,
            accuracy: accuracy,
            poiName: poiName,
            poiAddress: poiAddress,
            setConversationLastUpdate: true
        )
        
        guard let locationMessage else {
            assertionFailure("Could not create location message.")
            return
        }
        
        let task = await createTask(
            locationMessage: locationMessage,
            conversation: conversation
        )
        
        guard let task else {
            assertionFailure("Could not create task definition.")
            return
        }
        
        await executeSendLocationMessageTask(task)
        
        donateInteractionForOutgoingMessage(in: conversation)
    }
    
    private func sendDistributionListLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        to distributionList: DistributionListEntity,
        sendProfilePicture: Bool = true
    ) async {
        
        let conversation = await entityManager.perform {
            self.entityManager.entityFetcher.conversationEntity(forDistributionList: distributionList)
        }
        guard let conversation else {
            assertionFailure("Could find distribution list.")
            return
        }
        
        // TODO: (IOS-4366) How should we display (state, etc.) these messages in the distribution list conversation?
        let distributionListMessage = await createLocationMessage(
            conversation: conversation,
            coordinates: coordinates,
            accuracy: accuracy,
            poiName: poiName,
            poiAddress: poiAddress,
            setConversationLastUpdate: true
        )
        
        guard let distributionListMessage else {
            return
        }
        
        // Send message to all receiving conversations, this is mostly the same code as above for single conversations.
        for receivingConversation in receivingConversations(for: distributionList) {
            let locationMessage = await createLocationMessage(
                conversation: receivingConversation,
                coordinates: coordinates,
                accuracy: accuracy,
                poiName: poiName,
                poiAddress: poiAddress,
                setConversationLastUpdate: false,
                distributionListMessage: distributionListMessage
            )
            
            guard let locationMessage else {
                assertionFailure("Could not create location message.")
                return
            }
            
            let task = await createTask(
                locationMessage: locationMessage,
                conversation: receivingConversation
            )
            
            guard let task else {
                assertionFailure("Could not create task definition.")
                return
            }
            
            await executeSendLocationMessageTask(task)
            
            donateInteractionForOutgoingMessage(in: conversation)
        }
    }
    
    private func createLocationMessage(
        conversation: ConversationEntity,
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        setConversationLastUpdate: Bool,
        distributionListMessage: LocationMessageEntity? = nil
    ) async -> LocationMessageEntity? {
        await entityManager.performSave {
            if let messageConversation = self.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? ConversationEntity,
                let message = self.entityManager.entityCreator.locationMessageEntity(
                    for: messageConversation,
                    setLastUpdate: setConversationLastUpdate
                ) {
                
                message.latitude = NSNumber(floatLiteral: coordinates.latitude)
                message.longitude = NSNumber(floatLiteral: coordinates.longitude)
                message.accuracy = NSNumber(floatLiteral: accuracy)
                message.poiName = poiName
                message.poiAddress = poiAddress
                
                // Distribution list handling
                if let distributionListMessage {
                    message.distributionListMessage = distributionListMessage
                }
                
                return message
            }
            return nil
        }
    }

    private func createTask(
        locationMessage: LocationMessageEntity,
        conversation: ConversationEntity
    ) async -> TaskDefinitionSendLocationMessage? {
        await entityManager.perform {
            var task: TaskDefinitionSendLocationMessage? = nil
            
            // We replace \n with \\n to conform to specs
            let formattedAddress = locationMessage.poiAddress?.replacingOccurrences(of: "\n", with: "\\n")
            
            if let group = self.groupManager.getGroup(conversation: conversation) {
                self.groupManager.periodicSyncIfNeeded(for: group)
                let receivers = group.members.map(\.identity)
                task = TaskDefinitionSendLocationMessage(
                    poiAddress: formattedAddress,
                    messageID: locationMessage.id,
                    group: group,
                    receivers: receivers
                )
            }
            else if let receiver = locationMessage.conversation.contact?.identity {
                task = TaskDefinitionSendLocationMessage(
                    poiAddress: formattedAddress,
                    messageID: locationMessage.id,
                    receiverIdentity: receiver
                )
            }
            
            return task
        }
    }
    
    private func executeSendLocationMessageTask(_ sendLocationMessageTask: TaskDefinitionSendLocationMessage) async {
        taskManager.add(taskDefinition: sendLocationMessageTask)
    }

    // MARK: - BallotMessage
    
    @objc public func sendBallotMessage(for ballot: BallotEntity) {
        guard BallotMessageEncoder.passesSanityCheck(ballot) else {
            DDLogError("Ballot did not pass sanity check. Do not send.")
            return
        }

        let (messageID, receiverIdentity, group, conversation) = entityManager.performAndWaitSave {
            var messageID: Data?
            var receiverIdentity: ThreemaIdentity?
            var group: Group?
            var conversation: ConversationEntity?

            if let messageBallot = self.entityManager.entityFetcher
                .getManagedObject(by: ballot.objectID) as? BallotEntity,
                let message = self.entityManager.entityCreator
                .ballotMessage(for: messageBallot.conversation) {

                message.updateBallot(ballot)

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

    @objc public func sendBallotVoteMessage(for ballot: BallotEntity) {
        guard BallotMessageEncoder.passesSanityCheck(ballot) else {
            DDLogError("Ballot did not pass sanity check. Do not send.")
            return
        }

        let (ballotID, receiverIdentity, group, conversation) = entityManager.performAndWait {
            let ballotID = ballot.id
            var receiverIdentity: ThreemaIdentity?
            var group: Group?
            var conv: ConversationEntity?
            
            if let conversation = ballot.conversation {
                conv = conversation
                group = self.groupManager.getGroup(conversation: conversation)
                if let group {
                    self.groupManager.periodicSyncIfNeeded(for: group)
                }
                else {
                    receiverIdentity = conversation.contact?.threemaIdentity
                }
            }

            return (ballotID, receiverIdentity, group, conv)
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
                type: isPersistent ? .persistent : .volatile
            )
        ) { _, _ in
            completion?()
        }
    }

    public func sendBaseMessage(with objectID: NSManagedObjectID, to receivers: MessageSenderReceivers) async {
        let isBlobData: Bool? = entityManager.performAndWaitSave {
            guard let baseMessage = self.entityManager.entityFetcher
                .existingObject(with: objectID) as? BaseMessageEntity
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
                guard let baseMessage = self.entityManager.entityFetcher
                    .existingObject(with: objectID) as? BaseMessageEntity
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
                let baseMessage = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessageEntity
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
            guard let baseMessage = self.entityManager.entityFetcher
                .existingObject(with: objectID) as? BaseMessageEntity
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
            guard let baseMessage = self.entityManager.entityFetcher
                .existingObject(with: objectID) as? BaseMessageEntity
            else {
                throw MessageSenderError.unableToLoadMessage
            }
            
            var hasTextChanged = false
            var previousText: String?
            
            // Save edited text
            if let textMessage = baseMessage as? TextMessageEntity,
               textMessage.text != trimmedText {
                
                // Save history
                previousText = textMessage.text
                
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

    // MARK: - Reactions
    
    public func sendReaction(
        to objectID: NSManagedObjectID,
        reaction: EmojiVariant
    ) async throws -> ReactionsManager.ReactionSendingResult {
        
        // The following code intends to map our protocol for the "Reaction" message submitting
        
        // [Protocol Step] 1. Let reaction be the reaction to be applied to or withdrawn from a referred message which
        // must contain a
        // single fully-qualified emoji codepoint sequence that is part of the current Unicode standard.
        
        let (message, messageID, isOwnMessage): (BaseMessageEntity?, Data?, Bool?) = await entityManager.perform {
            guard let message = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessageEntity
            else {
                return (nil, nil, nil)
            }
            return (message, message.id, message.isOwnMessage)
        }
        
        guard let message, let messageID else {
            DDLogError("[Reactions] Message not found.")
            throw ReactionsManager.ReactionError.sendingFailed
        }
        
        let (conversation, conversationIsGroup) = await entityManager.perform {
            let conversation = self.entityManager.entityFetcher
                .existingObject(with: message.conversation.objectID) as? ConversationEntity
            return (conversation, conversation?.isGroup ?? false)
        }
        
        guard let conversation else {
            DDLogError("[Reactions] Conversation not found.")
            throw ReactionsManager.ReactionError.sendingFailed
        }
        
        // [Protocol Step] 2. Run the Legacy Reaction Mapping Steps with reaction and let legacy-reaction be the result.
        let legacyMapping = reaction.base.applyLegacyMapping()
                
        if !conversationIsGroup {
            // Reaction if for message in 1:1 conversation
            
            let contact: Contact? = await entityManager.perform {
                guard let contactEntity = self.entityManager.entityFetcher.contact(for: conversation.contact?.identity)
                else {
                    return nil
                }
                return Contact(contactEntity: contactEntity)
            }
            
            guard let contact else {
                DDLogError("[Reactions] Contact not found.")
                throw ReactionsManager.ReactionError.sendingFailed
            }
            
            let contactSupportsReaction = FeatureMask.check(contact: contact, for: .reactionSupport)
            
            // We cannot react to our own message, if the other side does not support reactions.
            if isOwnMessage ?? false, !contactSupportsReaction {
                return .noAction
            }
            
            // [Protocol Step] 3. If legacy-reaction is not defined and the sender or the receiver does not have
            // REACTION_SUPPORT, log a warning and abort these steps.¹
            if legacyMapping == nil {
                if !contactSupportsReaction {
                    return .noSupportRemoteSingle
                }
            }
            
            // [Protocol Step] 4. Let reacted-at be the current timestamp.
            let reactedAt = Date.now
            
            // Since we do no longer save legacy acks/decs, we create a reaction anyways
            let apply = await entityManager.performSave {
                
                // [Protocol Step]  7. Apply reaction (i.e. apply or withdraw) to the referred message with the
                // reacted-at timestamp.
                // We check if the user has already reacted with the same emoji…
                var messageReactionEntity: MessageReactionEntity?
                
                if let existingReactions = self.entityManager.entityFetcher.messageReactionEntities(
                    forMessage: message,
                    creator: nil
                ), !existingReactions.isEmpty {
                    
                    messageReactionEntity = existingReactions.first {
                        $0.reaction == reaction.rawValue
                    }
                    // … if so, we withdraw it (If the user supports reactions).
                    if let messageReactionEntity {
                        if contactSupportsReaction {
                            self.entityManager.entityDestroyer.delete(reaction: messageReactionEntity)
                        }
                        return false
                    }
                    
                    // If we do apply and the contact does not support reactions, we remove all existing reactions. This
                    // ensures that there cannot be a legacy ack and dec at the same time.
                    if !contactSupportsReaction {
                        for existingReaction in existingReactions {
                            self.entityManager.entityDestroyer.delete(reaction: existingReaction)
                        }
                    }
                }
                
                // … if not, we create a new reaction.
                messageReactionEntity = self.entityManager.entityCreator.messageReactionEntity().then {
                    $0.reaction = reaction.rawValue
                    $0.date = reactedAt
                    $0.message = message
                }
                
                return true
            }
            
            if !contactSupportsReaction, !apply {
                return .noSupportRemoteSingle
            }
            
            // [Protocol Step]  5. If both sender and receiver have REACTION_SUPPORT,…
            if contactSupportsReaction {
                
                // … run the 1:1 Messages Submit Steps with messages set from the following properties:
                var e2eReactionMessage = CspE2e_Reaction()
                e2eReactionMessage.messageID = try messageID.littleEndian()
          
                if apply {
                    e2eReactionMessage.action = .apply(reaction.data)
                }
                else {
                    e2eReactionMessage.action = .withdraw(reaction.data)
                }
                
                let task = TaskDefinitionSendReactionMessage(
                    reaction: e2eReactionMessage,
                    receiverIdentity: contact.identity.string
                )
                
                let (taskWait, _) = taskManager.addWithWait(taskDefinition: task)
                try await taskWait.wait()

                return .success
            }
            
            // [Protocol Step] 6. If the sender or the receiver does not have REACTION_SUPPORT, run the 1:1 Messages
            // Submit Steps with messages set from the following properties:
            else if let legacyMapping {
                switch legacyMapping {
                case .ack:
                    await sendUserAck(for: message, toIdentity: contact.identity)
                case .dec:
                    await sendUserDecline(for: message, toIdentity: contact.identity)
                }
                
                return .success
            }
        }
        else {
            // Reaction is for group
            guard let group = groupManager.getGroup(conversation: conversation) else {
                DDLogError("[Reactions] Group not found.")
                throw ReactionsManager.ReactionError.sendingFailed
            }
            
            guard group.isSelfMember else {
                DDLogError("[Reactions] Not member of group.")
                return .notGroupMemeber
            }
            
            var (hasRemoteSupport, unsupported) = FeatureMask.check(message: message, for: .reactionSupport)
            
            if group.isNoteGroup {
                hasRemoteSupport = true
            }
            
            if legacyMapping == nil {
                // [Protocol Step] 3. If legacy-reaction is not defined:
                // [Protocol Step] 3.1 If the sender does not have REACTION_SUPPORT, log a warning and abort these
                // steps.
                // [Protocol Step] 3.2 If all of the group members do not have REACTION_SUPPORT, log a warning and abort
                // these steps.
                
                if !hasRemoteSupport {
                    DDLogWarn(
                        "Tried to send a Reaction, but it is not supported by any receiver in the group."
                    )
                    return .noSupportRemoteGroup
                }
            }
            
            // [Protocol Step] 4. Let reacted-at be the current timestamp.
            let reactedAt = Date.now
            
            // [Protocol Step] 5. Run the Group Messages Submit Steps with messages set from the following properties:
            let apply = try await entityManager.performSave {
                
                guard let baseMessage = self.entityManager.entityFetcher
                    .existingObject(with: objectID) as? BaseMessageEntity
                else {
                    throw MessageSenderError.unableToLoadMessage
                }
                
                // [Protocol Step] 6. Apply reaction (i.e. apply or withdraw) to the referred message with the
                // reacted-at timestamp.
                // We check if the user has already reacted with the same emoji
                var messageReactionEntity: MessageReactionEntity?
                
                if let existingReactions = self.entityManager.entityFetcher.messageReactionEntities(
                    forMessage: baseMessage,
                    creator: nil
                ), !existingReactions.isEmpty {
                    
                    messageReactionEntity = existingReactions.first {
                        $0.reaction == reaction.rawValue
                    }
                    // … if so, we withdraw it (If the user supports reactions).
                    if let messageReactionEntity {
                        if hasRemoteSupport {
                            self.entityManager.entityDestroyer.delete(reaction: messageReactionEntity)
                        }
                        return false
                    }
                    
                    // If we do apply and no contact does not support reactions, we remove all our own existing
                    // reactions. This ensures that there cannot be a legacy ack and dec at the same time for contacts
                    // that do not support reactions yet.
                    if !hasRemoteSupport {
                        for existingReaction in existingReactions {
                            self.entityManager.entityDestroyer.delete(reaction: existingReaction)
                        }
                    }
                }
           
                // If not, we create a new reaction
                messageReactionEntity = self.entityManager.entityCreator.messageReactionEntity().then {
                    $0.reaction = reaction.rawValue
                    $0.date = reactedAt
                    $0.message = baseMessage
                }
                
                return true
            }
            
            if !hasRemoteSupport, !apply {
                return .noSupportRemoteGroup
            }
            
            var e2eReactionMessage = CspE2e_Reaction()
            e2eReactionMessage.messageID = try messageID.littleEndian()
                
            if apply {
                e2eReactionMessage.action = .apply(reaction.data)
            }
            else {
                e2eReactionMessage.action = .withdraw(reaction.data)
            }
                
            let task = TaskDefinitionSendReactionMessage(
                reaction: e2eReactionMessage,
                group: group
            )
                
            if !unsupported.isEmpty {
                var receivers = Set<String>()
                    
                for member in group.members {
                    let contains = unsupported.contains { $0.identity == member.identity }
                        
                    guard !contains else {
                        continue
                    }
                    receivers.insert(member.identity.string)
                }
                    
                task.receivingGroupMembers = receivers
            }
                
            let (waitTask, _) = taskManager.addWithWait(taskDefinition: task)
            try await waitTask.wait()

            // [Protocol Step] 3.3 If any of the group members do not have REACTION_SUPPORT, notify the user that
            // the
            // affected contacts will not receive the reaction.
            if !unsupported.isEmpty {
                if let legacyMapping {
                    switch legacyMapping {
                    case .ack:
                        await sendUserAck(for: message, toGroup: group, receivers: unsupported)
                    case .dec:
                        await sendUserDecline(for: message, toGroup: group, receivers: unsupported)
                    }
                        
                    return .success
                }
                    
                // Checks for gateway ids in unsupported members
                // If the group is message storing, we always show an alert
                guard !group.isMessageStoringGatewayGroup else {
                    return .partialSupportRemoteGroup
                }
                // Check if unsupported contains non gateway ids
                let unsupportingNonGatewayMembers = unsupported.filter { !$0.hasGatewayID }
                    
                // If so we have unsupporting members
                if !unsupportingNonGatewayMembers.isEmpty {
                    return .partialSupportRemoteGroup
                }
                else {
                    return .success
                }
            }
            else {
                return .success
            }
        }
        
        return .error
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
    public func sendReadReceipt(for messages: [BaseMessageEntity], toIdentity: ThreemaIdentity) async {
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
    public func sendReadReceipt(for messages: [BaseMessageEntity], toGroupIdentity: GroupIdentity) async {
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
            receivers: Array(group.members),
            toGroup: group
        )
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
                type: .dropOnDisconnect
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

    public func doSendReadReceipt(to conversation: ConversationEntity) -> Bool {
        guard !conversation.isGroup else {
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

    @objc public func doSendTypingIndicator(to conversation: ConversationEntity) -> Bool {
        guard !conversation.isGroup else {
            return false
        }

        return doSendTypingIndicator(to: conversation.contact)
    }

    // MARK: - Donate interaction

    func donateInteractionForOutgoingMessage(in conversation: ConversationEntity) {
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

                backgroundEntityManager.performAndWait {
                    guard let conversation = backgroundEntityManager.entityFetcher
                        .existingObject(with: conversationManagedObjectID) as? ConversationEntity else {
                        let msg = "Could not donate interaction because object is not a conversation"
                        DDLogError("\(msg)")
                        assertionFailure(msg)

                        seal(false)
                        return
                    }

                    guard conversation.conversationCategory != .private else {
                        DDLogVerbose("Do not donate for private conversations")
                        seal(false)
                        return
                    }

                    if conversation.isGroup,
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
            guard let baseMessage = self.entityManager.entityFetcher
                .existingObject(with: objectID) as? BaseMessageEntity
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
    
    func sendUserAck(for message: BaseMessageEntity, toIdentity: ThreemaIdentity) async {
        await sendReceipt(for: [message], receiptType: .ack, toIdentity: toIdentity)
    }

    func sendUserAck(for message: BaseMessageEntity, toGroup: Group, receivers: [Contact]) async {
        await sendReceipt(for: [message], receiptType: .ack, receivers: receivers, toGroup: toGroup)
    }

    func sendUserDecline(for message: BaseMessageEntity, toIdentity: ThreemaIdentity) async {
        await sendReceipt(for: [message], receiptType: .decline, toIdentity: toIdentity)
    }

    func sendUserDecline(for message: BaseMessageEntity, toGroup: Group, receivers: [Contact]) async {
        await sendReceipt(for: [message], receiptType: .decline, receivers: receivers, toGroup: toGroup)
    }

    private func sendReceipt(
        for messages: [BaseMessageEntity],
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

                    if message.noDeliveryReceiptFlagSet {
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
        for messages: [BaseMessageEntity],
        receiptType: ReceiptType,
        receivers: [Contact],
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
                        let receiverIdentities = receivers.map(\.identity.string)
                        
                        if !receiptMessageIDs.isEmpty {
                            DDLogVerbose("Sending delivery receipt for message IDs: \(receiptMessageIDs)")

                            let taskSendDeliveryReceipts = TaskDefinitionSendGroupDeliveryReceiptsMessage(
                                group: toGroup,
                                from: self.myIdentityStore.identity,
                                to: receiverIdentities,
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
    
    private func receivingConversations(for distributionList: DistributionListEntity) -> [ConversationEntity] {
        var conversations = [ConversationEntity]()
        entityManager.performAndWait {
            let recipients = distributionList.conversation.unwrappedMembers
            for recipient in recipients {
                if let conversation = self.entityManager.conversation(
                    for: recipient.identity,
                    createIfNotExisting: true
                ) {
                    conversations.append(conversation)
                }
            }
        }
        return conversations
    }
}
