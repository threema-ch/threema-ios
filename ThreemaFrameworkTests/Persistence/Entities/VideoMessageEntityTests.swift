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

final class VideoMessageEntityTests: XCTestCase {
    
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
        let testBundle = Bundle(for: VideoMessageEntityTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let videoData = try XCTUnwrap(Data(contentsOf: testVideoURL))
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-4", withExtension: "png"))
        let imageData = try XCTUnwrap(Data(contentsOf: testImageURL))
        
        let videoBlobID = MockData.generateBlobID()
        let videoSize: NSNumber = 256
        let duration: NSNumber = 10
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let videoDataEntity = entityManager.performAndWaitSave {
            let videoDataEntity = entityManager.entityCreator.videoDataEntity(data: videoData)
            return videoDataEntity
        }
        
        let thumbnailDataEntity = entityManager.performAndWaitSave {
            let thumbnailDataEntity = entityManager.entityCreator.imageDataEntity(data: imageData, size: .zero)
                       
            return thumbnailDataEntity
        }
        
        // Count only encrypt calls while saving `VideoMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let videoMessageEntity = entityManager.performAndWaitSave {
            VideoMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                duration: duration,
                encryptionKey: encryptionKey,
                progress: progress,
                videoBlobID: videoBlobID,
                videoSize: videoSize,
                conversation: conversation,
                thumbnail: thumbnailDataEntity,
                video: videoDataEntity
            )
        }

        let fetchedVideoMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: videoMessageEntity.objectID) as? VideoMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedVideoMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedVideoMessageEntity.isOwnMessage)
        XCTAssertEqual(duration, fetchedVideoMessageEntity.duration)
        XCTAssertEqual(encryptionKey, fetchedVideoMessageEntity.encryptionKey)
        XCTAssertEqual(progress, fetchedVideoMessageEntity.progress)
        XCTAssertEqual(videoBlobID, fetchedVideoMessageEntity.videoBlobID)
        XCTAssertEqual(videoSize, fetchedVideoMessageEntity.videoSize)
        XCTAssertEqual(conversation.objectID, fetchedVideoMessageEntity.conversation.objectID)
        XCTAssertEqual(videoDataEntity.objectID, fetchedVideoMessageEntity.video?.objectID)
        XCTAssertEqual(thumbnailDataEntity.objectID, fetchedVideoMessageEntity.thumbnail?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                9
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedVideoMessageEntity, mergeChanges: false)

            XCTAssertEqual(duration, fetchedVideoMessageEntity.duration)
            XCTAssertEqual(encryptionKey, fetchedVideoMessageEntity.encryptionKey)
            XCTAssertEqual(videoBlobID, fetchedVideoMessageEntity.videoBlobID)
            XCTAssertEqual(videoSize, fetchedVideoMessageEntity.videoSize)

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
        
        let videoMessageEntity = entityManager.performAndWaitSave {
            VideoMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                conversation: conversation
            )
        }

        let fetchedVideoMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: videoMessageEntity.objectID) as? VideoMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedVideoMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedVideoMessageEntity.isOwnMessage)
        XCTAssertEqual(conversation.objectID, fetchedVideoMessageEntity.conversation.objectID)
    }
}
