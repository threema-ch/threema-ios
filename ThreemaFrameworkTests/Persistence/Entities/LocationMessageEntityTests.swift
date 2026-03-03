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

import Foundation
import RemoteSecretProtocolTestHelper
import ThreemaEssentialsTestHelper
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class LocationMessageEntityTests: XCTestCase {
    
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

        let messageID = MockData.generateMessageID()
        let isOwn = true
        let accuracy = 100.0
        let latitude = 1.0
        let longitude = 2.0
        let poiAddress = "Address"
        let poiName = "Name"
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        // Count only encrypt calls while saving `LocationMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let locationMessageEntity = entityManager.performAndWaitSave {
            LocationMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                accuracy: accuracy,
                latitude: latitude,
                longitude: longitude,
                poiAddress: poiAddress,
                poiName: poiName,
                conversation: conversation
            )
        }

        let fetchedLocationMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: locationMessageEntity.objectID) as? LocationMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedLocationMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedLocationMessageEntity.isOwnMessage)
        XCTAssertEqual(accuracy, fetchedLocationMessageEntity.accuracy?.doubleValue)
        XCTAssertEqual(latitude, fetchedLocationMessageEntity.latitude.doubleValue)
        XCTAssertEqual(longitude, fetchedLocationMessageEntity.longitude.doubleValue)
        XCTAssertEqual(poiAddress, fetchedLocationMessageEntity.poiAddress)
        XCTAssertEqual(poiName, fetchedLocationMessageEntity.poiName)
        XCTAssertEqual(conversation.objectID, fetchedLocationMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                10
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedLocationMessageEntity, mergeChanges: false)

            XCTAssertEqual(accuracy, fetchedLocationMessageEntity.accuracy?.doubleValue)
            XCTAssertEqual(latitude, fetchedLocationMessageEntity.latitude.doubleValue)
            XCTAssertEqual(longitude, fetchedLocationMessageEntity.longitude.doubleValue)
            XCTAssertEqual(poiAddress, fetchedLocationMessageEntity.poiAddress)
            XCTAssertEqual(poiName, fetchedLocationMessageEntity.poiName)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 5)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                10
            ) // Plus 5 `BaseMessageEntity` fields
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

        let messageID = MockData.generateMessageID()
        let isOwn = true
        let latitude = 1.0
        let longitude = 2.0
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let locationMessageEntity = entityManager.performAndWaitSave {
            LocationMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                latitude: latitude,
                longitude: longitude,
                conversation: conversation
            )
        }

        let fetchedLocationMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: locationMessageEntity.objectID) as? LocationMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedLocationMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedLocationMessageEntity.isOwnMessage)
        XCTAssertEqual(latitude, fetchedLocationMessageEntity.latitude.doubleValue)
        XCTAssertEqual(longitude, fetchedLocationMessageEntity.longitude.doubleValue)
        XCTAssertEqual(conversation.objectID, fetchedLocationMessageEntity.conversation.objectID)
    }
}
