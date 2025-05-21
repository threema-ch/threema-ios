//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

class DatabasePreparer {
    private let objCnx: NSManagedObjectContext

    required init(context: NSManagedObjectContext) {
        self.objCnx = context
    }
    
    /// Save data modifications on DB.
    ///
    /// - Parameters:
    ///    - dbModificationAction: Closure with data modifications
    func save(dbModificationAction: () -> Void) {
        do {
            dbModificationAction()
            
            try objCnx.save()
        }
        catch {
            print(error)
            XCTFail("Could not generate test data: \(error)")
        }
    }

    @discardableResult
    func save<T>(_ block: () throws -> T) rethrows -> T {
        try objCnx.performAndWait {
            let result = try block()
            try objCnx.save()
            return result
        }
    }

    func delete(object: NSManagedObject) {
        objCnx.delete(object)
    }

    @discardableResult func createBallot(
        conversation: ConversationEntity,
        ballotID: Data = MockData.generateBallotID()
    ) -> BallotEntity {
        let ballot = createEntity(objectType: BallotEntity.self)
        ballot.conversation = conversation
        ballot.id = ballotID
        return ballot
    }
    
    @discardableResult func createBallotMessage(
        conversation: ConversationEntity,
        ballot: BallotEntity,
        ballotState: Int = BallotEntity.BallotState.open.rawValue,
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        sender: ContactEntity? = nil,
        remoteSentDate: Date? = nil // can be set to nil for outgoing messages
    ) -> BallotMessageEntity {
        let ballotMessage = createEntity(objectType: BallotMessageEntity.self)
        ballotMessage.conversation = conversation
        ballotMessage.ballot = ballot
        ballotMessage.ballotState = NSNumber(integerLiteral: ballotState)
        ballotMessage.date = date
        ballotMessage.delivered = NSNumber(booleanLiteral: delivered)
        ballotMessage.id = id
        ballotMessage.isOwn = NSNumber(booleanLiteral: isOwn)
        ballotMessage.read = NSNumber(booleanLiteral: read)
        ballotMessage.readDate = readDate
        ballotMessage.sent = NSNumber(booleanLiteral: sent)
        ballotMessage.sender = sender
        ballotMessage.remoteSentDate = remoteSentDate
        return ballotMessage
    }

    @discardableResult func createContact(
        publicKey: Data = MockData.generatePublicKey(),
        identity: String,
        featureMask: Int = 1, // Voice calls
        verificationLevel: ContactEntity.VerificationLevel = .unverified,
        nickname: String? = nil,
        state: ContactEntity.ContactState = .active
    ) -> ContactEntity {
        let contact = createEntity(objectType: ContactEntity.self)
        contact.publicKey = publicKey
        contact.setIdentity(to: identity)
        contact.setFeatureMask(to: featureMask)
        contact.contactVerificationLevel = verificationLevel
        contact.contactState = state
        
        if let nickname {
            contact.publicNickname = nickname
        }
        
        return contact
    }
    
    @discardableResult func createConversation(
        contactEntity: ContactEntity? = nil,
        groupID: Data? = nil,
        typing: Bool = false,
        unreadMessageCount: Int = 0,
        category: ConversationEntity.Category = .default,
        visibility: ConversationEntity.Visibility = .default,
        complete: ((ConversationEntity) -> Void)? = nil
    ) -> ConversationEntity {
        let conversation = createEntity(objectType: ConversationEntity.self)
        conversation.contact = contactEntity
        // swiftformat:disable:next acronyms
        conversation.groupId = groupID
        conversation.setTyping(to: typing)
        conversation.unreadMessageCount = NSNumber(integerLiteral: unreadMessageCount)
        conversation.changeCategory(to: category)
        conversation.changeVisibility(to: visibility)
 
        complete?(conversation)
        
        return conversation
    }
    
    @discardableResult func createGroupEntity(groupID: Data, groupCreator: String?) -> GroupEntity {
        let groupEntity = createEntity(objectType: GroupEntity.self)
        // swiftformat:disable:next acronyms
        groupEntity.groupId = groupID
        groupEntity.groupCreator = groupCreator
        groupEntity.state = NSNumber(integerLiteral: 0)
        return groupEntity
    }
    
    @discardableResult func createDistributionListEntity(id: Int64) -> DistributionListEntity {
        let distributionListEntity = createEntity(objectType: DistributionListEntity.self)
        distributionListEntity.distributionListID = id
        return distributionListEntity
    }
    
    @discardableResult func createImageDataEntity(data: Data, height: Int, width: Int) -> ImageDataEntity {
        let imageData = createEntity(objectType: ImageDataEntity.self)
        imageData.data = data
        imageData.height = Int16(height)
        imageData.width = Int16(width)
        return imageData
    }
    
    @discardableResult func createAudioDataEntity(data: Data) -> AudioDataEntity {
        let audioDataEntity = createEntity(objectType: AudioDataEntity.self)
        audioDataEntity.data = data
        return audioDataEntity
    }
    
    @discardableResult func createVideoDataEntity(data: Data) -> VideoDataEntity {
        let videoDataEntity = createEntity(objectType: VideoDataEntity.self)
        videoDataEntity.data = data
        return videoDataEntity
    }
    
    @discardableResult func createFileDataEntity(data: Data) -> FileDataEntity {
        let fileDataEntity = createEntity(objectType: FileDataEntity.self)
        fileDataEntity.data = data
        return fileDataEntity
    }
    
    @discardableResult func createAudioMessageEntity(
        conversation: ConversationEntity,
        duration: Int,
        complete: ((AudioMessageEntity) -> Void)?
    ) -> AudioMessageEntity {
        let audioMessage = createEntity(objectType: AudioMessageEntity.self)
        audioMessage.conversation = conversation
        audioMessage.duration = NSNumber(integerLiteral: duration)
        audioMessage.date = Date()
        audioMessage.delivered = NSNumber(booleanLiteral: true)
        audioMessage.read = NSNumber(booleanLiteral: false)
        if let complete {
            complete(audioMessage)
        }
        return audioMessage
    }
    
    @discardableResult func createImageMessageEntity(
        conversation: ConversationEntity,
        image: ImageDataEntity,
        thumbnail: ImageDataEntity,
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        sender: ContactEntity?,
        remoteSentDate: Date? // can be set to nil for outgoing messages
    ) -> ImageMessageEntity {
        let imageMessageEntity = createEntity(objectType: ImageMessageEntity.self)
        imageMessageEntity.conversation = conversation
        imageMessageEntity.image = image
        imageMessageEntity.thumbnail = thumbnail
        imageMessageEntity.date = date
        imageMessageEntity.delivered = NSNumber(booleanLiteral: delivered)
        imageMessageEntity.id = id
        imageMessageEntity.isOwn = NSNumber(booleanLiteral: isOwn)
        imageMessageEntity.read = NSNumber(booleanLiteral: read)
        imageMessageEntity.readDate = readDate
        imageMessageEntity.sent = NSNumber(booleanLiteral: sent)
        imageMessageEntity.userack = false
        imageMessageEntity.sender = sender
        imageMessageEntity.remoteSentDate = remoteSentDate
        return imageMessageEntity
    }

    @discardableResult func createLocationMessage(
        conversation: ConversationEntity,
        accuracy: Double,
        latitude: Double,
        longitude: Double,
        poiAddress: String? = nil,
        poiName: String?,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        sender: ContactEntity? = nil
    ) -> LocationMessageEntity {
        let locationMessage = createEntity(objectType: LocationMessageEntity.self)
        locationMessage.conversation = conversation
        locationMessage.accuracy = NSNumber(value: accuracy)
        locationMessage.latitude = NSNumber(value: latitude)
        locationMessage.longitude = NSNumber(value: longitude)
        locationMessage.poiAddress = poiAddress
        locationMessage.poiName = poiName
        locationMessage.id = id
        locationMessage.date = Date()
        locationMessage.delivered = NSNumber(booleanLiteral: true)
        locationMessage.isOwn = NSNumber(booleanLiteral: isOwn)
        locationMessage.read = NSNumber(booleanLiteral: false)
        locationMessage.sent = NSNumber(booleanLiteral: true)
        locationMessage.userack = NSNumber(booleanLiteral: false)
        locationMessage.sender = sender
        return locationMessage
    }

    @discardableResult func createSystemMessage(
        conversation: ConversationEntity,
        type: Int,
        date: Date = Date(),
        id: Data = MockData.generateMessageID()
    ) -> SystemMessageEntity {
        let systemMessage = createEntity(objectType: SystemMessageEntity.self)
        systemMessage.conversation = conversation
        systemMessage.type = NSNumber(integerLiteral: type)
        systemMessage.date = date
        systemMessage.delivered = NSNumber(booleanLiteral: false)
        systemMessage.id = id
        systemMessage.isOwn = NSNumber(booleanLiteral: true)
        systemMessage.read = NSNumber(booleanLiteral: false)
        systemMessage.sent = NSNumber(booleanLiteral: false)
        systemMessage.userack = NSNumber(booleanLiteral: false)
        return systemMessage
    }

    @discardableResult func createTextMessage(
        conversation: ConversationEntity,
        text: String = "Test message",
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        userackDate: Date? = nil,
        userack: Bool = false,
        sender: ContactEntity?,
        remoteSentDate: Date? // can be set to nil for outgoing messages
    ) -> TextMessageEntity {
        let textMessage = createEntity(objectType: TextMessageEntity.self)
        textMessage.conversation = conversation
        textMessage.text = text
        textMessage.date = date
        textMessage.delivered = NSNumber(booleanLiteral: delivered)
        textMessage.id = id
        textMessage.isOwn = NSNumber(booleanLiteral: isOwn)
        textMessage.read = NSNumber(booleanLiteral: read)
        textMessage.readDate = readDate
        textMessage.sent = NSNumber(booleanLiteral: sent)
        textMessage.userackDate = userackDate
        textMessage.userack = NSNumber(booleanLiteral: userack)
        textMessage.sender = sender
        textMessage.remoteSentDate = remoteSentDate
        return textMessage
    }
    
    @discardableResult func createVideoMessageEntity(
        conversation: ConversationEntity,
        video: VideoDataEntity?,
        duration: Int,
        thumbnail: ImageDataEntity,
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        userack: Bool = false,
        sender: ContactEntity?,
        remoteSentDate: Date?
    ) -> VideoMessageEntity {
        let videoMessageEntity = createEntity(objectType: VideoMessageEntity.self)
        videoMessageEntity.conversation = conversation
        videoMessageEntity.video = video
        videoMessageEntity.duration = NSNumber(integerLiteral: duration)
        videoMessageEntity.thumbnail = thumbnail
        videoMessageEntity.date = date
        videoMessageEntity.delivered = NSNumber(booleanLiteral: delivered)
        videoMessageEntity.id = id
        videoMessageEntity.isOwn = NSNumber(booleanLiteral: isOwn)
        videoMessageEntity.read = NSNumber(booleanLiteral: read)
        videoMessageEntity.readDate = readDate
        videoMessageEntity.sent = NSNumber(booleanLiteral: sent)
        videoMessageEntity.userack = NSNumber(booleanLiteral: userack)
        videoMessageEntity.sender = sender
        videoMessageEntity.remoteSentDate = remoteSentDate
        return videoMessageEntity
    }
    
    @discardableResult func createFileMessageEntity(
        conversation: ConversationEntity,
        encryptionKey: Data? = nil,
        blobID: Data? = nil,
        blobThumbnailID: Data? = nil,
        progress: NSNumber? = nil,
        data: FileDataEntity? = nil,
        thumbnail: ImageDataEntity? = nil,
        mimeType: String? = nil,
        type: NSNumber? = nil,
        messageID: Data = MockData.generateMessageID(),
        date: Date = Date(),
        isOwn: Bool = false,
        sent: Bool = true,
        delivered: Bool = false,
        read: Bool = false,
        caption: String? = nil,
        userack: Bool = false
    ) -> FileMessageEntity {
        let fileMessage = createEntity(objectType: FileMessageEntity.self)
        
        fileMessage.conversation = conversation
        fileMessage.encryptionKey = encryptionKey
        // swiftformat:disable: acronyms
        fileMessage.blobId = blobID
        fileMessage.blobThumbnailId = blobThumbnailID
        // swiftformat:enable: acronyms
        fileMessage.progress = progress
        fileMessage.data = data
        fileMessage.thumbnail = thumbnail
        fileMessage.mimeType = mimeType
        fileMessage.type = type
        fileMessage.caption = caption
        
        // Required by Core Data values
        fileMessage.id = messageID
        fileMessage.date = date
        fileMessage.isOwn = NSNumber(booleanLiteral: isOwn)
        fileMessage.sent = NSNumber(booleanLiteral: sent)
        fileMessage.delivered = NSNumber(booleanLiteral: delivered)
        fileMessage.read = NSNumber(booleanLiteral: read)
        fileMessage.userack = NSNumber(booleanLiteral: userack)
        
        return fileMessage
    }

    func createGroup(
        groupID: Data,
        groupCreatorIdentity: String,
        members: [String]
    ) throws -> (ContactEntity, GroupEntity, ConversationEntity) {
        save {
            let contactEntity = loadEntity(
                objectType: ContactEntity.self,
                predicate: "identity == %@",
                args: groupCreatorIdentity
            )
                ?? createContact(identity: groupCreatorIdentity)
            let groupEntity = createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            let conversation = createConversation()
            // swiftformat:disable:next acronyms
            conversation.groupId = groupEntity.groupId
            conversation.contact = contactEntity
            for identity in members {
                let member = loadEntity(objectType: ContactEntity.self, predicate: "identity == %@", args: identity)
                    ?? createContact(identity: identity)
                conversation.members?.insert(member)
            }

            return (contactEntity, groupEntity, conversation)
        }
    }
    
    private func createEntity<T: NSManagedObject>(objectType: T.Type) -> T {
        NSEntityDescription.insertNewObject(
            forEntityName: entityDescription(objectType: objectType).name!,
            into: objCnx
        ) as! T
    }

    private func loadEntity<T: NSManagedObject>(objectType: T.Type, predicate: String, args: String...) -> T? {
        let entityDescriptor = entityDescription(objectType: objectType)

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityDescriptor.name!)
        fetchRequest.entity = entityDescriptor
        fetchRequest.predicate = NSPredicate(format: predicate, argumentArray: args)
        fetchRequest.fetchLimit = 1

        return (try? fetchRequest.execute() as? [T])?.first
    }

    private func entityDescription(objectType: (some NSManagedObject).Type) -> NSEntityDescription {
        var entityName: String

        if objectType is ContactEntity.Type {
            entityName = "Contact"
        }
        else if objectType is ConversationEntity.Type {
            entityName = "Conversation"
        }
        else if objectType is GroupEntity.Type {
            entityName = "Group"
        }
        else if objectType is ImageDataEntity.Type {
            entityName = "ImageData"
        }
        else if objectType is AudioDataEntity.Type {
            entityName = "AudioData"
        }
        else if objectType is VideoDataEntity.Type {
            entityName = "VideoData"
        }
        else if objectType is FileDataEntity.Type {
            entityName = "FileData"
        }
        else if objectType is BallotEntity.Type {
            entityName = "Ballot"
        }
        else if objectType is BallotMessageEntity.Type {
            entityName = "BallotMessage"
        }
        else if objectType is SystemMessageEntity.Type {
            entityName = "SystemMessage"
        }
        else if objectType is TextMessageEntity.Type {
            entityName = "TextMessage"
        }
        else if objectType is AudioMessageEntity.Type {
            entityName = "AudioMessage"
        }
        else if objectType is ImageMessageEntity.Type {
            entityName = "ImageMessage"
        }
        else if objectType is LocationMessageEntity.Type {
            entityName = "LocationMessage"
        }
        else if objectType is VideoMessageEntity.Type {
            entityName = "VideoMessage"
        }
        else if objectType is FileMessageEntity.Type {
            entityName = "FileMessage"
        }
        else if objectType is DistributionListEntity.Type {
            entityName = "DistributionList"
        }
        else {
            fatalError("Object type not defined")
        }

        return NSEntityDescription.entity(forEntityName: entityName, in: objCnx)!
    }
}
