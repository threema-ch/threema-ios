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

final class ImageMessageEntityTests: XCTestCase {
    
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
        let testBundle = Bundle(for: ImageMessageEntityTests.self)
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-4", withExtension: "png"))
        let imageData = try XCTUnwrap(Data(contentsOf: testImageURL))
        
        let imageBlobID = MockData.generateBlobID()
        let nonce = MockData.generateMessageNonce()
        let imageSize: NSNumber = 256
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let imageDataEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.imageDataEntity(data: imageData, size: .zero)
        }
        
        let thumbnailDataEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.imageDataEntity(data: imageData, size: .zero)
        }
        
        // Count only encrypt calls while saving `ImageMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let imageMessageEntity = entityManager.performAndWaitSave {
            ImageMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                encryptionKey: encryptionKey,
                imageBlobID: imageBlobID,
                imageNonce: nonce,
                imageSize: imageSize,
                progress: progress,
                image: imageDataEntity,
                thumbnail: thumbnailDataEntity,
                conversation: conversation
            )
        }

        let fetchedImageMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageMessageEntity.objectID) as? ImageMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedImageMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedImageMessageEntity.isOwnMessage)
        XCTAssertEqual(encryptionKey, fetchedImageMessageEntity.encryptionKey)
        XCTAssertEqual(imageBlobID, fetchedImageMessageEntity.imageBlobID)
        XCTAssertEqual(nonce, fetchedImageMessageEntity.imageNonce)
        XCTAssertEqual(imageSize, fetchedImageMessageEntity.imageSize)
        XCTAssertEqual(progress, fetchedImageMessageEntity.progress)

        XCTAssertEqual(imageDataEntity.objectID, fetchedImageMessageEntity.image?.objectID)
        XCTAssertEqual(thumbnailDataEntity.objectID, fetchedImageMessageEntity.thumbnail?.objectID)
        XCTAssertEqual(conversation.objectID, fetchedImageMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                9
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedImageMessageEntity, mergeChanges: false)

            XCTAssertEqual(encryptionKey, fetchedImageMessageEntity.encryptionKey)
            XCTAssertEqual(imageBlobID, fetchedImageMessageEntity.imageBlobID)
            XCTAssertEqual(nonce, fetchedImageMessageEntity.imageNonce)
            XCTAssertEqual(imageSize, fetchedImageMessageEntity.imageSize)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 4)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                9
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
        
        let imageMessageEntity = entityManager.performAndWaitSave {
            ImageMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                conversation: conversation
            )
        }

        let fetchedImageMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageMessageEntity.objectID) as? ImageMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedImageMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedImageMessageEntity.isOwnMessage)
        XCTAssertEqual(conversation.objectID, fetchedImageMessageEntity.conversation.objectID)
    }
}
