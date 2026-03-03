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
@testable import ThreemaFramework

final class SystemMessageEntityTests: XCTestCase {
    
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
        let arg = String("TestArg").data(using: .utf8)
        let type = SystemMessageEntity.SystemMessageEntityType.renameGroup

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        // Count only encrypt calls while saving `SystemMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let systemMessageEntity = entityManager.performAndWaitSave {
            SystemMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                arg: arg,
                type: Int16(type.rawValue),
                conversation: conversation
            )
        }

        let fetchedSystemMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: systemMessageEntity.objectID) as? SystemMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedSystemMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedSystemMessageEntity.isOwnMessage)
        XCTAssertEqual(arg, fetchedSystemMessageEntity.arg)
        XCTAssertEqual(type.rawValue, fetchedSystemMessageEntity.type.intValue)
        XCTAssertEqual(conversation.objectID, fetchedSystemMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                6
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedSystemMessageEntity, mergeChanges: false)

            XCTAssertEqual(arg, fetchedSystemMessageEntity.arg)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                6
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
        let type = 1
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let systemMessageEntity = entityManager.performAndWaitSave {
            SystemMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                type: Int16(type),
                conversation: conversation
            )
        }

        let fetchedSystemMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: systemMessageEntity.objectID) as? SystemMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedSystemMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedSystemMessageEntity.isOwnMessage)
        XCTAssertEqual(type, fetchedSystemMessageEntity.type.intValue)
        XCTAssertEqual(conversation.objectID, fetchedSystemMessageEntity.conversation.objectID)
    }
}
