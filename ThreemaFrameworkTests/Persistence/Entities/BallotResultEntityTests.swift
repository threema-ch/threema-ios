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

final class BallotResultEntityTests: XCTestCase {
    
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

        let createDate = Date.distantPast
        let modifyDate = Date.now
        let participantID = "TESTER01"
        let value = false
        
        // Act
        let ballotEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotEntity(id: MockData.generateBallotID())
        }
        
        let ballotChoiceEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotChoiceEntity(ballotEntity: ballotEntity)
        }
        
        // Count only encrypt calls while saving `BallotResultEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let ballotResultEntity = entityManager.performAndWaitSave {
            BallotResultEntity(
                context: testDatabase.context.main,
                createDate: createDate,
                modifyDate: modifyDate,
                participantID: participantID,
                value: value,
                ballotChoice: ballotChoiceEntity
            )
        }

        let fetchedBallotResultEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotResultEntity.objectID) as? BallotResultEntity
        )
        
        // Assert
        XCTAssertEqual(createDate, fetchedBallotResultEntity.createDate)
        XCTAssertEqual(modifyDate, fetchedBallotResultEntity.modifyDate)
        XCTAssertEqual(participantID, fetchedBallotResultEntity.participantID)
        XCTAssertEqual(value, fetchedBallotResultEntity.value?.boolValue)
        XCTAssertEqual(ballotChoiceEntity.objectID, fetchedBallotResultEntity.ballotChoice.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 3)

            // Test faulting
            testDatabase.context.main.refresh(fetchedBallotResultEntity, mergeChanges: false)

            XCTAssertEqual(createDate, fetchedBallotResultEntity.createDate)
            XCTAssertEqual(
                modifyDate.timeIntervalSince1970,
                fetchedBallotResultEntity.modifyDate?.timeIntervalSince1970
            )
            XCTAssertEqual(value, fetchedBallotResultEntity.value?.boolValue)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 3)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 3)
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

        let participantID = "TESTER01"
        
        // Act
        let ballotEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotEntity(id: MockData.generateBallotID())
        }
        
        let ballotChoiceEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotChoiceEntity(ballotEntity: ballotEntity)
        }
        
        let ballotResultEntity = entityManager.performAndWaitSave {
            BallotResultEntity(
                context: testDatabase.context.main,
                participantID: participantID,
                ballotChoice: ballotChoiceEntity
            )
        }
        
        let fetchedBallotResultEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotResultEntity.objectID) as? BallotResultEntity
        )
        
        // Assert
        XCTAssertEqual(participantID, fetchedBallotResultEntity.participantID)
        XCTAssertEqual(ballotChoiceEntity.objectID, fetchedBallotResultEntity.ballotChoice.objectID)
    }
}
