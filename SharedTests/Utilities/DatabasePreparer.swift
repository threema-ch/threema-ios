//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

    @discardableResult func createBallot(
        conversation: Conversation,
        ballotID: Data = MockData.generateBallotID()
    ) -> Ballot {
        let ballot = createEntity(objectType: Ballot.self)
        ballot.conversation = conversation
        ballot.id = ballotID
        return ballot
    }
    
    @discardableResult func createBallotMessage(
        conversation: Conversation,
        ballot: Ballot,
        ballotState: Int = Int(kBallotMessageStateOpenBallot),
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        userack: Bool = false,
        sender: ContactEntity? = nil,
        remoteSentDate: Date? = nil // can be set to nil for outgoing messages
    ) -> BallotMessage {
        let ballotMessage = createEntity(objectType: BallotMessage.self)
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
        ballotMessage.userack = NSNumber(booleanLiteral: userack)
        ballotMessage.sender = sender
        ballotMessage.remoteSentDate = remoteSentDate
        return ballotMessage
    }

    @discardableResult func createContact(
        publicKey: Data = MockData.generatePublicKey(),
        identity: String,
        featureMask: Int = 1, // Voice calls
        verificationLevel: Int = 0,
        nickname: String? = nil,
        state: NSNumber? = NSNumber(value: kStateActive)
    ) -> ContactEntity {
        let contact = createEntity(objectType: ContactEntity.self)
        contact.publicKey = publicKey
        contact.identity = identity
        contact.featureMask = NSNumber(integerLiteral: featureMask)
        contact.verificationLevel = NSNumber(integerLiteral: verificationLevel)
        if let nickname {
            contact.publicNickname = nickname
        }
        if let state {
            contact.state = state
        }
        return contact
    }
    
    @discardableResult func createConversation(
        contactEntity: ContactEntity? = nil,
        groupID: Data? = nil,
        typing: Bool = false,
        unreadMessageCount: Int = 0,
        category: ConversationCategory = .default,
        visibility: ConversationVisibility = .default,
        complete: ((Conversation) -> Void)? = nil
    ) -> Conversation {
        let conversation = createEntity(objectType: Conversation.self)
        conversation.contact = contactEntity
        conversation.groupID = groupID
        conversation.typing = NSNumber(booleanLiteral: typing)
        conversation.unreadMessageCount = NSNumber(integerLiteral: unreadMessageCount)
        conversation.conversationCategory = category
        conversation.conversationVisibility = visibility
 
        complete?(conversation)
        
        return conversation
    }
    
    @discardableResult func createGroupEntity(groupID: Data, groupCreator: String?) -> GroupEntity {
        let groupEntity = createEntity(objectType: GroupEntity.self)
        groupEntity.groupID = groupID
        groupEntity.groupCreator = groupCreator
        groupEntity.state = NSNumber(integerLiteral: 0)
        return groupEntity
    }
    
    @discardableResult func createImageData(data: Data, height: Int, width: Int) -> ImageData {
        let imageData = createEntity(objectType: ImageData.self)
        imageData.data = data
        imageData.height = NSNumber(integerLiteral: height)
        imageData.width = NSNumber(integerLiteral: width)
        return imageData
    }
    
    @discardableResult func createAudioData(data: Data?) -> AudioData {
        let audioData = createEntity(objectType: AudioData.self)
        audioData.data = data
        return audioData
    }
    
    @discardableResult func createVideoData(data: Data) -> VideoData {
        let videoData = createEntity(objectType: VideoData.self)
        videoData.data = data
        return videoData
    }
    
    @discardableResult func createFileData(data: Data) -> FileData {
        let fileData = createEntity(objectType: FileData.self)
        fileData.data = data
        return fileData
    }
    
    @discardableResult func createAudioMessageEntity(
        conversation: Conversation,
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
        conversation: Conversation,
        image: ImageData,
        thumbnail: ImageData,
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        userack: Bool = false,
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
        imageMessageEntity.userack = NSNumber(booleanLiteral: userack)
        imageMessageEntity.sender = sender
        imageMessageEntity.remoteSentDate = remoteSentDate
        return imageMessageEntity
    }

    @discardableResult func createLocationMessage(
        conversation: Conversation,
        accuracy: Double,
        latitude: Double,
        longitude: Double,
        reverseGeocodingResult: String,
        poiAddress: String? = nil,
        poiName: String?,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        sender: ContactEntity? = nil
    ) -> LocationMessage {
        let locationMessage = createEntity(objectType: LocationMessage.self)
        locationMessage.conversation = conversation
        locationMessage.accuracy = NSNumber(value: accuracy)
        locationMessage.latitude = NSNumber(value: latitude)
        locationMessage.longitude = NSNumber(value: longitude)
        locationMessage.reverseGeocodingResult = reverseGeocodingResult
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
        conversation: Conversation,
        type: Int,
        date: Date = Date(),
        id: Data = MockData.generateMessageID()
    ) -> SystemMessage {
        let systemMessage = createEntity(objectType: SystemMessage.self)
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
        conversation: Conversation,
        text: String = "Test message",
        date: Date = Date(),
        delivered: Bool = true,
        id: Data = MockData.generateMessageID(),
        isOwn: Bool,
        read: Bool = true,
        readDate: Date? = nil,
        sent: Bool = true,
        userack: Bool = false,
        sender: ContactEntity?,
        remoteSentDate: Date? // can be set to nil for outgoing messages
    ) -> TextMessage {
        let textMessage = createEntity(objectType: TextMessage.self)
        textMessage.conversation = conversation
        textMessage.text = text
        textMessage.date = date
        textMessage.delivered = NSNumber(booleanLiteral: delivered)
        textMessage.id = id
        textMessage.isOwn = NSNumber(booleanLiteral: isOwn)
        textMessage.read = NSNumber(booleanLiteral: read)
        textMessage.readDate = readDate
        textMessage.sent = NSNumber(booleanLiteral: sent)
        textMessage.userack = NSNumber(booleanLiteral: userack)
        textMessage.sender = sender
        textMessage.remoteSentDate = remoteSentDate
        return textMessage
    }
    
    @discardableResult func createVideoMessageEntity(
        conversation: Conversation,
        video: VideoData?,
        duration: Int,
        thumbnail: ImageData,
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
        conversation: Conversation,
        encryptionKey: Data? = nil,
        blobID: Data? = nil,
        blobThumbnailID: Data? = nil,
        progress: NSNumber? = nil,
        data: FileData? = nil,
        thumbnail: ImageData? = nil,
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
        fileMessage.blobID = blobID
        fileMessage.blobThumbnailID = blobThumbnailID
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
    ) throws -> (ContactEntity, GroupEntity, Conversation) {
        save {
            let contactEntity = createContact(identity: groupCreatorIdentity)
            let groupEntity = createGroupEntity(groupID: groupID, groupCreator: groupCreatorIdentity)
            let conversation = createConversation()
            conversation.groupID = groupEntity.groupID
            conversation.contact = contactEntity
            members.forEach { identity in
                conversation.members.insert(createContact(identity: identity))
            }

            return (contactEntity, groupEntity, conversation)
        }
    }
    
    private func createEntity<T: NSManagedObject>(objectType: T.Type) -> T {
        var entityName: String
        
        if objectType is ContactEntity.Type {
            entityName = "Contact"
        }
        else if objectType is Conversation.Type {
            entityName = "Conversation"
        }
        else if objectType is GroupEntity.Type {
            entityName = "Group"
        }
        else if objectType is ImageData.Type {
            entityName = "ImageData"
        }
        else if objectType is AudioData.Type {
            entityName = "AudioData"
        }
        else if objectType is VideoData.Type {
            entityName = "VideoData"
        }
        else if objectType is FileData.Type {
            entityName = "FileData"
        }
        else if objectType is Ballot.Type {
            entityName = "Ballot"
        }
        else if objectType is BallotMessage.Type {
            entityName = "BallotMessage"
        }
        else if objectType is SystemMessage.Type {
            entityName = "SystemMessage"
        }
        else if objectType is TextMessage.Type {
            entityName = "TextMessage"
        }
        else if objectType is AudioMessageEntity.Type {
            entityName = "AudioMessage"
        }
        else if objectType is ImageMessageEntity.Type {
            entityName = "ImageMessage"
        }
        else if objectType is LocationMessage.Type {
            entityName = "LocationMessage"
        }
        else if objectType is VideoMessageEntity.Type {
            entityName = "VideoMessage"
        }
        else if objectType is FileMessageEntity.Type {
            entityName = "FileMessage"
        }
        else {
            fatalError("objects type not defined")
        }
        
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: objCnx) as! T
    }
}
