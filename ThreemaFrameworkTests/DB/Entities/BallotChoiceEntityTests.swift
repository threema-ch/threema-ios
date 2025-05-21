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

import XCTest
@testable import ThreemaFramework

final class BallotChoiceEntityTests: XCTestCase {
    
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
        let createDate = Date.now
        let id = NSNumber(integerLiteral: 0)
        let modifyDate = Date.now
        let name = "Test Choice"
        let orderPosition = NSNumber(integerLiteral: 1)
        let totalVotes = NSNumber(integerLiteral: 2)

        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        let ballotEntity = try entityManager.performAndWaitSave {
            let ballotEntity =
                try XCTUnwrap(entityManager.entityCreator.ballot())
            
            ballotEntity.id = MockData.generateBallotID()
            
            return ballotEntity
        }
        
        let ballotChoiceEntity = try entityManager.performAndWaitSave {
            let ballotChoiceEntity =
                try XCTUnwrap(entityManager.entityCreator.ballotChoice())
            
            ballotChoiceEntity.createDate = createDate
            ballotChoiceEntity.id = id
            ballotChoiceEntity.modifyDate = modifyDate
            ballotChoiceEntity.name = name
            ballotChoiceEntity.orderPosition = orderPosition
            ballotChoiceEntity.totalVotes = totalVotes
            
            ballotChoiceEntity.ballot = ballotEntity
            
            return ballotChoiceEntity
        }
        
        let fetchedBallotChoiceEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotChoiceEntity.objectID) as? BallotChoiceEntity
        )
        
        // Assert
        XCTAssertEqual(createDate, fetchedBallotChoiceEntity.createDate)
        XCTAssertEqual(id, fetchedBallotChoiceEntity.id)
        XCTAssertEqual(modifyDate, fetchedBallotChoiceEntity.modifyDate)
        XCTAssertEqual(name, fetchedBallotChoiceEntity.name)
        XCTAssertEqual(orderPosition, fetchedBallotChoiceEntity.orderPosition)
        XCTAssertEqual(totalVotes, fetchedBallotChoiceEntity.totalVotes)
    }
}
