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

final class LastGroupSyncRequestEntityTests: XCTestCase {
    
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
        let groupCreator = "TESTER01"
        let groupID = MockData.generateGroupID()
        let lastSyncRequest = Date.now
        let entityManager = EntityManager(databaseContext: dbContext)

        // Act
        let lastGroupSyncRequestEntity = try entityManager.performAndWaitSave {
            let lastGroupSyncRequestEntity = try XCTUnwrap(entityManager.entityCreator.lastGroupSyncRequestEntity())
            
            lastGroupSyncRequestEntity.groupCreator = groupCreator
            // swiftformat:disable:next acronyms
            lastGroupSyncRequestEntity.groupId = groupID
            lastGroupSyncRequestEntity.lastSyncRequest = lastSyncRequest

            return lastGroupSyncRequestEntity
        }

        let fetchedLastGroupSyncRequestEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: lastGroupSyncRequestEntity.objectID) as? LastGroupSyncRequestEntity
        )
        
        // Assert
        XCTAssertEqual(groupCreator, fetchedLastGroupSyncRequestEntity.groupCreator)
        // swiftformat:disable:next acronyms
        XCTAssertEqual(groupID, fetchedLastGroupSyncRequestEntity.groupId)
        XCTAssertEqual(lastSyncRequest, fetchedLastGroupSyncRequestEntity.lastSyncRequest)
    }
}
