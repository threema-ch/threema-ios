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

final class BallotEntityTests: XCTestCase {
    
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
        let assessmentType = BallotEntity.BallotAssessmentType.multi
        let choicesType = 0
        let createDate = Date.now
        let creatorID = "TESTER01"
        let displayMode = BallotEntity.BallotDisplayMode.list
        let id = MockData.generateBallotID()
        let modifyDate = Date.now
        let status = BallotEntity.BallotState.open
        let title = "Test Ballot"
        let type = BallotEntity.BallotType.closed
        
        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        let ballotEntity = try entityManager.performAndWaitSave {
            let ballotEntity =
                try XCTUnwrap(entityManager.entityCreator.ballot())
            
            ballotEntity.assessmentType = NSNumber(integerLiteral: assessmentType.rawValue)
            ballotEntity.choicesType = NSNumber(integerLiteral: choicesType)
            ballotEntity.createDate = createDate
            // swiftformat:disable:next acronyms
            ballotEntity.creatorId = creatorID
            ballotEntity.displayMode = NSNumber(integerLiteral: displayMode.rawValue)
            ballotEntity.id = id
            ballotEntity.modifyDate = modifyDate
            ballotEntity.state = NSNumber(integerLiteral: status.rawValue)
            ballotEntity.title = title
            ballotEntity.type = NSNumber(integerLiteral: type.rawValue)
            
            return ballotEntity
        }
        
        let fetchedBallotEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotEntity.objectID) as? BallotEntity
        )
        
        // Assert
        XCTAssertEqual(NSNumber(integerLiteral: assessmentType.rawValue), fetchedBallotEntity.assessmentType)
        XCTAssertEqual(NSNumber(integerLiteral: choicesType), fetchedBallotEntity.choicesType)
        XCTAssertEqual(createDate, fetchedBallotEntity.createDate)
        // swiftformat:disable:next acronyms
        XCTAssertEqual(creatorID, fetchedBallotEntity.creatorId)
        XCTAssertEqual(NSNumber(integerLiteral: displayMode.rawValue), fetchedBallotEntity.displayMode)
        XCTAssertEqual(id, fetchedBallotEntity.id)
        XCTAssertEqual(modifyDate, fetchedBallotEntity.modifyDate)
        XCTAssertEqual(NSNumber(integerLiteral: type.rawValue), fetchedBallotEntity.state)
        XCTAssertEqual(title, fetchedBallotEntity.title)
        XCTAssertEqual(NSNumber(integerLiteral: type.rawValue), fetchedBallotEntity.type)
    }
}
