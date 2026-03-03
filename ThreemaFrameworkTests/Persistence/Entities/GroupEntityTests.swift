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

final class GroupEntityTests: XCTestCase {
    
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

        let groupCreator = "TESTERID"
        let groupID = MockData.generateGroupID()
        let lastPeriodicSync = Date.distantPast
        let state = 0

        // Act
        let groupEntity = entityManager.performAndWaitSave {
            GroupEntity(
                context: testDatabase.context.main,
                groupCreator: groupCreator,
                groupID: groupID,
                lastPeriodicSync: lastPeriodicSync,
                state: state as NSNumber
            )
        }

        let fetchedGroupEntity = try XCTUnwrap(
            entityManager.entityFetcher.existingObject(with: groupEntity.objectID) as? GroupEntity
        )
        
        // Assert
        XCTAssertEqual(groupCreator, fetchedGroupEntity.groupCreator)
        XCTAssertEqual(groupID, fetchedGroupEntity.groupID)
        XCTAssertEqual(
            lastPeriodicSync,
            fetchedGroupEntity.lastPeriodicSync
        )
        XCTAssertEqual(state as NSNumber, fetchedGroupEntity.state)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedGroupEntity, mergeChanges: false)

            XCTAssertEqual(
                lastPeriodicSync,
                fetchedGroupEntity.lastPeriodicSync
            )

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)
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

        let groupID = MockData.generateGroupID()
        let state = 0

        // Act
        let groupEntity = entityManager.performAndWaitSave {
            GroupEntity(
                context: testDatabase.context.main,
                groupID: groupID,
                state: 0
            )
        }

        let fetchedGroupEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupEntity.objectID) as? GroupEntity
        )
        
        // Assert
        XCTAssertEqual(groupID, fetchedGroupEntity.groupID)
        XCTAssertEqual(state as NSNumber, fetchedGroupEntity.state)
    }
}
