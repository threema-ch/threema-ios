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

final class CallEntityTests: XCTestCase {
    
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
        let callID: NSNumber = 10
        let date: NSDate = Date.now as NSDate
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        let contact = try entityManager.performAndWaitSave {
            let contact = try XCTUnwrap(entityManager.entityCreator.contact())
            contact.identity = contactID
            contact.publicKey = MockData.generatePublicKey()
            return contact
        }
        
        let callEntity = try entityManager.performAndWaitSave {
            let callEntity = try XCTUnwrap(entityManager.entityCreator.callEntity())
            
            callEntity.callID = callID
            callEntity.date = date
            callEntity.contact = contact
           
            return callEntity
        }

        let fetchedCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: callEntity.objectID) as? CallEntity
        )
        
        // Assert
        XCTAssertEqual(callID, fetchedCallEntity.callID)
        XCTAssertEqual(date, fetchedCallEntity.date)
        XCTAssertEqual(contact.objectID, fetchedCallEntity.contact?.objectID)
    }
}
