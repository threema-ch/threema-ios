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

import ThreemaEssentials
import ThreemaEssentialsTestHelper
import XCTest
@testable import ThreemaFramework

final class LastGroupSyncRequestEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var testDatabase: TestDatabase!

    // MARK: - Setup

    override func setUpWithError() throws {
        testDatabase = TestDatabase()
    }
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let groupCreator = "TESTER01"
        let groupID = MockData.generateGroupID()
        let lastSyncRequest = Date.now
        let entityManager = testDatabase.entityManager

        // Act
        let lastGroupSyncRequestEntity = entityManager.performAndWaitSave {
            LastGroupSyncRequestEntity(
                context: self.testDatabase.context.main,
                groupCreator: groupCreator,
                groupID: groupID,
                lastSyncRequest: lastSyncRequest
            )
        }

        let fetchedLastGroupSyncRequestEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: lastGroupSyncRequestEntity.objectID) as? LastGroupSyncRequestEntity
        )
        
        // Assert
        XCTAssertEqual(groupCreator, fetchedLastGroupSyncRequestEntity.groupCreator)
        XCTAssertEqual(groupID, fetchedLastGroupSyncRequestEntity.groupID)
        XCTAssertEqual(lastSyncRequest, fetchedLastGroupSyncRequestEntity.lastSyncRequest)
    }
}
