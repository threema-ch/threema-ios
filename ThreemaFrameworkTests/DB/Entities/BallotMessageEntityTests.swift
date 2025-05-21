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

final class BallotMessageEntityTests: XCTestCase {
    
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
        let contactID = "TESTER01"
        let ballotState = NSNumber(integerLiteral: 0)

        let entityManager = EntityManager(databaseContext: dbContext)
        
        // Act
        entityManager.performAndWaitSave {
            let contact = entityManager.entityCreator.contact()
            contact?.setIdentity(to: contactID)
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let conversation = entityManager.performAndWaitSave {
            let contact = entityManager.entityFetcher.contact(for: contactID)!
            return entityManager.conversation(forContact: contact, createIfNotExisting: true)
        }
        
        let ballotEntity = try entityManager.performAndWaitSave {
            let ballotEntity =
                try XCTUnwrap(entityManager.entityCreator.ballot())
            
            ballotEntity.id = MockData.generateBallotID()
            return ballotEntity
        }
        
        let ballotMessageEntity = try entityManager.performAndWaitSave {
            let ballotMessageEntity =
                try XCTUnwrap(entityManager.entityCreator.ballotMessage(for: conversation))
            
            ballotMessageEntity.ballotState = ballotState
            ballotMessageEntity.updateBallot(ballotEntity)
            return ballotMessageEntity
        }
        
        let fetchedBallotMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotMessageEntity.objectID) as? BallotMessageEntity
        )
        
        // Assert
        XCTAssertEqual(ballotState, fetchedBallotMessageEntity.ballotState)
        XCTAssertEqual(ballotEntity, fetchedBallotMessageEntity.ballot)
    }
}
