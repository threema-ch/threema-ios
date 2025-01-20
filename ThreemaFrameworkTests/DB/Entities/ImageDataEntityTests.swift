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

final class ImageDataEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var dbContext: DatabaseContext!
    
    // MARK: - Setup

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        dbContext = DatabaseContext(mainContext: managedObjectContext, backgroundContext: nil)
    }
    
    // MARK: - Tests

    private func testCreation() throws {
        // Arrange
        let testBundle = Bundle(for: ImageDataEntityTests.self)
        let testImageURL = try XCTUnwrap(testBundle.url(forResource: "Bild-1-1", withExtension: "jpg"))
        let data = try XCTUnwrap(Data(contentsOf: testImageURL))
        let entityManager = EntityManager(databaseContext: dbContext)
        let image = try XCTUnwrap(UIImage(data: data))
       
        // Act
        let imageDataEntity = try entityManager.performAndWaitSave {
            let imageDataEntity = try XCTUnwrap(entityManager.entityCreator.imageDataEntity())
            imageDataEntity.data = data
            imageDataEntity.height = Int16(image.size.height)
            imageDataEntity.width = Int16(image.size.width)

            return imageDataEntity
        }
        
        let fetchedImageDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: imageDataEntity.objectID) as? ImageDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedImageDataEntity.data)
        XCTAssertEqual(Int16(image.size.height), fetchedImageDataEntity.height)
        XCTAssertEqual(Int16(image.size.width), fetchedImageDataEntity.width)
        XCTAssertEqual(image.pngData(), fetchedImageDataEntity.uiImage()?.pngData())
    }
}
