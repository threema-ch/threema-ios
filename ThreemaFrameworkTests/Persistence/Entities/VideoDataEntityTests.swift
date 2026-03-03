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
@testable import ThreemaFramework

final class VideoDataEntityTests: XCTestCase {
    
    // MARK: - Properties

    private let testBundle = Bundle(for: VideoDataEntityTests.self)
    
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

        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let data = try XCTUnwrap(Data(contentsOf: testVideoURL))
       
        // Act
        let videoMessageEntity = entityManager.performAndWaitSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            
            return VideoMessageEntity(
                context: testDatabase.context.main,
                id: MockData.generateMessageID(),
                isOwn: true,
                conversation: conversation
            )
        }
        
        // Count only encrypt calls while saving `VideoDataEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let videoDataEntity = entityManager.performAndWaitSave {
            VideoDataEntity(context: testDatabase.context.main, data: data, message: videoMessageEntity)
        }
        
        let fetchedVideoDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: videoDataEntity.objectID) as? VideoDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedVideoDataEntity.data)
        XCTAssertEqual(videoMessageEntity.objectID, fetchedVideoDataEntity.message?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedVideoDataEntity, mergeChanges: false)

            XCTAssertEqual(data, fetchedVideoDataEntity.data)
            
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)
        }
    }

    func testCreationMinimal() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let data = try XCTUnwrap(Data(contentsOf: testVideoURL))
       
        // Act
        let videoDataEntity = entityManager.performAndWaitSave {
            VideoDataEntity(context: testDatabase.context.main, data: data)
        }
        
        let fetchedVideoDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: videoDataEntity.objectID) as? VideoDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedVideoDataEntity.data)
    }
}
