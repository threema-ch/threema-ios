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

final class MessageMarkersEntityTests: XCTestCase {
        
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

        let star = true
        
        // Act
        let textMessageEntity = entityManager.performAndWaitSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            
            return TextMessageEntity(
                context: testDatabase.context.main,
                id: MockData.generateMessageID(),
                isOwn: true,
                text: "Test",
                conversation: conversation
            )
        }

        // Count only encrypt calls while saving `MessageMarkersEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let messageMarkersEntity = entityManager.performAndWaitSave {
            MessageMarkersEntity(
                context: testDatabase.context.main,
                star: star,
                message: textMessageEntity
            )
        }

        let fetchedMessageMarkersEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageMarkersEntity.objectID) as? MessageMarkersEntity
        )
        
        // Assert
        XCTAssertEqual(star, fetchedMessageMarkersEntity.star.boolValue)
        XCTAssertEqual(textMessageEntity.objectID, fetchedMessageMarkersEntity.message?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedMessageMarkersEntity, mergeChanges: false)

            XCTAssertEqual(star, fetchedMessageMarkersEntity.star.boolValue)

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

        let star = true
        
        // Act
        let messageMarkersEntity = entityManager.performAndWaitSave {
            MessageMarkersEntity(
                context: testDatabase.context.main,
                star: star
            )
        }

        let fetchedMessageMarkersEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: messageMarkersEntity.objectID) as? MessageMarkersEntity
        )
        
        // Assert
        XCTAssertEqual(star, fetchedMessageMarkersEntity.star.boolValue)
    }
}
