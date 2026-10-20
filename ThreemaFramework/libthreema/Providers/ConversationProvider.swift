import CocoaLumberjackSwift
import Foundation
import libthreemaSwift
import ThreemaEssentials

final class ConversationProvider: libthreemaSwift.ConversationProvider {

    enum ConversationProviderError: Error {
        case ballotIsMissing
        case contactIsMissing
        case conversationIsMissing
        case invalidDate
        case messageSenderIsMissing
        case reactionCreatorIsMissing
    }

    enum MessageStateError: Error {
        case unknownMessageEntityType
    }

    private let userIdentity: ThreemaIdentity
    private nonisolated(unsafe) let entityManager: EntityManager

    init(
        userIdentity: ThreemaIdentity,
        entityManager: EntityManager
    ) {
        self.userIdentity = userIdentity
        self.entityManager = entityManager
    }

    func addMessages(messages: [libthreemaSwift.MessageState]) throws {
        do {
            try entityManager.performAndWait {
                // 1. For each message of messages:
                // 2. Add each message of messages to the referred conversation³.
                for message in messages {
                    // swiftformat:disable:next acronyms
                    guard let conversationEntity = try self.conversation(for: message.conversationId) else {
                        continue
                    }

                    // 4. If message.message_id is already present in the referred conversation (i.e. the message has
                    // already been added at some point), return ProviderError::InvalidState.²
                    guard self.entityManager.entityFetcher.message(
                        // swiftformat:disable:next acronyms
                        with: message.messageId.littleEndianData,
                        in: conversationEntity
                    ) == nil else {
                        throw ProviderError.ContractViolation("Message already in the conversation")
                    }

                    guard let baseMessageEntity = try self.addMessage(for: message.body, in: conversationEntity) else {
                        continue
                    }

                    // swiftformat:disable:next acronyms
                    baseMessageEntity.id = message.messageId.littleEndianData
                    baseMessageEntity.read = NSNumber(booleanLiteral: message.readAt != nil)
                    baseMessageEntity.readDate = message.readAt?.date

                    switch message.direction {
                    case let .incoming(incomingMessageDirection):
                        baseMessageEntity.isOwn = NSNumber(booleanLiteral: false)
                        // Create at comes always from the sender
                        baseMessageEntity.remoteSentDate = message.createdAt.date
                        baseMessageEntity.date = incomingMessageDirection.receivedAt != 0 ? incomingMessageDirection.receivedAt.date : message.createdAt.date

                        guard let contactEntity = self.entityManager.entityFetcher.contactEntity(
                            for: message.creatorIdentity
                        ) else {
                            throw ProviderError.ContractViolation(
                                "The sender \(message.creatorIdentity) of the message not found"
                            )
                        }
                        baseMessageEntity.sender = contactEntity
                    case let .outgoing(outgoingMessageDirection):
                        baseMessageEntity.isOwn = NSNumber(booleanLiteral: true)
                        baseMessageEntity.sent = NSNumber(booleanLiteral: outgoingMessageDirection.sentAt != nil)
                        baseMessageEntity.remoteSentDate = outgoingMessageDirection.sentAt?.date
                        baseMessageEntity.date = message.createdAt.date
                        baseMessageEntity.delivered = NSNumber(
                            booleanLiteral: outgoingMessageDirection.deliveredAt != nil
                        )
                        baseMessageEntity.deliveryDate = outgoingMessageDirection.deliveredAt?.date
                    }

                    if message.starMarker == .star {
                        let messageMarkersEntity = self.entityManager.entityCreator.messageMarkersEntity()
                        messageMarkersEntity.star = NSNumber(booleanLiteral: true)
                        baseMessageEntity.messageMarkers = messageMarkersEntity
                    }

                    for reaction in message.reactions {
                        var reactionCreator: ContactEntity?
                        if reaction.creatorIdentity != self.userIdentity.rawValue {
                            guard let contactEntity = self.entityManager.entityFetcher.contactEntity(
                                for: reaction.creatorIdentity
                            ) else {
                                throw ProviderError.ContractViolation(
                                    "The creator \(message.creatorIdentity) of the reaction not found"
                                )
                            }
                            reactionCreator = contactEntity
                        }

                        let messageReactionEntity = self.entityManager.entityCreator.messageReactionEntity(
                            reaction: reaction.emoji.codepoint,
                            message: baseMessageEntity
                        )
                        guard let reactionCreatedAt = reaction.createdAt.date else {
                            throw ConversationProviderError.invalidDate
                        }
                        messageReactionEntity.date = reactionCreatedAt
                        messageReactionEntity.creator = reactionCreator
                    }
                }
            }

            try entityManager.save()
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func setTypingIndicator(senderIdentity: LibthreemaThreemaID, isTyping: Bool) throws {
        do {
            try entityManager.performAndWaitSave {
                guard let conversationEntity = try self.conversation(for: .contact(senderIdentity)) else {
                    throw ProviderError.ContractViolation("Contact not found")
                }

                conversationEntity.typing = NSNumber(booleanLiteral: isTyping)
            }
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    func updateMessages(updates: [libthreemaSwift.MessageStateUpdate]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func getManyMessages(conversationType: libthreemaSwift.ConversationType, batchIndex: UInt64) throws -> [
        libthreemaSwift.MessageState
    ] {
        let batchSize = 2 << 10
        let offset: Int = batchSize * Int(batchIndex)

        return try entityManager.performAndWait {
            let baseMessageEntities: [BaseMessageEntity]? =
                switch conversationType {
                case .contact:
                    try self.entityManager.entityFetcher.fetchEntities(
                        entityName: "Message",
                        predicate: .baseMessageIsOneToOne,
                        offset: offset,
                        limit: batchSize
                    )

                case .distributionList:
                    // Not implemented yet
                    []

                case .group:
                    try self.entityManager.entityFetcher.fetchEntities(
                        entityName: "Message",
                        predicate: .baseMessageIsGroup,
                        offset: offset,
                        limit: batchSize
                    )
                }

            var messages = [libthreemaSwift.MessageState]()

            if let baseMessageEntities {
                for baseMessageEntity in baseMessageEntities {
                    guard let messageState = try self.messageState(for: baseMessageEntity) else {
                        continue
                    }

                    messages.append(messageState)
                }
            }

            return messages
        }
    }

    // swiftformat:disable:next acronyms
    func getMessagesMetadata(conversationId: LibthreemaConversationID, messageIds: [LibthreemaMessageID]) throws -> [
        libthreemaSwift.MessageStateMetadata
    ] {
        []
    }

    // swiftformat:disable:next acronyms
    func isMessageMarkedUsed(senderIdentity: LibthreemaThreemaID, messageId: LibthreemaMessageID) throws -> Bool {
        guard let conversationEntity = entityManager.entityFetcher.conversationEntity(for: senderIdentity)
        else {
            return false
        }

        // swiftformat:disable:next acronyms
        return entityManager.entityFetcher.message(with: messageId.littleEndianData, in: conversationEntity) != nil
    }

    // MARK: Private functions

    // MARK: Get message state

    private func messageState(for baseMessageEntity: BaseMessageEntity) throws -> MessageState? {

        var creatorIdentity: LibthreemaThreemaID

        guard let createdAt = baseMessageEntity.date else {
            throw MappingError.messageCreatedAtMissing
        }

        if baseMessageEntity.isOwnMessage {
            creatorIdentity = LibthreemaThreemaID(threemaIdentity: userIdentity)
        }
        else {
            guard let contact = baseMessageEntity.sender ?? baseMessageEntity.conversation.contact else {
                throw ConversationProviderError.messageSenderIsMissing
            }
            creatorIdentity = contact.identity
        }

        guard let body = try messageBodyState(for: baseMessageEntity) else {
            return nil
        }

        return try MessageState(
            // swiftformat:disable:next acronyms
            conversationId: LibthreemaConversationID(
                conversationEntity: baseMessageEntity.conversation,
                entityManager: entityManager,
                userIdentity: userIdentity
            ),
            creatorIdentity: creatorIdentity,
            // swiftformat:disable:next acronyms
            messageId: baseMessageEntity.id.littleEndian(),
            createdAt: createdAt.millisecondsSince1970,
            direction: baseMessageEntity.isOwnMessage ?
                .outgoing(OutgoingMessageDirection(
                    sentAt: baseMessageEntity.remoteSentDate?.millisecondsSince1970,
                    deliveredAt: baseMessageEntity.deliveryDate?.millisecondsSince1970
                )) :
                .incoming(IncomingMessageDirection(
                    receivedAt: createdAt.millisecondsSince1970,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default) // TODO: Implement overrides!
                )),
            readAt: baseMessageEntity.readDate?.millisecondsSince1970,
            starMarker: MessageStarMarker(baseMessageEntity: baseMessageEntity),
            reactions: messageReactions(for: baseMessageEntity),
            body: body
        )
    }

    private func messageBodyState(for baseMessageEntity: BaseMessageEntity) throws -> MessageStateBody? {
        if baseMessageEntity.deletedAt != nil {
            return try .deleted(DeletedMessageState(baseMessageEntity: baseMessageEntity))
        }

        if baseMessageEntity is AudioMessageEntity {
            DDLogWarn("Audio message in data backup is not supported yet")
            return nil
        }
        else if let ballotMessageEntity = baseMessageEntity as? BallotMessageEntity {
            guard let ballotState = ballotMessageEntity.ballotState, let pollID: UInt64 = try ballotMessageEntity.ballot?.id.littleEndian(
            ) else {
                return nil
            }

            if ballotState.intValue == BallotEntity.BallotState.open.rawValue {
                return .pollOpen(PollOpen(id: pollID))
            }
            else if ballotState.intValue == BallotEntity.BallotState.closed.rawValue {
                return .pollClose(PollClose(id: pollID))
            }
            else {
                return nil
            }
        }
        else if baseMessageEntity is FileMessageEntity {
            DDLogWarn("File message in data backup is not supported yet")
            return nil
        }
        else if baseMessageEntity is ImageMessageEntity {
            DDLogWarn("Image message in data backup is not supported yet")
            return nil
        }
        else if let locationMessageEntity = baseMessageEntity as? LocationMessageEntity {
            return .location(LocationMessageState(locationMessageEntity: locationMessageEntity))
        }
        else if baseMessageEntity is SystemMessageEntity {
            DDLogWarn("System message in data backup is not supported yet")
            return nil
        }
        else if let textMessageEntity = baseMessageEntity as? TextMessageEntity {
            return try .text(TextMessageState(textMessageEntity: textMessageEntity))
        }
        else if baseMessageEntity is VideoMessageEntity {
            DDLogWarn("Video message in data backup is not supported yet")
            return nil
        }
        else {
            throw MessageStateError.unknownMessageEntityType
        }
    }

    private func messageReactions(for baseMessageEntity: BaseMessageEntity) throws -> [LibthreemaMessageReaction] {
        if let reactions = baseMessageEntity.reactions {
            try reactions.filter { $0.emoji != nil }
                .map { try LibthreemaMessageReaction(messageReactionEntity: $0, userIdentity: userIdentity) }
        }
        else {
            []
        }
    }

    // MARK: Add message state

    private func addMessage(for messageStateBody: MessageStateBody, in conversationEntity: ConversationEntity) throws -> BaseMessageEntity? {
        switch messageStateBody {
        case let .deleted(messageStateBodyType):
            let deletedMessage =
                switch messageStateBodyType.previousMessageType {
                case .deleted:
                    addDeletedTextMessage(in: conversationEntity)
                case .location:
                    addDeletedLocationMessage(in: conversationEntity)
                case .pollClose, .pollOpen:
                    addDeletedBallotMessage(in: conversationEntity)
                case .text:
                    addDeletedTextMessage(in: conversationEntity)
                }
            deletedMessage.deletedAt = messageStateBodyType.deletedAt.date
            return deletedMessage
        case let .location(locationMessageState):
            return try addLocationMessage(for: locationMessageState, in: conversationEntity)
        case let .pollClose(pollClose):
            return try addBallotMessage(id: pollClose.id.littleEndianData, state: .closed, in: conversationEntity)
        case let .pollOpen(pollOpen):
            return try addBallotMessage(id: pollOpen.id.littleEndianData, state: .open, in: conversationEntity)
        case let .text(textMessageState):
            return try addTextMessage(for: textMessageState, in: conversationEntity)
        }
    }

    private func addBallotMessage(id: Data, state: BallotEntity.BallotState, in conversationEntity: ConversationEntity) throws -> BallotMessageEntity? {
        guard let ballotEntity = entityManager.entityFetcher.ballotEntity(for: id) else {
            throw ConversationProviderError.ballotIsMissing
        }

        let ballotMessageEntity = entityManager.entityCreator.ballotMessageEntity(in: conversationEntity)
        ballotMessageEntity.ballot = ballotEntity
        ballotMessageEntity.ballotState = NSNumber(integerLiteral: state.rawValue)

        return ballotMessageEntity
    }

    private func addDeletedBallotMessage(in conversationEntity: ConversationEntity) -> BallotMessageEntity {
        let ballotMessageEntity = entityManager.entityCreator.ballotMessageEntity(in: conversationEntity)
        ballotMessageEntity.deletedAt = .now
        return ballotMessageEntity
    }

    private func addDeletedLocationMessage(in conversationEntity: ConversationEntity) -> LocationMessageEntity {
        let locationMessageEntity = entityManager.entityCreator.locationMessageEntity(
            latitude: 0,
            longitude: 0,
            in: conversationEntity
        )
        locationMessageEntity.deletedAt = .now
        return locationMessageEntity
    }

    private func addDeletedTextMessage(in conversationEntity: ConversationEntity) -> TextMessageEntity {
        let textMessageEntity = entityManager.entityCreator.textMessageEntity(
            text: String.empty,
            in: conversationEntity,
            setLastUpdate: false
        )
        return textMessageEntity
    }

    private func addLocationMessage(
        for locationMessageState: LocationMessageState,
        in conversationEntity: ConversationEntity
    ) throws -> LocationMessageEntity? {
        let locationMessageEntity = entityManager.entityCreator.locationMessageEntity(
            latitude: locationMessageState.latitude,
            longitude: locationMessageState.longitude,
            accuracy: locationMessageState.accuracyM,
            in: conversationEntity
        )

        locationMessageEntity.poiName = locationMessageState.name
        locationMessageEntity.poiAddress = locationMessageState.address

        return locationMessageEntity
    }

    private func addTextMessage(for textMessageState: TextMessageState, in conversationEntity: ConversationEntity) throws -> TextMessageEntity? {
        if let lastRevision = textMessageState.revisions.last {
            // Create current text message from last revision
            let textMessageEntity = entityManager.entityCreator.textMessageEntity(
                text: lastRevision.message.text,
                in: conversationEntity,
                setLastUpdate: false
            )
            textMessageEntity.lastEditedAt = lastRevision.createdAt.date

            // Add original as history entry
            let historyEntry = entityManager.entityCreator.messageHistoryEntryEntity(for: textMessageEntity)
            guard let editDate = textMessageState.revisions.first?.createdAt.date else {
                throw ConversationProviderError.invalidDate
            }
            historyEntry.editDate = editDate
            historyEntry.text = textMessageState.original.text

            // Add all other history entries
            for revision in textMessageState.revisions where revision != lastRevision {
                let historyEntry = entityManager.entityCreator.messageHistoryEntryEntity(for: textMessageEntity)
                guard let editDate = revision.createdAt.date else {
                    throw ConversationProviderError.invalidDate
                }
                historyEntry.editDate = editDate
                historyEntry.text = revision.message.text
            }

            return textMessageEntity
        }
        else {
            let textMessageEntity = entityManager.entityCreator.textMessageEntity(
                text: textMessageState.original.text,
                in: conversationEntity,
                setLastUpdate: false
            )

            return textMessageEntity
        }
    }

    private func conversation(for conversationID: LibthreemaConversationID) throws -> ConversationEntity? {
        switch conversationID {
        case let .contact(identity):
            // 1. If message refers to a 1:1 contact conversation:
            //   1. Look up the referred contact and let contact be the result.¹
            //   2. If contact is not defined, return ProviderError::InvalidState.
            guard let contactEntity = entityManager.entityFetcher.contactEntity(for: identity) else {
                throw ProviderError.ContractViolation("Contact not found")
            }

            // 3. If contact does not have acquaintance level direct, return ProviderError::InvalidState.
            guard !contactEntity.isHidden else {
                throw ProviderError.ContractViolation("Contact must have acquaintance level direct")
            }

            if let conversationEntity = entityManager.entityFetcher.conversationEntity(for: contactEntity.identity) {
                return conversationEntity
            }
            else {
                let conversationEntity = entityManager.entityCreator.conversationEntity()
                conversationEntity.contact = contactEntity
                return conversationEntity
            }

        case .distributionList:
            // 2. If message refers to a distribution list conversation and the referred distribution list does not
            // exist, return ProviderError::InvalidState.
            // Distribution list are not supported in iOS
            return nil

        case let .group(identity):
            // 3. If message refers to a group conversation and the referred group does not exist, return
            // ProviderError::InvalidState.
            guard let groupEntity = entityManager.entityFetcher.groupEntity(
                for: GroupIdentity(libthreemaGroupIdentity: identity),
                myIdentity: userIdentity.rawValue
            ),
                let conversationEntity = entityManager.entityFetcher.conversationEntity(
                    for: GroupIdentity(
                        id: groupEntity.groupID,
                        creator: ThreemaIdentity(groupEntity.groupCreator ?? userIdentity.rawValue)
                    ),
                    myIdentity: userIdentity.rawValue
                ) else {
                throw ProviderError.ContractViolation("Group not found")
            }

            return conversationEntity
        }
    }
}
