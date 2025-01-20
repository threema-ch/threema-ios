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

import XCTest
@testable import ThreemaFramework

final class VideoMessageEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var dbContext: DatabaseContext!
    
    // MARK: - Setup

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        dbContext = DatabaseContext(mainContext: managedObjectContext, backgroundContext: nil)
    }
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let contactID = "TESTER01"
        let testBundle = Bundle(for: VideoDataEntityTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let videoData = try XCTUnwrap(Data(contentsOf: testVideoURL))
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageData = try XCTUnwrap(Data(contentsOf: testImageURL))
        
        let videoBlobID = MockData.generateBlobID()
        let videoSize: NSNumber = 256
        let duration: NSNumber = 10
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        entityManager.performAndWaitSave {
            let contact = entityManager.entityCreator.contact()
            contact?.identity = contactID
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let conversation = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contact(for: contactID)!
            return entityManager.conversation(forContact: contact, createIfNotExisting: true)
        }
        
        let videoDataEntity = try entityManager.performAndWaitSave {
            let videoDataEntity = try XCTUnwrap(entityManager.entityCreator.videoDataEntity())
            
            videoDataEntity.data = videoData
           
            return videoDataEntity
        }
        
        let thumbnailDataEntity = try entityManager.performAndWaitSave {
            let thumbnailDataEntity = try XCTUnwrap(entityManager.entityCreator.imageDataEntity())
            
            thumbnailDataEntity.data = imageData
           
            return thumbnailDataEntity
        }
        
        let videoMessageEntity = try entityManager.performAndWaitSave {
            let videoMessageEntity = try XCTUnwrap(entityManager.entityCreator.videoMessageEntity(for: conversation))
            
            videoMessageEntity.duration = duration
            videoMessageEntity.encryptionKey = encryptionKey
            videoMessageEntity.progress = progress
            // swiftformat:disable:next acronyms
            videoMessageEntity.videoBlobId = videoBlobID
            videoMessageEntity.videoSize = videoSize
            
            videoMessageEntity.thumbnail = thumbnailDataEntity
            videoMessageEntity.video = videoDataEntity
           
            return videoMessageEntity
        }

        let fetchedVideoMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: videoMessageEntity.objectID) as? VideoMessageEntity
        )
        
        // Assert
        XCTAssertEqual(duration, fetchedVideoMessageEntity.duration)
        XCTAssertEqual(encryptionKey, fetchedVideoMessageEntity.encryptionKey)
        XCTAssertEqual(progress, fetchedVideoMessageEntity.progress)
        // swiftformat:disable:next acronyms
        XCTAssertEqual(videoBlobID, fetchedVideoMessageEntity.videoBlobId)
        XCTAssertEqual(videoSize, fetchedVideoMessageEntity.videoSize)

        XCTAssertEqual(videoDataEntity.objectID, fetchedVideoMessageEntity.video?.objectID)
        XCTAssertEqual(thumbnailDataEntity.objectID, fetchedVideoMessageEntity.thumbnail?.objectID)
    }
}
