import Foundation
import ThreemaEssentials

public final class EntityCreator: NSObject {
    
    private let managedObjectContext: ThreemaManagedObjectContext
    
    // MARK: - Lifecycle
    
    init(managedObjectContext: ThreemaManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("#function not implemented")
    }
    
    // MARK: - Messages
    
    // MARK: Text message
    
    public func textMessageEntity(
        messageID: Data,
        text: String,
        quotedMessageID: Data?,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversation: ConversationEntity
    ) -> TextMessageEntity {
        let textMessageEntity = TextMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            text: text,
            quotedMessageID: quotedMessageID,
            conversation: conversation
        )
        
        setProperties(of: textMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return textMessageEntity
    }
    
    public func textMessageEntity(
        quotedMessageID: Data? = nil,
        text: String,
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool
    ) -> TextMessageEntity {
        let textMessageEntity = TextMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            text: text,
            quotedMessageID: quotedMessageID,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = textMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return textMessageEntity
    }
    
    // MARK: File message
    
    public func fileMessageEntity(
        messageID: Data,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversationEntity: ConversationEntity
    ) -> FileMessageEntity {
        let fileMessageEntity = FileMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            conversation: conversationEntity
        )
        
        setProperties(of: fileMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)
        
        return fileMessageEntity
    }
    
    @objc public func fileMessageEntity(
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> FileMessageEntity {
        let fileMessageEntity = FileMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = fileMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return fileMessageEntity
    }
    
    // MARK: Location message
    
    public func locationMessageEntity(
        messageID: Data,
        date: Date,
        accuracy: Double?,
        latitude: Double,
        longitude: Double,
        poiAddress: String?,
        poiName: String?,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversation: ConversationEntity
    ) -> LocationMessageEntity {
        let locationMessageEntity = LocationMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            accuracy: accuracy,
            latitude: latitude,
            longitude: longitude,
            poiAddress: poiAddress,
            poiName: poiName,
            conversation: conversation
        )
        
        setProperties(of: locationMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return locationMessageEntity
    }
    
    public func locationMessageEntity(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        poiName: String? = nil,
        poiAddress: String? = nil,
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> LocationMessageEntity {
        let locationMessageEntity = LocationMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            accuracy: accuracy,
            latitude: latitude,
            longitude: longitude,
            poiAddress: poiAddress,
            poiName: poiName,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = locationMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return locationMessageEntity
    }
    
    // MARK: Ballot message
    
    public func ballotMessageEntity(
        messageID: Data,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversationEntity: ConversationEntity,
    ) -> BallotMessageEntity {
        let ballotMessageEntity = BallotMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            conversation: conversationEntity
        )
        
        setProperties(of: ballotMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return ballotMessageEntity
    }
    
    public func ballotMessageEntity(
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> BallotMessageEntity {
        let ballotMessageEntity = BallotMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = ballotMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return ballotMessageEntity
    }
    
    // MARK: System message
    
    /// New system message and set as last message if is allowed.
    /// - Parameters:
    ///   - type: Type that stats with `kSystemMessage...`
    ///   - conversation: Conversation to add system message to
    ///   - setLastUpdate: Update last update of conversation if system message is set as last message
    /// - Returns: New system message
    public func systemMessageEntity( // This is public because old MD & 1:1 calls depend on in in the app targets
        for type: SystemMessageEntity.SystemMessageEntityType,
        in conversation: ConversationEntity,
        setLastUpdate: Bool = false
    ) -> SystemMessageEntity {
        let systemMessageEntity = SystemMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            type: Int16(type.rawValue),
            conversation: conversation
        )
        
        if systemMessageEntity.isAllowedAsLastMessage {
            conversation.lastMessage = systemMessageEntity
            if setLastUpdate {
                conversation.lastUpdate = .now
            }
        }
        
        return systemMessageEntity
    }
    
    // MARK: - Legacy messages
    
    // MARK: Audio message
    
    public func audioMessageEntity(
        messageID: Data,
        audioBlobID: Data?,
        audioSize: Int?,
        duration: Int,
        encryptionKey: Data?,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversation: ConversationEntity
    ) -> AudioMessageEntity {
        let audioMessageEntity = AudioMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            audioBlobID: audioBlobID,
            audioSize: audioSize != nil ? UInt32(audioSize!) : nil,
            duration: Float(duration),
            encryptionKey: encryptionKey,
            conversation: conversation
        )
        
        setProperties(of: audioMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return audioMessageEntity
    }
    
    public func audioMessageEntity(
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> AudioMessageEntity {
        let audioMessageEntity = AudioMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = audioMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return audioMessageEntity
    }
    
    // MARK: Image message
    
    public func imageMessageEntity(
        messageID: Data,
        imageBlobID: Data?,
        imageNonce: Data?,
        imageSize: NSNumber?,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversation: ConversationEntity
    ) -> ImageMessageEntity {
        let imageMessageEntity = ImageMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            imageBlobID: imageBlobID,
            imageNonce: imageNonce,
            imageSize: imageSize,
            conversation: conversation
        )
                
        setProperties(of: imageMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return imageMessageEntity
    }

    public func imageMessageEntity(
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> ImageMessageEntity {
        let imageMessageEntity = ImageMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = imageMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return imageMessageEntity
    }
    
    // MARK: Video message
    
    public func videoMessageEntity(
        messageID: Data,
        duration: Int,
        encryptionKey: Data?,
        videoBlobID: Data?,
        videoSize: Int?,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int,
        in conversation: ConversationEntity
    ) -> VideoMessageEntity {
        let videoMessageEntity = VideoMessageEntity(
            context: managedObjectContext,
            id: messageID,
            isOwn: false,
            duration: duration as NSNumber,
            encryptionKey: encryptionKey,
            videoBlobID: videoBlobID,
            videoSize: videoSize as? NSNumber,
            conversation: conversation
        )
        
        setProperties(of: videoMessageEntity, date: date, flags: flags, forwardSecurityMode: forwardSecurityMode)

        return videoMessageEntity
    }
    
    public func videoMessageEntity(
        in conversationEntity: ConversationEntity,
        setLastUpdate: Bool = true
    ) -> VideoMessageEntity {
        let videoMessageEntity = VideoMessageEntity(
            context: managedObjectContext,
            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
            isOwn: true,
            conversation: conversationEntity
        )
        
        conversationEntity.lastMessage = videoMessageEntity
        
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        
        return videoMessageEntity
    }
    
    // MARK: Helper
    
    private func setProperties(
        of baseMessageEntity: BaseMessageEntity,
        date: Date,
        flags: NSNumber?,
        forwardSecurityMode: Int
    ) {
        baseMessageEntity.remoteSentDate = date
        baseMessageEntity.flags = flags
        baseMessageEntity.forwardSecurityMode = forwardSecurityMode as NSNumber
    }
    
    // MARK: - Message relations
    
    public func messageHistoryEntryEntity(for message: BaseMessageEntity) -> MessageHistoryEntryEntity {
        let date: Date? =
            if message.isOwnMessage {
                if let lastEdited = message.lastEditedAt {
                    lastEdited
                }
                else {
                    message.date
                }
            }
            else {
                if let lastEdited = message.lastEditedAt {
                    lastEdited
                }
                else if let remoteSentDate = message.remoteSentDate {
                    remoteSentDate
                }
                else {
                    message.date
                }
            }
        
        return MessageHistoryEntryEntity(
            context: managedObjectContext,
            editDate: date ?? .now,
            message: message
        )
    }
    
    public func messageMarkersEntity() -> MessageMarkersEntity {
        MessageMarkersEntity(context: managedObjectContext)
    }
    
    public func messageReactionEntity(reaction: String, message: BaseMessageEntity) -> MessageReactionEntity {
        MessageReactionEntity(context: managedObjectContext, reaction: reaction, message: message)
    }

    // MARK: - Nonce
    
    public func nonceEntity(for hashedNonce: Data) -> NonceEntity {
        // TODO: We should probably do hashing here
        NonceEntity(context: managedObjectContext, nonce: hashedNonce)
    }
    
    // MARK: - Data entities
    
    @objc public func imageDataEntity(data: Data, size: CGSize, message: ImageMessageEntity? = nil) -> ImageDataEntity {
        ImageDataEntity(
            context: managedObjectContext,
            data: data,
            height: Int16(size.height),
            width: Int16(size.width),
            message: message
        )
    }
    
    func videoDataEntity(data: Data, message: VideoMessageEntity? = nil) -> VideoDataEntity {
        VideoDataEntity(context: managedObjectContext, data: data, message: message)
    }
    
    @objc public func fileDataEntity(data: Data?, message: FileMessageEntity? = nil) -> FileDataEntity {
        FileDataEntity(context: managedObjectContext, data: data, message: message)
    }
    
    func audioDataEntity(data: Data, message: AudioMessageEntity? = nil) -> AudioDataEntity {
        AudioDataEntity(context: managedObjectContext, data: data, message: message)
    }
    
    // MARK: - Contact
    
    @objc public func contactEntity(
        identity: String,
        publicKey: Data,
        sortOrderFirstName: Bool
    ) -> ContactEntity {
        ContactEntity(
            context: managedObjectContext,
            identity: identity,
            publicKey: publicKey,
            sortOrderFirstName: sortOrderFirstName
        )
    }
    
    // MARK: - Conversation
    
    @objc public func conversationEntity(setLastUpdate: Bool = true) -> ConversationEntity {
        let conversationEntity = ConversationEntity(context: managedObjectContext)
        if setLastUpdate {
            conversationEntity.lastUpdate = .now
        }
        return conversationEntity
    }
    
    // MARK: - DistributionList
    
    public func distributionListEntity(
        distributionListID: Int64,
        conversation: ConversationEntity
    ) -> DistributionListEntity {
        DistributionListEntity(
            context: managedObjectContext,
            distributionListID: distributionListID,
            conversation: conversation
        )
    }

    // MARK: - Group
    
    public func groupEntity(groupID: Data, state: NSNumber) -> GroupEntity {
        GroupEntity(context: managedObjectContext, groupID: groupID, state: state)
    }
    
    // MARK: - Ballots
        
    @objc public func ballotEntity(id: Data) -> BallotEntity {
        BallotEntity(context: managedObjectContext, assessmentType: .single, id: id, state: .open, type: .intermediate)
    }
    
    @objc public func ballotChoiceEntity(
        ballotEntity: BallotEntity,
        id: NSNumber = arc4random() as NSNumber
    ) -> BallotChoiceEntity {
        let choiceEntity = BallotChoiceEntity(context: managedObjectContext, id: id, ballot: ballotEntity)
        choiceEntity.createDate = .now
        return choiceEntity
    }
    
    public func ballotResultEntity(
        participantID: String,
        ballotChoiceEntity: BallotChoiceEntity
    ) -> BallotResultEntity {
        let result = BallotResultEntity(
            context: managedObjectContext,
            participantID: participantID,
            ballotChoice: ballotChoiceEntity
        )
        result.createDate = .now
        return result
    }

    // MARK: - LastGroupSyncRequestEntity
    
    public func lastGroupSyncRequestEntity(
        groupIdentity: GroupIdentity,
        lastSyncRequest: Date
    ) -> LastGroupSyncRequestEntity {
        LastGroupSyncRequestEntity(
            context: managedObjectContext,
            groupCreator: groupIdentity.creator.rawValue,
            groupID: groupIdentity.id,
            lastSyncRequest: lastSyncRequest
        )
    }
    
    // MARK: - WebClientSession
    
    public func webClientSessionEntity(
        initiatorPermanentPublicKey: Data,
        permanent: Bool,
        saltyRTCHost: String,
        saltyRTCPort: Int64,
        selfHosted: Bool,
        serverPermanentPublicKey: Data
    ) -> WebClientSessionEntity {
        WebClientSessionEntity(
            context: managedObjectContext,
            initiatorPermanentPublicKey: initiatorPermanentPublicKey,
            permanent: permanent,
            saltyRTCHost: saltyRTCHost,
            saltyRTCPort: saltyRTCPort,
            selfHosted: selfHosted,
            serverPermanentPublicKey: serverPermanentPublicKey
        )
    }
    
    // MARK: - Calls
    
    public func callEntity(contactEntity: ContactEntity) -> CallEntity {
        CallEntity(context: managedObjectContext, contactEntity: contactEntity)
    }
    
    public func groupCallEntity() -> GroupCallEntity {
        GroupCallEntity(context: managedObjectContext)
    }
}
