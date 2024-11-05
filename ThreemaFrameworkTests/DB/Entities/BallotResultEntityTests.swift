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

final class BallotResultEntityTests: XCTestCase {
    
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
        let createDate = Date.distantPast
        let modifyDate = Date.now
        let participantID = "TESTER01"
        let value = false
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        let ballotEntity = try entityManager.performAndWaitSave {
            let ballotEntity =
                try XCTUnwrap(entityManager.entityCreator.ballot())
            
            ballotEntity.id = MockData.generateBallotID()
            
            return ballotEntity
        }
        
        let ballotChoiceEntity = try entityManager.performAndWaitSave {
            let ballotChoiceEntity = try XCTUnwrap(entityManager.entityCreator.ballotChoice())
            
            ballotChoiceEntity.ballot = ballotEntity
            
            return ballotChoiceEntity
        }
        
        let ballotResultEntity = try entityManager.performAndWaitSave {
            let ballotResultEntity = try XCTUnwrap(entityManager.entityCreator.ballotResultEntity())
            
            ballotResultEntity.createDate = createDate
            ballotResultEntity.modifyDate = modifyDate
            // swiftformat:disable:next acronyms
            ballotResultEntity.participantId = participantID
            ballotResultEntity.value = NSNumber(booleanLiteral: value)
            
            ballotResultEntity.ballotChoice = ballotChoiceEntity
            
            return ballotResultEntity
        }
        
        let fetchedBallotResultEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotResultEntity.objectID) as? BallotResultEntity
        )
        
        // Assert
        XCTAssertEqual(createDate, fetchedBallotResultEntity.createDate)
        XCTAssertEqual(modifyDate, fetchedBallotResultEntity.modifyDate)
        // swiftformat:disable:next acronyms
        XCTAssertEqual(participantID, fetchedBallotResultEntity.participantId)
        XCTAssertEqual(value, fetchedBallotResultEntity.value?.boolValue)
        XCTAssertEqual(ballotChoiceEntity.objectID, fetchedBallotResultEntity.ballotChoice.objectID)
    }
}
