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
import RemoteSecretProtocolTestHelper
import ThreemaEssentialsTestHelper
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class MessageHistoryEntryEntityTests: XCTestCase {
    
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

        let contactID = "TESTER01"
        let date = Date.now
        let text = "Test Text"

        // Act
        entityManager.performAndWaitSave {
            _ = entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: MockData.generatePublicKey(),
                sortOrderFirstName: true
            )
        }

        let message = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contactEntity(for: contactID)!
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact

            let message = entityManager.entityCreator.textMessageEntity(
                text: text,
                in: conversation,
                setLastUpdate: true
            )

            message.date = date

            return message
        }

        // Count only decrypt/encrypt calls while saving `TextMessageEntity`
        testDatabase.remoteSecretCryptoMock.decryptCalls = 0
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            MessageHistoryEntryEntity(
                context: testDatabase.context.main,
                editDate: date,
                text: text,
                message: message
            )
        }

        let fetchedMessageHistoryEntryEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageHistoryEntryEntity.objectID) as? MessageHistoryEntryEntity
        )

        // Assert
        XCTAssertEqual(date, fetchedMessageHistoryEntryEntity.editDate)
        XCTAssertEqual(text, fetchedMessageHistoryEntryEntity.text)
        XCTAssertEqual(message.objectID, fetchedMessageHistoryEntryEntity.message.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedMessageHistoryEntryEntity, mergeChanges: false)

            XCTAssertEqual(text, fetchedMessageHistoryEntryEntity.text)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)
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

        let contactID = "TESTER01"
        let date = Date.now
        
        // Act
        entityManager.performAndWaitSave {
            _ = entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: MockData.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let message = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contactEntity(for: contactID)!
            let conversation = entityManager.entityCreator.conversationEntity()
            conversation.contact = contact

            let message = entityManager.entityCreator.textMessageEntity(
                text: "Test",
                in: conversation,
                setLastUpdate: true
            )
            
            message.date = date
            
            return message
        }
        
        let messageHistoryEntryEntity = entityManager.performAndWaitSave {
            MessageHistoryEntryEntity(
                context: testDatabase.context.main,
                editDate: date,
                message: message
            )
        }

        let fetchedMessageHistoryEntryEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageHistoryEntryEntity.objectID) as? MessageHistoryEntryEntity
        )
        
        // Assert
        XCTAssertEqual(date, fetchedMessageHistoryEntryEntity.editDate)
        XCTAssertEqual(message.objectID, fetchedMessageHistoryEntryEntity.message.objectID)
    }
}
