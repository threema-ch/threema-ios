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

final class MessageReactionEntityTests: XCTestCase {
        
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
        let expectedReaction = "😁"
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
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
                text: "Text",
                in: conversation,
                setLastUpdate: true
            )
            message.date = Date.now

            return message
        }
        
        // Count only encrypt calls while saving `MessageReactionEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let messageReactionEntity = entityManager.performAndWaitSave {
            MessageReactionEntity(
                context: testDatabase.context.main,
                date: date,
                reaction: expectedReaction,
                contact: contactEntity,
                message: message
            )
        }

        let fetchedMessageReactionEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageReactionEntity.objectID) as? MessageReactionEntity
        )
        
        // Assert
        XCTAssertEqual(date, fetchedMessageReactionEntity.date)
        XCTAssertEqual(expectedReaction, fetchedMessageReactionEntity.reaction)
        XCTAssertEqual(contactEntity.objectID, fetchedMessageReactionEntity.creator?.objectID)
        XCTAssertEqual(message, fetchedMessageReactionEntity.message)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 2)

            // Test faulting
            testDatabase.context.main.refresh(fetchedMessageReactionEntity, mergeChanges: false)

            XCTAssertEqual(date.timeIntervalSince1970, fetchedMessageReactionEntity.date.timeIntervalSince1970)
            XCTAssertEqual(expectedReaction, fetchedMessageReactionEntity.reaction)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 2)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 2)
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
        let expectedReaction = "😁"
        
        // Act
        _ = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
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
                text: "Text",
                in: conversation,
                setLastUpdate: true
            )
            message.date = Date.now

            return message
        }
        
        let messageReactionEntity = entityManager.performAndWaitSave {
            MessageReactionEntity(
                context: testDatabase.context.main,
                date: date,
                reaction: expectedReaction,
                message: message
            )
        }

        let fetchedMessageReactionEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageReactionEntity.objectID) as? MessageReactionEntity
        )
        
        // Assert
        XCTAssertEqual(date, fetchedMessageReactionEntity.date)
        XCTAssertEqual(expectedReaction, fetchedMessageReactionEntity.reaction)
        XCTAssertEqual(message, fetchedMessageReactionEntity.message)
    }
}
