//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

final class BallotMessageEntityTests: XCTestCase {
    
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
        let ballotState = NSNumber(integerLiteral: 0)
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let ballotEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotEntity(id: MockData.generateBallotID())
        }

        // Count only encrypt calls while saving `BallotMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let ballotMessageEntity = entityManager.performAndWaitSave {
            BallotMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                ballotState: ballotState,
                ballot: ballotEntity,
                conversation: conversation
            )
        }
        
        let fetchedBallotMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotMessageEntity.objectID) as? BallotMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedBallotMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedBallotMessageEntity.isOwnMessage)
        XCTAssertEqual(ballotState, fetchedBallotMessageEntity.ballotState)
        XCTAssertEqual(ballotEntity, fetchedBallotMessageEntity.ballot)
        XCTAssertEqual(conversation.objectID, fetchedBallotMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 6) // Plus 5 from `BaseMessageEntity`

            // Test faulting
            testDatabase.context.main.refresh(fetchedBallotMessageEntity, mergeChanges: false)

            XCTAssertEqual(ballotState, fetchedBallotMessageEntity.ballotState)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 6) // Plus 5 from `BaseMessageEntity`
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
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let ballotMessageEntity = entityManager.performAndWaitSave {
            BallotMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                conversation: conversation
            )
        }
        
        let fetchedBallotMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotMessageEntity.objectID) as? BallotMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedBallotMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedBallotMessageEntity.isOwnMessage)
        XCTAssertEqual(conversation.objectID, fetchedBallotMessageEntity.conversation.objectID)
    }
}
