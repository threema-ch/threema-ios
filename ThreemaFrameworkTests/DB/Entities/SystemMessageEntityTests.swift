//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

final class SystemMessageEntityTests: XCTestCase {
    
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
        let arg = String("TestArg").data(using: .utf8)
        let type: NSNumber = 1
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
        
        let systemMessageEntity = try entityManager.performAndWaitSave {
            let systemMessageEntity = try XCTUnwrap(entityManager.entityCreator.systemMessageEntity(
                for: conversation
            ))
            
            systemMessageEntity.arg = arg
            systemMessageEntity.type = type
           
            return systemMessageEntity
        }

        let fetchedSystemMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: systemMessageEntity.objectID) as? SystemMessageEntity
        )
        
        // Assert
        XCTAssertEqual(arg, systemMessageEntity.arg)
        XCTAssertEqual(type, systemMessageEntity.type)
    }
}
