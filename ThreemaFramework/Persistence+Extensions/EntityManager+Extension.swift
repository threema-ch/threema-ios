import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaProtocols

// MARK: Convenience functions to accessing multiple contexts (current and main)

extension EntityManager {
    enum EntityManagerError: Error {
        case incomingMessageSenderMyself, missingSender, missingConversation, wrongBaseMessageType,
             unknownAbstractMessage, insertContactEntityFailed
    }

    @objc public func conversation(
        forContact contactEntity: ContactEntity,
        createIfNotExisting: Bool
    ) -> ConversationEntity? {
        conversation(forContact: contactEntity, createIfNotExisting: createIfNotExisting, setLastUpdate: true)
    }

    public func conversation(
        forContact contactEntity: ContactEntity,
        createIfNotExisting: Bool,
        setLastUpdate: Bool = true,
        keepContactHidden: Bool = false
    ) -> ConversationEntity? {
        let conversation = entityFetcher.conversationEntity(for: contactEntity.identity)

        if createIfNotExisting, conversation == nil {
            let conversation = entityCreator.conversationEntity(setLastUpdate: setLastUpdate)
            conversation.contact = contactEntity

            if contactEntity.showOtherThreemaTypeIcon {
                // Add work info as first message
                let systemMessage = entityCreator.systemMessageEntity(
                    for: .contactOtherAppInfo,
                    in: conversation
                )
                systemMessage.remoteSentDate = Date()
            }
            return conversation
        }
        else if createIfNotExisting, conversation == nil {
            DDLogError("Create conversation failed")
        }

        // Check if the contact still needs to be hidden
        if !keepContactHidden,
           contactEntity.isHidden {
            contactEntity.isHidden = false

            let mediatorSyncableContacts = MediatorSyncableContacts()
            mediatorSyncableContacts.updateAcquaintanceLevel(
                identity: contactEntity.identity,
                value: NSNumber(integerLiteral: ContactAcquaintanceLevel.direct.rawValue)
            )
            mediatorSyncableContacts.syncAsync()
        }

        return conversation
    }

    @objc public func conversation(for identity: String, createIfNotExisting: Bool) -> ConversationEntity? {
        conversation(for: identity, createIfNotExisting: createIfNotExisting, setLastUpdate: true)
    }

    public func conversation(
        for identity: String,
        createIfNotExisting: Bool,
        setLastUpdate: Bool = true,
        keepContactHidden: Bool = false
    ) -> ConversationEntity? {
        guard let contact = entityFetcher.contactEntity(for: identity) else {
            return nil
        }
        return conversation(
            forContact: contact,
            createIfNotExisting: createIfNotExisting,
            setLastUpdate: setLastUpdate,
            keepContactHidden: keepContactHidden
        )
    }

    func conversation(forMessage message: AbstractMessage, myIdentity: String?) -> ConversationEntity? {
        if let groupMessage = message as? AbstractGroupMessage {
            groupConversation(forMessage: groupMessage, fetcher: entityFetcher, myIdentity: myIdentity)
        }
        else {
            oneToOneConversation(forMessage: message, fetcher: entityFetcher, myIdentity: myIdentity)
        }
    }

    /// Looking for existing contact entity (sender) and conversation in current and in main DB context.
    ///
    /// - Parameter abstractMessage: Get sender and conversation from DB for that message
    /// - Returns: Conversation if is exists
    ///     Outgoing:
    ///         - Sender is nil because its me
    ///         - Receiver of one to one conversation otherwise nil
    ///     Incoming:
    ///         - Sender of the message
    ///         - Receiver is nil because its me
    func existingConversationSenderReceiver(for abstractMessage: AbstractMessage, myIdentity: String?)
        -> (conversation: ConversationEntity?, sender: ContactEntity?, receiver: ContactEntity?) {

        // Get DB objects Conversation and ContactEntity from particular entity fetcher
        func conversationSenderReceiver(fetcher: EntityFetcher, myIdentity: String?)
            -> (conversation: ConversationEntity?, sender: ContactEntity?, receiver: ContactEntity?) {
            var sender: ContactEntity?
            var receiver: ContactEntity?
            var conversation: ConversationEntity?

            if let groupMessage = abstractMessage as? AbstractGroupMessage {
                conversation = groupConversation(forMessage: groupMessage, fetcher: fetcher, myIdentity: myIdentity)

                // From identity it's me if the message is a reflected outgoing message
                if abstractMessage.fromIdentity != myIdentity {
                    sender = fetcher.contactEntity(for: abstractMessage.fromIdentity)
                }

                assert(receiver == nil, "Receiver is always nil for group messages")
            }
            else {
                conversation = oneToOneConversation(
                    forMessage: abstractMessage,
                    fetcher: fetcher,
                    myIdentity: myIdentity
                )

                if let conversation {
                    // From identity it's me if the message is a reflected outgoing message
                    if abstractMessage.fromIdentity != myIdentity {
                        sender = conversation.contact
                    }
                    else {
                        receiver = conversation.contact
                    }
                }
                else {
                    if abstractMessage.fromIdentity != myIdentity {
                        sender = fetcher.contactEntity(for: abstractMessage.fromIdentity)
                    }
                    else {
                        receiver = fetcher.contactEntity(for: abstractMessage.toIdentity)
                    }
                }

                assert(
                    (sender != nil && receiver == nil) || (sender == nil && receiver != nil),
                    "Sender or receiver have to be set, but never both (because I'm one of them)"
                )
            }

            return (conversation, sender, receiver)
        }

        var result = dbContext.current.performAndWait {
            conversationSenderReceiver(fetcher: entityFetcher, myIdentity: myIdentity)
        }

        if result.conversation == nil, result.sender == nil, result.receiver == nil, !isMainDBContext {
            DDLogWarn("Looking for contact entity and conversation on main DB context")
            var resultObjectIDs: (
                conversationObjectID: NSManagedObjectID?,
                senderObjectID: NSManagedObjectID?,
                receiverObjectID: NSManagedObjectID?
            )
            dbContext.main.performAndWait {
                let resultObject =
                    conversationSenderReceiver(fetcher: EntityFetcher(
                        managedObjectContext: dbContext.main
                    ), myIdentity: myIdentity)
                resultObjectIDs = (
                    resultObject.conversation?.objectID,
                    resultObject.sender?.objectID,
                    resultObject.receiver?.objectID
                )
            }

            // Apply contact entity and conversation to current DB context
            if let conversationObjectID = resultObjectIDs.conversationObjectID {
                result.conversation = dbContext.current.object(with: conversationObjectID) as? ConversationEntity
            }
            if let senderObjectID = resultObjectIDs.senderObjectID {
                result.sender = dbContext.current.object(with: senderObjectID) as? ContactEntity
            }
            if let receiverObjectID = resultObjectIDs.receiverObjectID {
                result.receiver = dbContext.current.object(with: receiverObjectID) as? ContactEntity
            }
        }

        return result
    }

    @objc func existingContact(with identity: String) -> Bool {
        var objectID: NSManagedObjectID?
        dbContext.current.performAndWait {
            guard let contact = entityFetcher.contactEntity(for: identity) else {
                return
            }
            objectID = contact.objectID
        }

        guard objectID == nil else {
            return true
        }

        dbContext.main.performAndWait {
            guard let contact = EntityFetcher(
                managedObjectContext: self.dbContext.main,
            )
            .contactEntity(for: identity)
            else {
                return
            }
            objectID = contact.objectID
        }

        if let objectID {
            dbContext.current.object(with: objectID)
        }

        return objectID != nil
    }

    @available(swift, obsoleted: 1.0, message: "Only use from Objective-C")
    @objc func existingConversationSenderReceiver(
        for abstractMessage: AbstractMessage,
        sender: UnsafeMutablePointer<ContactEntity?>,
        receiver: UnsafeMutablePointer<ContactEntity?>,
        myIdentity: String?
    ) -> ConversationEntity? {
        let result = existingConversationSenderReceiver(for: abstractMessage, myIdentity: myIdentity)
        sender.pointee = result.sender
        receiver.pointee = result.receiver
        return result.conversation
    }

    /// Looking for existing contact in current and in main DB context or insert new contact entity it was not found.
    ///
    /// - Parameters:
    ///   - identity: Threema Identity
    ///   - publicKey: Fetched public key of the identity
    ///   - sortOrderFirstName: User setting
    ///  - Returns: Inserted contact entity
    @objc public func getOrCreateContact(
        identity: String,
        publicKey: Data,
        sortOrderFirstName: Bool
    ) throws -> ContactEntity {

        // Get DB object `ContactEntity` from particular entity fetcher
        func getContactEntity(for identity: String, fetcher: EntityFetcher) -> ContactEntity? {
            fetcher.contactEntity(for: identity)
        }

        return try EntityManager.getOrCreateContactQueue.sync {
            var contactEntity: ContactEntity? = dbContext.current.performAndWait {
                getContactEntity(for: identity, fetcher: self.entityFetcher)
            }

            if contactEntity == nil, !isMainDBContext {
                DDLogNotice("Looking for the contact entity \(identity) on main DB context")
                let objectID = dbContext.main.performAndWait {
                    getContactEntity(
                        for: identity,
                        fetcher: EntityFetcher(
                            managedObjectContext: self.dbContext.main
                        )
                    )?.objectID
                }

                // Apply `ContactEntity` to current DB context
                if let objectID {
                    DDLogNotice("Apply contact entity \(identity) to current DB context")
                    contactEntity = dbContext.current.object(with: objectID) as? ContactEntity
                }
            }

            if let contactEntity {
                DDLogWarn("Creating new contact with identity \(identity) already exists")
                return contactEntity
            }
            else {
                contactEntity = performAndWaitSave {
                    self.entityCreator.contactEntity(
                        identity: identity,
                        publicKey: publicKey,
                        sortOrderFirstName: sortOrderFirstName
                    )
                }

                guard let contactEntity else {
                    throw EntityManagerError.insertContactEntityFailed
                }

                return contactEntity
            }
        }
    }

    /// Looking for existing message in current and in main DB context or creating new message it was not found.
    ///
    /// - Parameters:
    ///   - abstractMessage: Get or create message from DB for that message
    ///   - sender: Is only necessary for group message and I'm not the sender
    ///   - conversation: Search or insert message in this conversation
    ///   - thumbnail: Is needed to create deprecated `VideoMessageEntity`, because thumbnail is not optional
    ///   - onCompletion: Existing or new (unsaved) message from DB
    ///   - onError: ThreemaProtocolError.messageAlreadyProcessed, TaskExecutionError.messageTypeMismatch
    @available(swift, obsoleted: 1.0, message: "Only use from Objective-C")
    @objc func getOrCreateMessage(
        for abstractMessage: AbstractMessage,
        sender: ContactEntity?,
        conversation: ConversationEntity,
        thumbnail: UIImage?,
        myIdentity: String?,
        onCompletion: @escaping (BaseMessageEntity) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        do {
            try onCompletion(
                getOrCreateMessage(
                    for: abstractMessage,
                    sender: sender,
                    conversation: conversation,
                    thumbnail: thumbnail,
                    myIdentity: myIdentity
                )
            )
        }
        catch {
            onError(error)
        }
    }

    /// Looking for existing message in current and in main DB context or creating new message it was not found.
    ///
    /// - Parameters:
    ///   - abstractMessage: Get or create message from DB for that message
    ///   - sender: Is only necessary for group message and I'm not the sender
    ///   - conversation: Search or insert message in this conversation
    ///   - thumbnail: Is needed to create deprecated `VideoMessageEntity`, because thumbnail is not optional
    /// - Returns: Existing or new (unsaved) message from DB
    /// - Throws: ThreemaProtocolError.messageAlreadyProcessed, TaskExecutionError.messageTypeMismatch
    func getOrCreateMessage(
        for abstractMessage: AbstractMessage,
        sender: ContactEntity?,
        conversation: ConversationEntity,
        thumbnail: UIImage?,
        myIdentity: String?
    ) throws -> BaseMessageEntity {
        assert(abstractMessage.fromIdentity != nil, "Sender identity is needed to calculating sending direction")

        // Get DB objects BaseMessageEntity from particular entity fetcher
        func getMessage(for conversation: ConversationEntity, fetcher: EntityFetcher) -> BaseMessageEntity? {
            fetcher.message(with: abstractMessage.messageID, in: conversation)
        }

        return try EntityManager.getOrCreateMessageQueue.sync {
            var message: BaseMessageEntity?

            try dbContext.current.performAndWait {
                message = getMessage(for: conversation, fetcher: entityFetcher)
                guard !(message?.delivered.boolValue ?? false) else {
                    DDLogWarn("Message ID \(abstractMessage.messageID.hexString) already processed")
                    throw ThreemaProtocolError.messageAlreadyProcessed
                }
            }

            if message == nil, !isMainDBContext {
                DDLogNotice("Looking for the message \(abstractMessage.messageID.hexString) on main DB context")
                var messageObjectID: NSManagedObjectID?
                dbContext.main.performAndWait {
                    messageObjectID = getMessage(
                        for: conversation,
                        fetcher: EntityFetcher(
                            managedObjectContext: self.dbContext.main
                        )
                    )?.objectID
                }

                // Apply message to current DB context
                if let messageObjectID {
                    DDLogNotice("Apply message \(abstractMessage.messageID.hexString) to current DB context")
                    message = dbContext.current.object(with: messageObjectID) as? BaseMessageEntity
                    guard !(message?.delivered.boolValue ?? false) else {
                        DDLogWarn("Message ID \(abstractMessage.messageID.hexString) already processed")
                        throw ThreemaProtocolError.messageAlreadyProcessed
                    }
                }
            }

            if let message {
                // Validate type of existing message
                if abstractMessage is BoxAudioMessage || abstractMessage is GroupAudioMessage {
                    guard message is AudioMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxBallotCreateMessage || abstractMessage is GroupBallotCreateMessage {
                    guard message is BallotMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxFileMessage || abstractMessage is GroupFileMessage {
                    guard message is FileMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxImageMessage || abstractMessage is GroupImageMessage {
                    guard message is ImageMessage else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxLocationMessage || abstractMessage is GroupLocationMessage {
                    guard message is LocationMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxTextMessage || abstractMessage is GroupTextMessage {
                    guard message is TextMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxVideoMessage || abstractMessage is GroupVideoMessage {
                    guard message is VideoMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
            }
            else {
                // Create new message and save it to DB (without applying sender and conversation)
                try performAndWaitSave {
                    if let amsg = abstractMessage as? BoxAudioMessage {
                        message = self.entityCreator.audioMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxBallotCreateMessage {
                        message = self.entityCreator.ballotMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxFileMessage {
                        message = self.entityCreator.fileMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxImageMessage {
                        message = self.entityCreator.imageMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxLocationMessage {
                        message = self.entityCreator.locationMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxTextMessage {
                        message = self.entityCreator.textMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? BoxVideoMessage {
                        message = self.entityCreator.videoMessageEntity(from: amsg, in: conversation)
                    }
                    else if let amsg = abstractMessage as? GroupAudioMessage {
                        message = self.entityCreator.audioMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupBallotCreateMessage {
                        message = self.entityCreator.ballotMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupFileMessage {
                        message = self.entityCreator.fileMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupImageMessage {
                        message = self.entityCreator.imageMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupLocationMessage {
                        message = self.entityCreator.locationMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupTextMessage {
                        message = self.entityCreator.textMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupVideoMessage {
                        message = self.entityCreator.videoMessageEntity(from: amsg, in: conversation)
                        message?.sender = sender
                    }

                    if message is VideoMessageEntity {
                        if let thumbnail,
                           let data = thumbnail.jpegData(compressionQuality: kJPEGCompressionQualityLow) {
                            let imageData = self.entityCreator.imageDataEntity(data: data, size: thumbnail.size)

                            (message as? VideoMessageEntity)?.thumbnail = imageData
                        }
                        else {
                            fatalError("Create video message failed, because of missing thumbnail")
                        }
                    }

                    guard let message else {
                        DDLogWarn("Unknown message type (ID: \(abstractMessage.messageID.hexString))")
                        throw ThreemaProtocolError.unknownMessageType
                    }

                    let isOutgoingMessage = abstractMessage.fromIdentity == myIdentity
                    message.isOwn = NSNumber(booleanLiteral: isOutgoingMessage)

                    // Do not remove this assignments, otherwise the observers of the message
                    // properties are not called
                    message.conversation = conversation
                    conversation.lastMessage = message
                    conversation.lastUpdate = abstractMessage.date ?? .now
                }
            }

            return message!
        }
    }

    /// Get a list of `NSManagedObjectID` of related reactions and message history entries to the message
    /// that will be deleted.
    ///
    /// - Parameters:
    ///   - abstractDeleteMessage: Abstract delete message `DeleteMessage` or `DeleteGroupMessage`
    ///   - conversation: Conversation entity of the message that will be deleted
    /// - Returns: List with `NSManagedObjectID` of `MessageReaction` or `MessageHistoryEntry`
    @objc func relatedObjectIDsForAbstractDeleteMessage(
        _ abstractDeleteMessage: AbstractMessage,
        in conversation: ConversationEntity
    ) -> Set<NSManagedObjectID>? {
        var messageID: UInt64

        if let id = (abstractDeleteMessage as? DeleteMessage)?.decoded?.messageID {
            messageID = id
        }
        else if let id = (abstractDeleteMessage as? DeleteGroupMessage)?.decoded?.messageID {
            messageID = id
        }
        else {
            let errorMessage =
                "Abstract message \(abstractDeleteMessage.messageID.hexString) it's not an delete message"
            assertionFailure(errorMessage)
            DDLogWarn("\(errorMessage)")
            return nil
        }

        return relatedObjectIDs(for: messageID, in: conversation)
    }

    private func relatedObjectIDs(
        for messageID: UInt64,
        in conversation: ConversationEntity
    ) -> Set<NSManagedObjectID> {
        var relatedObjectIDs = Set<NSManagedObjectID>()

        return performAndWait {
            guard let message = self.entityFetcher.message(
                with: messageID.littleEndianData,
                in: conversation
            ) else {
                return relatedObjectIDs
            }

            if let historyEntries = message.historyEntries {
                for entry in historyEntries {
                    relatedObjectIDs.insert(entry.objectID)
                }
            }

            if let reactions = message.reactions {
                for reaction in reactions {
                    relatedObjectIDs.insert(reaction.objectID)
                }
            }

            return relatedObjectIDs
        }
    }

    @available(swift, obsoleted: 1.0, message: "Only use from Objective-C")
    @objc func deleteMessage(
        for abstractMessage: AbstractMessage,
        conversation: ConversationEntity,
        myIdentity: String?,
        onError: @escaping (Error) -> Void
    ) -> BaseMessageEntity? {
        do {
            return try deleteMessage(for: abstractMessage, conversation: conversation, myIdentity: myIdentity)
        }
        catch {
            onError(error)
        }
        return nil
    }

    func deleteMessage(
        for abstractMessage: AbstractMessage,
        conversation: ConversationEntity,
        myIdentity: String?,
    ) throws -> BaseMessageEntity {
        var e2eDeleteMessage: CspE2e_DeleteMessage

        if let decodedMessage = (abstractMessage as? DeleteMessage)?.decoded {
            e2eDeleteMessage = decodedMessage
        }
        else if let decodedMessage = (abstractMessage as? DeleteGroupMessage)?.decoded {
            e2eDeleteMessage = decodedMessage
        }
        else {
            DDLogError("Abstract message \(abstractMessage.messageID.hexString) it's not an delete message")
            throw ThreemaProtocolError.messageToDeleteNotFound
        }

        return try performAndWaitSave {
            guard let message = self.entityFetcher.message(
                with: e2eDeleteMessage.messageID.littleEndianData,
                in: conversation
            ) else {
                DDLogWarn("Message \(e2eDeleteMessage.messageID.littleEndianData.hexString) to delete not found")
                throw ThreemaProtocolError.messageToDeleteNotFound
            }

            if abstractMessage.fromIdentity != myIdentity {
                // If sender nil, then its a reflected outgoing message
                if let sender = message.sender ?? conversation.contact {
                    guard sender.identity == abstractMessage.fromIdentity else {
                        DDLogWarn("Message \(message.id.hexString) can't be deleted because of sender mismatch")
                        throw ThreemaProtocolError.messageSenderMismatch
                    }
                }
            }

            message.deletedAt = abstractMessage.date
            message.lastEditedAt = nil

            // Delete content of this base message
            try self.entityDestroyer.deleteMessageContent(of: message)

            conversation.updateLastDisplayMessage(with: self)

            return message
        }
    }

    @available(swift, obsoleted: 1.0, message: "Only use from Objective-C")
    @objc func editMessage(
        for abstractMessage: AbstractMessage,
        conversation: ConversationEntity,
        myIdentity: String?,
        onError: @escaping (Error) -> Void
    ) -> BaseMessageEntity? {
        do {
            return try editMessage(for: abstractMessage, conversation: conversation, myIdentity: myIdentity)
        }
        catch {
            onError(error)
        }
        return nil
    }

    func editMessage(
        for abstractMessage: AbstractMessage,
        conversation: ConversationEntity,
        myIdentity: String?,
    ) throws -> BaseMessageEntity {
        var e2eEditMessage: CspE2e_EditMessage

        if let decodedMessage = (abstractMessage as? EditMessage)?.decoded {
            e2eEditMessage = decodedMessage
        }
        else if let decodedMessage = (abstractMessage as? EditGroupMessage)?.decoded {
            e2eEditMessage = decodedMessage
        }
        else {
            DDLogError("Abstract message \(abstractMessage.messageID.hexString) it's not an edit message")
            throw ThreemaProtocolError.messageToEditNotFound
        }

        return try performAndWaitSave {
            guard let message = self.entityFetcher.message(
                with: e2eEditMessage.messageID.littleEndianData,
                in: conversation
            ) else {
                DDLogWarn("Message \(e2eEditMessage.messageID.littleEndianData.hexString) to edit not found")
                throw ThreemaProtocolError.messageToEditNotFound
            }

            if abstractMessage.fromIdentity != myIdentity {
                // If sender nil, then its a reflected outgoing message
                if let sender = message.sender ?? conversation.contact {
                    guard sender.identity == abstractMessage.fromIdentity else {
                        DDLogWarn("Message \(message.id.hexString) can't be edited because of sender mismatch")
                        throw ThreemaProtocolError.messageSenderMismatch
                    }
                }
            }

            let history = self.entityCreator.messageHistoryEntryEntity(for: message)

            if let textMessage = message as? TextMessageEntity {
                history.text = textMessage.text
                textMessage.text = e2eEditMessage.text
                textMessage.lastEditedAt = abstractMessage.date
            }
            else if let fileMessage = message as? FileMessageEntity {
                history.text = fileMessage.caption
                fileMessage.caption = e2eEditMessage.text
                fileMessage.lastEditedAt = abstractMessage.date
            }
            else {
                DDLogWarn("Received edit for unsupported message type")
                self.entityDestroyer.delete(messageHistoryEntryEntity: history)
            }

            return message
        }
    }

    /// Set delivered and delivery date of incoming message.
    /// - Parameters:
    /// - abstractMessage: Incoming message
    /// - receivedAt: Receive date is reflected at or now if message was not reflected
    public func markMessageAsReceived(
        _ abstractMessage: AbstractMessage,
        receivedAt: Date = .now,
        myIdentity: String?
    ) {

        performAndWaitSave {
            var conversation: ConversationEntity?

            if abstractMessage.flagGroupMessage() {
                guard let groupMessage = abstractMessage as? AbstractGroupMessage else {
                    DDLogError("Could not update message because it is not group message")
                    return
                }
                conversation = self.entityFetcher.conversationEntity(for: GroupIdentity(
                    id: groupMessage.groupID,
                    creator: ThreemaIdentity(groupMessage.groupCreator)
                ), myIdentity: myIdentity)
            }
            else {
                conversation = self.entityFetcher.conversationEntity(for: abstractMessage.fromIdentity)
            }

            guard let conversation else {
                DDLogError("Could not update message because we could not find the conversation")
                return
            }

            guard let msg = self.entityFetcher.message(
                with: abstractMessage.messageID,
                in: conversation
            ) else {
                DDLogWarn(
                    "Could not update message because we could not find the message ID \(abstractMessage.messageID?.hexString ?? "nil")"
                )
                return
            }

            msg.delivered = NSNumber(booleanLiteral: true)
            msg.deliveryDate = receivedAt
        }
    }

    // MARK: - Private functions

    private func groupConversation(
        forMessage message: AbstractGroupMessage,
        fetcher: EntityFetcher,
        myIdentity: String?
    ) -> ConversationEntity? {
        let groupIdentity = GroupIdentity(id: message.groupID, creator: ThreemaIdentity(message.groupCreator))
        return fetcher.conversationEntity(for: groupIdentity, myIdentity: myIdentity)
    }

    private func oneToOneConversation(
        forMessage message: AbstractMessage,
        fetcher: EntityFetcher,
        myIdentity: String?,
    ) -> ConversationEntity? {
        assert(!(message is AbstractGroupMessage))

        var conversation: ConversationEntity?

        if message.toIdentity != myIdentity {
            conversation = fetcher.conversationEntity(for: message.toIdentity)
        }
        else if message.fromIdentity != myIdentity {
            conversation = fetcher.conversationEntity(for: message.fromIdentity)
        }

        // Check if the contact still needs to be hidden
        if let contactEntity = conversation?.contact,
           contactEntity.isHidden {
            contactEntity.isHidden = false

            let mediatorSyncableContacts = MediatorSyncableContacts()
            mediatorSyncableContacts.updateAcquaintanceLevel(
                identity: contactEntity.identity,
                value: NSNumber(integerLiteral: ContactAcquaintanceLevel.direct.rawValue)
            )
            mediatorSyncableContacts.syncAsync()
        }

        return conversation
    }
}
