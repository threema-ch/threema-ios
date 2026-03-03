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

final class TextMessageEntityTests: XCTestCase {
    
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
        let text = "Test Text"
        let quoteID = MockData.generateMessageID()

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }

        // Count only encrypt calls while saving `TextMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let textMessageEntity = entityManager.performAndWaitSave {
            TextMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                text: text,
                quotedMessageID: quoteID,
                conversation: conversation
            )
        }

        let fetchedTextMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: textMessageEntity.objectID) as? TextMessageEntity
        )

        // Assert
        XCTAssertEqual(messageID, fetchedTextMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedTextMessageEntity.isOwnMessage)
        XCTAssertEqual(text, fetchedTextMessageEntity.text)
        XCTAssertEqual(quoteID, fetchedTextMessageEntity.quotedMessageID)
        XCTAssertEqual(conversation.objectID, fetchedTextMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedTextMessageEntity, mergeChanges: false)

            XCTAssertEqual(text, fetchedTextMessageEntity.text)
            XCTAssertEqual(quoteID, fetchedTextMessageEntity.quotedMessageID)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 2)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
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
        let text = "Test Text"
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
                
        let textMessageEntity = entityManager.performAndWaitSave {
            TextMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                text: text,
                conversation: conversation
            )
        }

        let fetchedTextMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: textMessageEntity.objectID) as? TextMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedTextMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedTextMessageEntity.isOwnMessage)
        XCTAssertEqual(text, fetchedTextMessageEntity.text)
        XCTAssertEqual(conversation.objectID, fetchedTextMessageEntity.conversation.objectID)
    }
}
