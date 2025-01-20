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

import Foundation

import XCTest
@testable import ThreemaFramework

final class LocationMessageEntityTests: XCTestCase {
    
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
        let accuracy: NSNumber = 100
        let latitude: NSNumber = 1.0
        let longitude: NSNumber = 2.0
        let poiAddress = "Address"
        let poiName = "Name"
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
        
        let locationMessageEntity = try entityManager.performAndWaitSave {
            let locationMessageEntity = try XCTUnwrap(entityManager.entityCreator.locationMessageEntity(
                for: conversation,
                setLastUpdate: true
            ))
            
            locationMessageEntity.accuracy = accuracy
            locationMessageEntity.latitude = latitude
            locationMessageEntity.longitude = longitude
            locationMessageEntity.poiAddress = poiAddress
            locationMessageEntity.poiName = poiName
           
            return locationMessageEntity
        }

        let fetchedLocationMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: locationMessageEntity.objectID) as? LocationMessageEntity
        )
        
        // Assert
        XCTAssertEqual(accuracy, fetchedLocationMessageEntity.accuracy)
        XCTAssertEqual(latitude, fetchedLocationMessageEntity.latitude)
        XCTAssertEqual(longitude, fetchedLocationMessageEntity.longitude)
        XCTAssertEqual(poiAddress, fetchedLocationMessageEntity.poiAddress)
        XCTAssertEqual(poiName, fetchedLocationMessageEntity.poiName)
    }
}
