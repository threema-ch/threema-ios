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

final class ImageMessageEntityTests: XCTestCase {
    
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
        let testBundle = Bundle(for: ImageDataEntityTests.self)
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-0", withExtension: "jpg"))
        let imageData = try XCTUnwrap(Data(contentsOf: testImageURL))
        
        let imageBlobID = MockData.generateBlobID()
        let nonce = MockData.generateMessageNonce()
        let imageSize: NSNumber = 256
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        entityManager.performAndWaitSave {
            let contact = entityManager.entityCreator.contact()
            contact?.setIdentity(to: contactID)
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let conversation = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contact(for: contactID)!
            return entityManager.conversation(forContact: contact, createIfNotExisting: true)
        }
        
        let imageDataEntity = try entityManager.performAndWaitSave {
            let imageDataEntity = try XCTUnwrap(entityManager.entityCreator.imageDataEntity())
            
            imageDataEntity.data = imageData
           
            return imageDataEntity
        }
        
        let thumbnailDataEntity = try entityManager.performAndWaitSave {
            let thumbnailDataEntity = try XCTUnwrap(entityManager.entityCreator.imageDataEntity())
            
            thumbnailDataEntity.data = imageData
           
            return thumbnailDataEntity
        }
        
        let imageMessageEntity = try entityManager.performAndWaitSave {
            let imageMessageEntity = try XCTUnwrap(entityManager.entityCreator.imageMessageEntity(for: conversation))
            
            imageMessageEntity.encryptionKey = encryptionKey
            // swiftformat:disable:next acronyms
            imageMessageEntity.imageBlobId = imageBlobID
            imageMessageEntity.imageNonce = nonce
            imageMessageEntity.imageSize = imageSize
            imageMessageEntity.progress = progress
            
            imageMessageEntity.image = imageDataEntity
            imageMessageEntity.thumbnail = thumbnailDataEntity
           
            return imageMessageEntity
        }

        let fetchedImageMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageMessageEntity.objectID) as? ImageMessageEntity
        )
        
        // Assert
        XCTAssertEqual(encryptionKey, fetchedImageMessageEntity.encryptionKey)
        // swiftformat:disable:next acronyms
        XCTAssertEqual(imageBlobID, fetchedImageMessageEntity.imageBlobId)
        XCTAssertEqual(nonce, fetchedImageMessageEntity.imageNonce)
        XCTAssertEqual(imageSize, fetchedImageMessageEntity.imageSize)
        XCTAssertEqual(progress, fetchedImageMessageEntity.progress)

        XCTAssertEqual(imageDataEntity.objectID, fetchedImageMessageEntity.image?.objectID)
        XCTAssertEqual(thumbnailDataEntity.objectID, fetchedImageMessageEntity.thumbnail?.objectID)
    }
}
