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

import CoreData
import ThreemaEssentials
import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

public class DatabasePreparer {
    private let objCnx: NSManagedObjectContext

    public required init(context: NSManagedObjectContext) {
        self.objCnx = context
    }

    /// Save data modifications on DB.
    ///
    /// - Parameters:
    ///    - dbModificationAction: Closure with data modifications
    public func save(dbModificationAction: () -> Void) {
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
    public func save<T>(_ block: () throws -> T) rethrows -> T {
        try objCnx.performAndWait {
            let result = try block()
            do {
                try objCnx.save()
            }
            catch {
                print("\(error)")
                throw error
            }
            return result
        }
    }

    public func delete(object: NSManagedObject) {
        objCnx.delete(object)
    }

    @discardableResult public func createBallot(
        conversation: ConversationEntity,
        ballotID: Data = MockData.generateBallotID()
    ) -> BallotEntity {
        let ballot = BallotEntity(
            context: objCnx,
            assessmentType: nil,
            id: ballotID,
            state: nil,
            type: nil
        )
        ballot.conversation = conversation
        return ballot
    }

    @discardableResult public func createBallotMessage(
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
        let ballotMessage = BallotMessageEntity(
            context: objCnx,
            id: id,
            isOwn: isOwn,
            conversation: conversation
        )
        ballotMessage.ballot = ballot
        ballotMessage.ballotState = NSNumber(integerLiteral: ballotState)
        ballotMessage.date = date
        ballotMessage.delivered = NSNumber(booleanLiteral: delivered)
        ballotMessage.read = NSNumber(booleanLiteral: read)
        ballotMessage.readDate = readDate
        ballotMessage.sent = NSNumber(booleanLiteral: sent)
        ballotMessage.sender = sender
        ballotMessage.remoteSentDate = remoteSentDate
        return ballotMessage
    }

    @discardableResult public func createContact(
        publicKey: Data = MockData.generatePublicKey(),
        identity: String,
        featureMask: Int = 1, // Voice calls
        verificationLevel: ContactEntity.VerificationLevel = .unverified,
        nickname: String? = nil,
        state: ContactEntity.ContactState = .active
    ) -> ContactEntity {
        let contact = ContactEntity(
            context: objCnx,
            featureMask: featureMask,
            forwardSecurityState: NSNumber(integerLiteral: 0),
            identity: identity,
            publicKey: publicKey,
            readReceipts: NSNumber(integerLiteral: 0),
            typingIndicators: NSNumber(integerLiteral: 0),
            verificationLevel: NSNumber(integerLiteral: verificationLevel.rawValue),
            sortOrderFirstName: true
        )
        contact.contactState = state

        if let nickname {
            contact.publicNickname = nickname
        }

        return contact
    }

    @discardableResult public func createConversation(
        contactEntity: ContactEntity? = nil,
        groupID: Data? = nil,
        typing: Bool = false,
        unreadMessageCount: Int = 0,
        category: ConversationEntity.Category = .default,
        visibility: ConversationEntity.Visibility = .default,
        complete: ((ConversationEntity) -> Void)? = nil
    ) -> ConversationEntity {
        let conversation = ConversationEntity(
            context: objCnx,
            category: category,
            groupID: groupID,
            typing: typing,
            unreadMessageCount: NSNumber(integerLiteral: unreadMessageCount),
            visibility: visibility,
            contact: contactEntity
        )

        complete?(conversation)

        return conversation
    }

    @discardableResult public func createGroupEntity(groupID: Data, groupCreator: String?) -> GroupEntity {
        let groupEntity = GroupEntity(
            context: objCnx,
            groupID: groupID,
            state: NSNumber(integerLiteral: 0)
        )
        groupEntity.groupCreator = groupCreator
        return groupEntity
    }

    @discardableResult public func createDistributionListEntity(
        id: Int64,
        conversation: ConversationEntity
    ) -> DistributionListEntity {
        DistributionListEntity(
            context: objCnx,
            distributionListID: id,
            conversation: conversation
        )
    }

    @discardableResult public func createImageDataEntity(data: Data, height: Int16, width: Int16) -> ImageDataEntity {
        ImageDataEntity(
            context: objCnx,
            data: data,
            height: height,
            width: width
        )
    }

    @discardableResult public func createAudioDataEntity(data: Data) -> AudioDataEntity {
        AudioDataEntity(context: objCnx, data: data)
    }

    @discardableResult public func createVideoDataEntity(data: Data) -> VideoDataEntity {
        VideoDataEntity(context: objCnx, data: data)
    }

    @discardableResult public func createFileDataEntity(data: Data) -> FileDataEntity {
        FileDataEntity(context: objCnx, data: data)
    }

    @discardableResult public func createAudioMessageEntity(
        conversation: ConversationEntity,
        duration: Float,
        complete: ((AudioMessageEntity) -> Void)?
    ) -> AudioMessageEntity {
        let audioMessage = AudioMessageEntity(
            context: objCnx,
            id: MockData.generateMessageID(),
            isOwn: true,
            duration: duration,
            conversation: conversation
        )
        audioMessage.date = Date()
        audioMessage.delivered = NSNumber(booleanLiteral: true)
        audioMessage.read = NSNumber(booleanLiteral: false)
        if let complete {
            complete(audioMessage)
        }
        return audioMessage
    }

    @discardableResult public func createImageMessageEntity(
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
        let imageMessageEntity = ImageMessageEntity(
            context: objCnx,
            id: id,
            isOwn: isOwn,
            conversation: conversation
        )
        imageMessageEntity.image = image
        imageMessageEntity.thumbnail = thumbnail
        imageMessageEntity.date = date
        imageMessageEntity.delivered = NSNumber(booleanLiteral: delivered)
        imageMessageEntity.read = NSNumber(booleanLiteral: read)
        imageMessageEntity.readDate = readDate
        imageMessageEntity.sent = NSNumber(booleanLiteral: sent)
        imageMessageEntity.userack = false
        imageMessageEntity.sender = sender
        imageMessageEntity.remoteSentDate = remoteSentDate
        return imageMessageEntity
    }

    @discardableResult public func createLocationMessage(
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
        let locationMessage = LocationMessageEntity(
            context: objCnx,
            id: id,
            isOwn: isOwn,
            latitude: latitude,
            longitude: longitude,
            conversation: conversation
        )
        locationMessage.accuracy = NSNumber(value: accuracy)
        locationMessage.poiAddress = poiAddress
        locationMessage.poiName = poiName
        locationMessage.date = Date()
        locationMessage.delivered = NSNumber(booleanLiteral: true)
        locationMessage.read = NSNumber(booleanLiteral: false)
        locationMessage.sent = NSNumber(booleanLiteral: true)
        locationMessage.userack = NSNumber(booleanLiteral: false)
        locationMessage.sender = sender
        return locationMessage
    }

    @discardableResult public func createSystemMessage(
        conversation: ConversationEntity,
        type: SystemMessageEntity.SystemMessageEntityType,
        date: Date = Date(),
        id: Data = MockData.generateMessageID()
    ) -> SystemMessageEntity {
        let systemMessage = SystemMessageEntity(
            context: objCnx,
            id: id,
            isOwn: true,
            type: Int16(type.rawValue),
            conversation: conversation
        )
        systemMessage.date = date
        systemMessage.delivered = NSNumber(booleanLiteral: false)
        systemMessage.read = NSNumber(booleanLiteral: false)
        systemMessage.sent = NSNumber(booleanLiteral: false)
        systemMessage.userack = NSNumber(booleanLiteral: false)
        return systemMessage
    }

    @discardableResult public func createTextMessage(
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
        let textMessage = TextMessageEntity(
            context: objCnx,
            id: id,
            isOwn: isOwn,
            text: text,
            conversation: conversation
        )
        textMessage.date = date
        textMessage.delivered = NSNumber(booleanLiteral: delivered)
        textMessage.read = NSNumber(booleanLiteral: read)
        textMessage.readDate = readDate
        textMessage.sent = NSNumber(booleanLiteral: sent)
        textMessage.userackDate = userackDate
        textMessage.userack = NSNumber(booleanLiteral: userack)
        textMessage.sender = sender
        textMessage.remoteSentDate = remoteSentDate
        return textMessage
    }

    @discardableResult public func createVideoMessageEntity(
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
        let videoMessageEntity = VideoMessageEntity(
            context: objCnx,
            id: id,
            isOwn: isOwn,
            conversation: conversation
        )
        videoMessageEntity.video = video
        videoMessageEntity.duration = NSNumber(integerLiteral: duration)
        videoMessageEntity.thumbnail = thumbnail
        videoMessageEntity.date = date
        videoMessageEntity.delivered = NSNumber(booleanLiteral: delivered)
        videoMessageEntity.read = NSNumber(booleanLiteral: read)
        videoMessageEntity.readDate = readDate
        videoMessageEntity.sent = NSNumber(booleanLiteral: sent)
        videoMessageEntity.userack = NSNumber(booleanLiteral: userack)
        videoMessageEntity.sender = sender
        videoMessageEntity.remoteSentDate = remoteSentDate
        return videoMessageEntity
    }

    @discardableResult public func createFileMessageEntity(
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
        let fileMessage = FileMessageEntity(
            context: objCnx,
            id: messageID,
            isOwn: isOwn,
            conversation: conversation
        )

        fileMessage.encryptionKey = encryptionKey
        fileMessage.blobID = blobID
        fileMessage.blobThumbnailID = blobThumbnailID
        fileMessage.progress = progress
        fileMessage.data = data
        fileMessage.thumbnail = thumbnail
        fileMessage.mimeType = mimeType
        fileMessage.type = type
        fileMessage.caption = caption
        fileMessage.fileSize = NSNumber(value: 1024)
        
        // Required by Core Data values
        fileMessage.date = date
        fileMessage.sent = NSNumber(booleanLiteral: sent)
        fileMessage.delivered = NSNumber(booleanLiteral: delivered)
        fileMessage.read = NSNumber(booleanLiteral: read)
        fileMessage.userack = NSNumber(booleanLiteral: userack)

        return fileMessage
    }

    public func createGroup(
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
            conversation.groupID = groupEntity.groupID
            conversation.contact = contactEntity
            for identity in members {
                let member = loadEntity(objectType: ContactEntity.self, predicate: "identity == %@", args: identity)
                    ?? createContact(identity: identity)
                conversation.members?.insert(member)
            }

            return (contactEntity, groupEntity, conversation)
        }
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
