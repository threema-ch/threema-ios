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

import XCTest
@testable import ThreemaFramework

final class DistributionListEntityTests: XCTestCase {
    
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
        let id: Int64 = 10
        let name = "Test"
        
        let entityManager = EntityManager(databaseContext: dbContext)

        // Act
        let conversation = try entityManager.performAndWaitSave {
            let conversation = try XCTUnwrap(entityManager.entityCreator.conversationEntity(true))
            return conversation
        }
        
        let distributionListEntity = try entityManager.performAndWaitSave {
            let distributionListEntity = try XCTUnwrap(entityManager.entityCreator.distributionListEntity())
            
            distributionListEntity.distributionListID = id
            distributionListEntity.name = name

            distributionListEntity.conversation = conversation
           
            return distributionListEntity
        }

        let fetchedDistributionListEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: distributionListEntity.objectID) as? DistributionListEntity
        )
        
        // Assert
        XCTAssertEqual(id, fetchedDistributionListEntity.distributionListID)
        XCTAssertEqual(NSNumber(integerLiteral: Int(id)), fetchedDistributionListEntity.distributionListIDObjC)
        XCTAssertEqual(name, fetchedDistributionListEntity.name)

        XCTAssertEqual(conversation.objectID, fetchedDistributionListEntity.conversation.objectID)
    }
}
