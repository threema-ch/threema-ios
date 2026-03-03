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

final class GroupCallEntityTests: XCTestCase {
    
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

        let gck = MockData.generateGCK()
        let protocolVersion = Int32(32)
        let sfuBaseURL = "fakeURL"
        let startMessageReceiveDate = Date.now
        
        // Act
        let groupEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.groupEntity(groupID: MockData.generateGroupID(), state: 0)
        }
        
        // Count only encrypt calls while saving `GroupCallEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let groupCallEntity = entityManager.performAndWaitSave {
            GroupCallEntity(
                context: testDatabase.context.main,
                gck: gck,
                protocolVersion: protocolVersion,
                sfuBaseURL: sfuBaseURL,
                startMessageReceiveDate: startMessageReceiveDate,
                group: groupEntity
            )
        }

        let fetchedGroupCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupCallEntity.objectID) as? GroupCallEntity
        )
        
        // Assert
        XCTAssertEqual(gck, fetchedGroupCallEntity.gck)
        XCTAssertEqual(protocolVersion, try Int32(truncating: XCTUnwrap(fetchedGroupCallEntity.protocolVersion)))
        XCTAssertEqual(sfuBaseURL, fetchedGroupCallEntity.sfuBaseURL)
        XCTAssertEqual(
            startMessageReceiveDate,
            fetchedGroupCallEntity.startMessageReceiveDate
        )
        XCTAssertEqual(groupEntity.objectID, fetchedGroupCallEntity.group?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 4)

            // Test faulting
            testDatabase.context.main.refresh(fetchedGroupCallEntity, mergeChanges: false)

            XCTAssertEqual(gck, fetchedGroupCallEntity.gck)
            XCTAssertEqual(protocolVersion, try Int32(truncating: XCTUnwrap(fetchedGroupCallEntity.protocolVersion)))
            XCTAssertEqual(sfuBaseURL, fetchedGroupCallEntity.sfuBaseURL)
            XCTAssertEqual(
                startMessageReceiveDate.timeIntervalSince1970,
                fetchedGroupCallEntity.startMessageReceiveDate?.timeIntervalSince1970
            )

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 4)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 4)
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

        // Act
        let groupCallEntity = entityManager.performAndWaitSave {
            GroupCallEntity(context: testDatabase.context.main)
        }

        let fetchedGroupCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupCallEntity.objectID) as? GroupCallEntity
        )
        
        // Assert
        XCTAssertNotNil(fetchedGroupCallEntity)
    }
}
