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
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class DistributionListEntityTests: XCTestCase {
    
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

        let id: Int64 = 10
        let name = "Test"
        
        // Act
        let conversationEntity = entityManager.performAndWaitSave {
            let conversationEntity = entityManager.entityCreator.conversationEntity()
            return conversationEntity
        }

        // Count only encrypt calls while saving `DistributionListEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let distributionListEntity = entityManager.performAndWaitSave {
            DistributionListEntity(
                context: testDatabase.context.main,
                distributionListID: id,
                name: name,
                conversation: conversationEntity
            )
        }

        let fetchedDistributionListEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: distributionListEntity.objectID) as? DistributionListEntity
        )
        
        // Assert
        XCTAssertEqual(id, fetchedDistributionListEntity.distributionListID)
        XCTAssertEqual(NSNumber(integerLiteral: Int(id)), fetchedDistributionListEntity.distributionListIDObjC)
        XCTAssertEqual(name, fetchedDistributionListEntity.name)
        XCTAssertEqual(conversationEntity.objectID, fetchedDistributionListEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedDistributionListEntity, mergeChanges: false)
            XCTAssertEqual(name, fetchedDistributionListEntity.name)
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

        let id: Int64 = 10
        
        // Act
        let conversationEntity = entityManager.performAndWaitSave {
            let conversationEntity = entityManager.entityCreator.conversationEntity()
            return conversationEntity
        }
        
        let distributionListEntity = entityManager.performAndWaitSave {
            DistributionListEntity(
                context: testDatabase.context.main,
                distributionListID: id,
                conversation: conversationEntity
            )
        }

        let fetchedDistributionListEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: distributionListEntity.objectID) as? DistributionListEntity
        )
        
        // Assert
        XCTAssertEqual(id, fetchedDistributionListEntity.distributionListID)
        XCTAssertEqual(NSNumber(integerLiteral: Int(id)), fetchedDistributionListEntity.distributionListIDObjC)
        XCTAssertEqual(conversationEntity.objectID, fetchedDistributionListEntity.conversation.objectID)
    }
}
