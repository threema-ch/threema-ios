//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import RemoteSecretProtocolTestHelper
import ThreemaEssentialsTestHelper
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class FileMessageEntityTests: XCTestCase {
    
    // MARK: - Tests

    func testCreationFull() throws {
        try creationTestFull(encrypted: false)
    }
    
    func testCreationEncrypted() throws {
        try creationTestFull(encrypted: true)
    }
    
    private func creationTestFull(encrypted: Bool) throws {
        // Arrange
        let testDatabase = TestDatabase(encrypted: encrypted)
        let entityManager = testDatabase.entityManager

        let messageID = MockData.generateMessageID()
        let isOwn = true
        let blobID = MockData.generateBlobID()
        let blobThumbnailID = MockData.generateBlobID()
        let caption = "Caption"
        let consumed = Date.now
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let fileName = "fileName"
        let fileSize = 0
        let json = "JSON"
        let mime = "MIME"
        let origin = 0
        let progress = 0
        let type = 0

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let thumbnailDataEntity = entityManager.performAndWaitSave {
            let thumbnailDataEntity = entityManager.entityCreator.imageDataEntity(data: Data(), size: .zero)
            return thumbnailDataEntity
        }
        
        let fileDataEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.fileDataEntity(data: Data())
        }

        // Count only encrypt calls while saving `FileMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let fileMessageEntity = entityManager.performAndWaitSave {
            FileMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                blobID: blobID,
                blobThumbnailID: blobThumbnailID,
                caption: caption,
                consumed: consumed,
                encryptionKey: encryptionKey,
                fileName: fileName,
                fileSize: fileSize as NSNumber,
                json: json,
                mimeType: mime,
                origin: origin as NSNumber,
                progress: progress as NSNumber,
                type: type as NSNumber,
                conversation: conversation,
                thumbnail: thumbnailDataEntity,
                data: fileDataEntity
            )
        }

        let fetchedFileMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: fileMessageEntity.objectID) as? FileMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedFileMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedFileMessageEntity.isOwnMessage)
        XCTAssertEqual(blobID, fetchedFileMessageEntity.blobID)
        XCTAssertEqual(blobThumbnailID, fetchedFileMessageEntity.blobThumbnailID)
        XCTAssertEqual(caption, fetchedFileMessageEntity.caption)
        XCTAssertEqual(consumed, fetchedFileMessageEntity.consumed)
        XCTAssertEqual(encryptionKey, fetchedFileMessageEntity.encryptionKey)
        XCTAssertEqual(fileName, fetchedFileMessageEntity.fileName)
        XCTAssertEqual(fileSize as NSNumber, fetchedFileMessageEntity.fileSize)
        XCTAssertEqual(json, fetchedFileMessageEntity.json)
        XCTAssertEqual(mime, fetchedFileMessageEntity.mimeType)
        XCTAssertEqual(origin as NSNumber, fetchedFileMessageEntity.origin)
        XCTAssertEqual(progress as NSNumber, fetchedFileMessageEntity.progress)
        XCTAssertEqual(type as NSNumber, fetchedFileMessageEntity.type)
        XCTAssertEqual(conversation.objectID, fetchedFileMessageEntity.conversation.objectID)
        XCTAssertEqual(thumbnailDataEntity.objectID, fetchedFileMessageEntity.thumbnail?.objectID)
        XCTAssertEqual(fileDataEntity.objectID, fetchedFileMessageEntity.data?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                15
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedFileMessageEntity, mergeChanges: false)

            XCTAssertEqual(blobID, fetchedFileMessageEntity.blobID)
            XCTAssertEqual(blobThumbnailID, fetchedFileMessageEntity.blobThumbnailID)
            XCTAssertEqual(caption, fetchedFileMessageEntity.caption)
            XCTAssertEqual(consumed.timeIntervalSince1970, fetchedFileMessageEntity.consumed?.timeIntervalSince1970)
            XCTAssertEqual(encryptionKey, fetchedFileMessageEntity.encryptionKey)
            XCTAssertEqual(fileName, fetchedFileMessageEntity.fileName)
            XCTAssertEqual(fileSize as NSNumber, fetchedFileMessageEntity.fileSize)
            XCTAssertEqual(json, fetchedFileMessageEntity.json)
            XCTAssertEqual(mime, fetchedFileMessageEntity.mimeType)
            XCTAssertEqual(type as NSNumber, fetchedFileMessageEntity.type)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 10)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                15
            ) // Plus 5 `BaseMessageEntity` fields
        }
        else {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 0)
        }
    }

    func testCreationMinimal() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let messageID = MockData.generateMessageID()
        let isOwn = true
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let fileMessageEntity = entityManager.performAndWaitSave {
            FileMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                conversation: conversation
            )
        }

        let fetchedFileMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: fileMessageEntity.objectID) as? FileMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedFileMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedFileMessageEntity.isOwnMessage)
        XCTAssertEqual(conversation.objectID, fetchedFileMessageEntity.conversation.objectID)
    }

    func testJson() throws {
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let conversationEntity = entityManager.entityCreator.conversationEntity()

        let fileMessageEntity = entityManager.entityCreator.fileMessageEntity(in: conversationEntity)

        XCTAssertNil(fileMessageEntity.correlationID)
        XCTAssertNil(fileMessageEntity.mimeTypeThumbnail)
        XCTAssertNil(fileMessageEntity.height)
        XCTAssertNil(fileMessageEntity.width)
        XCTAssertNil(fileMessageEntity.duration)
        XCTAssertNil(fileMessageEntity.jsonDescription)

        fileMessageEntity.correlationID = "C-1"
        fileMessageEntity.mimeTypeThumbnail = "JPEG"
        fileMessageEntity.height = 1
        fileMessageEntity.width = 2
        fileMessageEntity.duration = 3.3423

        XCTAssertEqual(fileMessageEntity.correlationID, "C-1")
        XCTAssertEqual(fileMessageEntity.mimeTypeThumbnail, "JPEG")
        XCTAssertEqual(fileMessageEntity.height, 1)
        XCTAssertEqual(fileMessageEntity.width, 2)
        XCTAssertEqual(fileMessageEntity.duration, 3.3423)
        XCTAssertNil(fileMessageEntity.jsonDescription)
    }
}
