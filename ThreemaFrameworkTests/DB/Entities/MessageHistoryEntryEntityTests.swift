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

final class MessageHistoryEntryEntityTests: XCTestCase {
    
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
        let date = Date.now
        let text = "Test Text"
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        entityManager.performAndWaitSave {
            let contact = entityManager.entityCreator.contact()
            contact?.identity = contactID
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let message = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contact(for: contactID)!
            let conversation = entityManager.conversation(forContact: contact, createIfNotExisting: true)
            let message = entityManager.entityCreator.textMessageEntity(for: conversation, setLastUpdate: true)!
            
            message.date = date
            message.text = text
            
            return message
        }
        
        let messageHistoryEntryEntity = try entityManager.performAndWaitSave {
            let messageHistoryEntryEntity = try XCTUnwrap(entityManager.entityCreator.messageHistoryEntry(for: message))
            
            messageHistoryEntryEntity.text = text
            
            return messageHistoryEntryEntity
        }

        let fetchedMessageHistoryEntryEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageHistoryEntryEntity.objectID) as? MessageHistoryEntryEntity
        )
        
        // Assert
        XCTAssertEqual(date, fetchedMessageHistoryEntryEntity.editDate)
        XCTAssertEqual(text, fetchedMessageHistoryEntryEntity.text)
        XCTAssertEqual(message.objectID, fetchedMessageHistoryEntryEntity.message.objectID)
    }
}
