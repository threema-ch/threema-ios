//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

class EntityCreatorTests: XCTestCase {

    private let testBundle = Bundle(for: EntityCreatorTests.self)
    private var context: NSManagedObjectContext!
    private var databasePreparer: DatabasePreparer!
    private var conversation: ConversationEntity!
    private var entityCreator: EntityCreator!
    private var entityManager: EntityManager!

    override func setUp() {
        let (_, context, backgroundManagedObjectContext) = DatabasePersistentContext.devNullContext()
                
        databasePreparer = DatabasePreparer(context: context)
        
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
        
        let databaseContext = DatabaseContext(
            mainContext: context,
            backgroundContext: backgroundManagedObjectContext
        )
        
        entityCreator = EntityCreator(managedObjectContext: context)
        entityManager = EntityManager(databaseContext: databaseContext, isRemoteSecretEnabled: false)
    }
    
    // MARK: - Own messages
    
    func testCreateOwnTextMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let expectedText = "Test"
        
        let textMessageEntity = await entityManager.performSave {
            let entity = self.entityManager.entityCreator.textMessageEntity(
                text: expectedText,
                in: self.conversation,
                setLastUpdate: true
            )
            return entity
        }
        
        validateNewOwnMessageEntity(textMessageEntity, in: conversation)
        XCTAssertNil(textMessageEntity.quotedMessageID)
        XCTAssertEqual(textMessageEntity.text, expectedText)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    func testCreateOwnTextMessageEntityNoLastUpdate() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let expectedText = "Test"
        let expectedLastUpdate = Date.now
        conversation.lastUpdate = expectedLastUpdate

        let textMessageEntity = await entityManager.performSave {
            let entity = self.entityManager.entityCreator.textMessageEntity(
                text: expectedText,
                in: self.conversation,
                setLastUpdate: false
            )
            return entity
        }
        
        validateNewOwnMessageEntity(textMessageEntity, in: conversation)
        XCTAssertNil(textMessageEntity.quotedMessageID)
        XCTAssertEqual(textMessageEntity.text, expectedText)
        XCTAssertEqual(conversation.lastUpdate, expectedLastUpdate)
    }
    
    func testCreateOwnImageMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let imageMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.imageMessageEntity(in: self.conversation)
        }
        
        validateNewOwnMessageEntity(imageMessageEntity, in: conversation)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    func testCreateOwnVideoMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let videoMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.videoMessageEntity(in: self.conversation)
        }
        
        validateNewOwnMessageEntity(videoMessageEntity, in: conversation)
        XCTAssertNotNil(conversation.lastUpdate)
    }

    func testCreateOwnFileMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let fileMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.fileMessageEntity(in: self.conversation)
        }
        
        validateNewOwnMessageEntity(fileMessageEntity, in: conversation)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    func testCreateOwnAudioMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let audioMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.audioMessageEntity(in: self.conversation)
        }
        
        validateNewOwnMessageEntity(audioMessageEntity, in: conversation)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    func testCreateOwnLocationMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let expectedLatitude = 10.0
        let expectedLongitude = 20.0
        let expectedAccuracy = 100.0
        
        let locationMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.locationMessageEntity(
                latitude: expectedLatitude,
                longitude: expectedLongitude,
                accuracy: expectedAccuracy,
                in: self.conversation,
                setLastUpdate: true
            )
        }
        
        validateNewOwnMessageEntity(locationMessageEntity, in: conversation)
        XCTAssertEqual(locationMessageEntity.latitude.doubleValue, expectedLatitude)
        XCTAssertEqual(locationMessageEntity.longitude.doubleValue, expectedLongitude)
        XCTAssertEqual(locationMessageEntity.accuracy?.doubleValue, expectedAccuracy)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    func testCreateOwnLocationMessageEntityNoLastUpdate() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let expectedLatitude = 1234.5678
        let expectedLongitude = 98765.4321
        let expectedAccuracy = 234.230
        
        let expectedLastUpdate = Date.now
        conversation.lastUpdate = expectedLastUpdate
        
        let locationMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.locationMessageEntity(
                latitude: expectedLatitude,
                longitude: expectedLongitude,
                accuracy: expectedAccuracy,
                in: self.conversation,
                setLastUpdate: false
            )
        }
        
        validateNewOwnMessageEntity(locationMessageEntity, in: conversation)
        XCTAssertEqual(locationMessageEntity.latitude.doubleValue, expectedLatitude)
        XCTAssertEqual(locationMessageEntity.longitude.doubleValue, expectedLongitude)
        XCTAssertEqual(locationMessageEntity.accuracy?.doubleValue, expectedAccuracy)
        XCTAssertEqual(conversation.lastUpdate, expectedLastUpdate)
    }
    
    func testCreateSystemMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let expectedType = SystemMessageEntity.SystemMessageEntityType.unsupportedType

        let systemMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.systemMessageEntity(
                for: expectedType,
                in: self.conversation
            )
        }
        
        XCTAssertTrue(systemMessageEntity.isOwnMessage)
        XCTAssertEqual(systemMessageEntity.sent, NSNumber(booleanLiteral: true))
        XCTAssertEqual(systemMessageEntity.delivered, NSNumber(booleanLiteral: false))
        XCTAssertEqual(systemMessageEntity.read, NSNumber(booleanLiteral: false))
        XCTAssertEqual(systemMessageEntity.type.intValue, expectedType.rawValue)
        XCTAssertEqual(systemMessageEntity.conversation, conversation)
        XCTAssertNil(conversation.lastUpdate)
    }
    
    func testCreateOwnBallotMessageEntity() async throws {
        XCTAssertEqual(conversation.unreadMessageCount, 0)
        XCTAssertNil(conversation.lastUpdate)
        
        let ballotMessageEntity = await entityManager.performSave {
            self.entityManager.entityCreator.ballotMessageEntity(in: self.conversation)
        }
        
        validateNewOwnMessageEntity(ballotMessageEntity, in: conversation)
        XCTAssertNotNil(conversation.lastUpdate)
    }
    
    // MARK: Own message validation
    
    func validateNewOwnMessageEntity(_ messageEntity: BaseMessageEntity, in conversation: ConversationEntity) {
        XCTAssertTrue(messageEntity.isOwnMessage)
        XCTAssertEqual(messageEntity.sent, NSNumber(booleanLiteral: false))
        XCTAssertEqual(messageEntity.delivered, NSNumber(booleanLiteral: false))
        XCTAssertEqual(messageEntity.read, NSNumber(booleanLiteral: false))
        XCTAssertEqual(messageEntity.conversation, conversation)
        XCTAssertEqual(conversation.lastMessage, messageEntity)
    }
    
    // MARK: - Other entities
    
    func testCreateContactEntity() {
        let contactEntity = entityManager.performAndWaitSave {
            let contact = self.entityManager.entityCreator.contactEntity(
                identity: "ABCDEFGH",
                publicKey: MockData.generatePublicKey(),
                sortOrderFirstName: true
            )
            return contact
        }
        
        XCTAssertNotNil(contactEntity.createdAt)
    }
    
    func testCreateConversationEntity() {
        let conversationEntity = entityManager.performAndWaitSave {
            self.entityCreator.conversationEntity()
        }
        
        XCTAssertNotNil(conversationEntity.lastUpdate)
    }
    
    func testCreateConversationEntityNoLastUpdate() {
        let conversationEntity = entityManager.performAndWaitSave {
            self.entityCreator.conversationEntity(setLastUpdate: false)
        }
        
        XCTAssertNil(conversationEntity.lastUpdate)
    }
    
    func testCreateBallotChoiceEntity() throws {
        let ballotChoiceEntity = entityManager.performAndWaitSave {
            // Ensure all required values are set
            let ballot = self.entityCreator.ballotEntity(id: MockData.generateBallotID())
            let ballotChoice = self.entityCreator.ballotChoiceEntity(ballotEntity: ballot)
            return ballotChoice
        }
        
        XCTAssertNotNil(ballotChoiceEntity.id)
        XCTAssertNotNil(ballotChoiceEntity.createDate)
    }
    
    func testCreateBallotResultEntity() throws {
        let ballotResultEntity = entityManager.performAndWaitSave {
            
            let ballot = self.entityCreator.ballotEntity(id: MockData.generateBallotID())
            let ballotChoice = self.entityCreator.ballotChoiceEntity(ballotEntity: ballot)
            let ballotResult = self.entityCreator.ballotResultEntity(
                participantID: "ABCDEFGH",
                ballotChoiceEntity: ballotChoice
            )
            
            return ballotResult
        }
        
        XCTAssertNotNil(ballotResultEntity.createDate)
    }
    
    func testNonceEntity() {
        let expectedNonce = MockData.generateMessageNonce()
        
        let nonceEntity = entityManager.performAndWaitSave {
            self.entityCreator.nonceEntity(for: expectedNonce)
        }
        
        XCTAssertEqual(nonceEntity.nonce, expectedNonce)
    }
    
    func testCreateOwnMessageHistoryEntryEntity() {
        let messageEntity = entityManager.performAndWaitSave {
            self.entityCreator.textMessageEntity(
                text: "Hello, world!",
                in: self.conversation,
                setLastUpdate: true
            )
        }

        XCTAssertTrue(messageEntity.isOwnMessage)
        XCTAssertNil(messageEntity.lastEditedAt)
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            self.entityCreator.messageHistoryEntryEntity(for: messageEntity)
        }
        
        XCTAssertEqual(messageHistoryEntryEntity.editDate, messageEntity.date)
    }
    
    func testCreateOwnMessageHistoryEntryEntityWithExistingEdit() {
        let expectedEditDate = Date.now
        
        let messageEntity = entityManager.performAndWaitSave {
            self.entityCreator.textMessageEntity(
                text: "Hello, world!",
                in: self.conversation,
                setLastUpdate: true
            )
        }
        messageEntity.lastEditedAt = expectedEditDate

        XCTAssertTrue(messageEntity.isOwnMessage)
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            self.entityCreator.messageHistoryEntryEntity(for: messageEntity)
        }
        
        XCTAssertEqual(messageHistoryEntryEntity.editDate, expectedEditDate)
    }
    
    func testCreateOtherMessageHistoryEntryEntity() {
        let messageEntity = entityManager.performAndWaitSave {
            self.entityCreator.textMessageEntity(
                text: "Hello, world!",
                in: self.conversation,
                setLastUpdate: true
            )
        }
        messageEntity.isOwn = NSNumber(booleanLiteral: false)
        
        XCTAssertFalse(messageEntity.isOwnMessage)
        XCTAssertNil(messageEntity.lastEditedAt)
        XCTAssertNil(messageEntity.remoteSentDate)
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            self.entityCreator.messageHistoryEntryEntity(for: messageEntity)
        }
        
        XCTAssertEqual(messageHistoryEntryEntity.editDate, messageEntity.date)
    }
    
    func testCreateOtherMessageHistoryEntryEntityWithRemoteSentDate() {
        let expectedEditDate = Date.now
        
        let messageEntity = entityManager.performAndWaitSave {
            self.entityCreator.textMessageEntity(
                text: "Hello, world!",
                in: self.conversation,
                setLastUpdate: true
            )
        }
        messageEntity.isOwn = NSNumber(booleanLiteral: false)
        messageEntity.remoteSentDate = expectedEditDate
        
        XCTAssertFalse(messageEntity.isOwnMessage)
        XCTAssertNil(messageEntity.lastEditedAt)
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            self.entityCreator.messageHistoryEntryEntity(for: messageEntity)
        }
        
        XCTAssertEqual(messageHistoryEntryEntity.editDate, expectedEditDate)
    }
    
    func testCreateOtherMessageHistoryEntryEntityWithExistingEdit() {
        let expectedEditDate = Date.now
        
        let messageEntity = entityManager.performAndWaitSave {
            self.entityCreator.textMessageEntity(
                text: "Hello, world!",
                in: self.conversation,
                setLastUpdate: true
            )
        }
        messageEntity.isOwn = NSNumber(booleanLiteral: false)
        messageEntity.lastEditedAt = expectedEditDate

        XCTAssertFalse(messageEntity.isOwnMessage)
        XCTAssertNil(messageEntity.remoteSentDate)
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            self.entityCreator.messageHistoryEntryEntity(for: messageEntity)
        }
        
        XCTAssertEqual(messageHistoryEntryEntity.editDate, expectedEditDate)
    }
    
    // MARK: - Advanced file message creation

    func testCreateFileMessageEntityImage() async throws {
        
        // Arrange
        let imageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))

        let expectedData = try XCTUnwrap(Data(contentsOf: imageURL))
        let expectedImage = UIImage(data: expectedData)!
        let expectedMimeType = "image/jpg"
        let expectedCaption = "Test Caption"
        let expectedFileName: String? = imageURL.lastPathComponent
        let expectedType = FileMessageEntity.FileMessageBaseType.media
        let expectedDuration: Double? = nil
        let expectedHeight: Int? = Int(expectedImage.size.height)
        let expectedWidth: Int? = Int(expectedImage.size.width)
        let expectedThumbnailData: Data? = nil
        let expectedThumbnailSize: CGSize? = nil
        let expectedEncryptionKey: Data = MockData.generateBlobEncryptionKey()
        let expectedOrigin = NSNumber(integerLiteral: 1)
        let expectedCorrelationID = "TestCorrelationID"
        let expectedWebRequestID = "TestWebRequestID"

        // Act
        let fileMessageEntity = try entityManager.performAndWaitSave {
            try self.entityManager.entityCreator.createFileMessageEntity(
                data: expectedData,
                mimeType: expectedMimeType,
                caption: expectedCaption,
                fileName: expectedFileName,
                type: expectedType,
                duration: expectedDuration,
                height: expectedHeight,
                width: expectedWidth,
                thumbnailData: expectedThumbnailData,
                thumbnailSize: expectedThumbnailSize,
                encryptionKey: expectedEncryptionKey,
                origin: expectedOrigin,
                in: self.conversation,
                correlationID: expectedCorrelationID,
                webRequestID: expectedWebRequestID
            )
        }
               
        // Assert
        XCTAssertEqual(fileMessageEntity.width, expectedWidth)
        XCTAssertEqual(fileMessageEntity.height, expectedHeight)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            data: expectedData,
            mimeType: expectedMimeType,
            caption: expectedCaption,
            fileName: expectedFileName,
            type: expectedType,
            correlationID: expectedCorrelationID,
            webRequestID: expectedWebRequestID
        )
    }
    
    func testCreateFileMessageEntityVideo() async throws {
        
        // Arrange
        let videoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let videoThumbnailURL = try XCTUnwrap(testBundle.url(forResource: "Video-1-Thumbnail", withExtension: "png"))

        let expectedData = try XCTUnwrap(Data(contentsOf: videoURL))
        let expectedThumbnailData = try XCTUnwrap(Data(contentsOf: videoThumbnailURL))
        let expectedThumbnail = UIImage(data: expectedThumbnailData)!
        let expectedMimeType = "video/mp4"
        let expectedCaption = "Test Caption"
        let expectedFileName: String? = videoURL.lastPathComponent
        let expectedType = FileMessageEntity.FileMessageBaseType.media
        let expectedDuration: Double? = 10
        let expectedHeight: Int? = 400
        let expectedWidth: Int? = 600
        let expectedThumbnailSize: CGSize? = expectedThumbnail.size
        let expectedEncryptionKey: Data = MockData.generateBlobEncryptionKey()
        let expectedOrigin = NSNumber(integerLiteral: 1)
        let expectedCorrelationID = "TestCorrelationID"
        let expectedWebRequestID = "TestWebRequestID"

        // Act
        let fileMessageEntity = try entityManager.performAndWaitSave {
            try self.entityManager.entityCreator.createFileMessageEntity(
                data: expectedData,
                mimeType: expectedMimeType,
                caption: expectedCaption,
                fileName: expectedFileName,
                type: expectedType,
                duration: expectedDuration,
                height: expectedHeight,
                width: expectedWidth,
                thumbnailData: expectedThumbnailData,
                thumbnailSize: expectedThumbnailSize,
                encryptionKey: expectedEncryptionKey,
                origin: expectedOrigin,
                in: self.conversation,
                correlationID: expectedCorrelationID,
                webRequestID: expectedWebRequestID
            )
        }

        // Assert
        XCTAssertEqual(fileMessageEntity.width, expectedWidth)
        XCTAssertEqual(fileMessageEntity.height, expectedHeight)
        XCTAssertEqual(fileMessageEntity.duration, expectedDuration)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            data: expectedData,
            mimeType: expectedMimeType,
            caption: expectedCaption,
            fileName: expectedFileName,
            type: expectedType,
            correlationID: expectedCorrelationID,
            webRequestID: expectedWebRequestID
        )
    }
    
    func testCreateFileMessageEntityAudio() async throws {
        
        // Arrange
        let audioURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))

        let expectedData = try XCTUnwrap(Data(contentsOf: audioURL))
        let expectedMimeType = "audio/mp3"
        let expectedCaption = "Test Caption"
        let expectedFileName: String? = audioURL.lastPathComponent
        let expectedType = FileMessageEntity.FileMessageBaseType.media
        let expectedDuration: Double? = 10
        let expectedHeight: Int? = nil
        let expectedWidth: Int? = nil
        let expectedThumbnailData: Data? = nil
        let expectedThumbnailSize: CGSize? = nil
        let expectedEncryptionKey: Data = MockData.generateBlobEncryptionKey()
        let expectedOrigin = NSNumber(integerLiteral: 1)
        let expectedCorrelationID = "TestCorrelationID"
        let expectedWebRequestID = "TestWebRequestID"

        // Act
        let fileMessageEntity = try entityManager.performAndWaitSave {
            try self.entityManager.entityCreator.createFileMessageEntity(
                data: expectedData,
                mimeType: expectedMimeType,
                caption: expectedCaption,
                fileName: expectedFileName,
                type: expectedType,
                duration: expectedDuration,
                height: expectedHeight,
                width: expectedWidth,
                thumbnailData: expectedThumbnailData,
                thumbnailSize: expectedThumbnailSize,
                encryptionKey: expectedEncryptionKey,
                origin: expectedOrigin,
                in: self.conversation,
                correlationID: expectedCorrelationID,
                webRequestID: expectedWebRequestID
            )
        }

        // Assert
        XCTAssertEqual(fileMessageEntity.width, expectedWidth)
        XCTAssertEqual(fileMessageEntity.height, expectedHeight)
        XCTAssertEqual(fileMessageEntity.duration, expectedDuration)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            data: expectedData,
            mimeType: expectedMimeType,
            caption: expectedCaption,
            fileName: expectedFileName,
            type: expectedType,
            correlationID: expectedCorrelationID,
            webRequestID: expectedWebRequestID
        )
    }
    
    func testCreateFileMessageEntityFile() async throws {
        
        // Arrange
        let fileURL = try XCTUnwrap(testBundle.url(forResource: "Test", withExtension: "pdf"))

        let expectedData = try XCTUnwrap(Data(contentsOf: fileURL))
        let expectedMimeType = "application/pdf"
        let expectedCaption = "Test Caption"
        let expectedFileName: String? = fileURL.lastPathComponent
        let expectedType = FileMessageEntity.FileMessageBaseType.media
        let expectedDuration: Double? = nil
        let expectedHeight: Int? = nil
        let expectedWidth: Int? = nil
        let expectedThumbnailData: Data? = nil
        let expectedThumbnailSize: CGSize? = nil
        let expectedEncryptionKey: Data = MockData.generateBlobEncryptionKey()
        let expectedOrigin = NSNumber(integerLiteral: 1)
        let expectedCorrelationID = "TestCorrelationID"
        let expectedWebRequestID = "TestWebRequestID"

        // Act
        let fileMessageEntity = try entityManager.performAndWaitSave {
            try self.entityManager.entityCreator.createFileMessageEntity(
                data: expectedData,
                mimeType: expectedMimeType,
                caption: expectedCaption,
                fileName: expectedFileName,
                type: expectedType,
                duration: expectedDuration,
                height: expectedHeight,
                width: expectedWidth,
                thumbnailData: expectedThumbnailData,
                thumbnailSize: expectedThumbnailSize,
                encryptionKey: expectedEncryptionKey,
                origin: expectedOrigin,
                in: self.conversation,
                correlationID: expectedCorrelationID,
                webRequestID: expectedWebRequestID
            )
        }

        // Assert
        XCTAssertEqual(fileMessageEntity.width, expectedWidth)
        XCTAssertEqual(fileMessageEntity.height, expectedHeight)
        XCTAssertEqual(fileMessageEntity.duration, expectedDuration)

        generalFileMessageAssertions(
            fileMessageEntity: fileMessageEntity,
            data: expectedData,
            mimeType: expectedMimeType,
            caption: expectedCaption,
            fileName: expectedFileName,
            type: expectedType,
            correlationID: expectedCorrelationID,
            webRequestID: expectedWebRequestID
        )
    }
    
    // MARK: File message validation
    
    private func generalFileMessageAssertions(
        fileMessageEntity: FileMessageEntity,
        data: Data?,
        mimeType: String?,
        caption: String?,
        fileName: String?,
        type: FileMessageEntity.FileMessageBaseType?,
        correlationID: String,
        webRequestID: String
    ) {
        XCTAssertEqual(fileMessageEntity.data?.data, data)
        XCTAssertEqual(fileMessageEntity.mimeType, mimeType)
        XCTAssertEqual(fileMessageEntity.caption, caption)
        XCTAssertEqual(fileMessageEntity.fileName, fileName)
        XCTAssertEqual(fileMessageEntity.fileSize, data != nil ? NSNumber(integerLiteral: data!.count) : nil)
        XCTAssertEqual(fileMessageEntity.type, type != nil ? NSNumber(integerLiteral: type!.rawValue) : 0)
        XCTAssertEqual(fileMessageEntity.correlationID, correlationID)
        XCTAssertEqual(fileMessageEntity.webRequestID, webRequestID)
    }
}
