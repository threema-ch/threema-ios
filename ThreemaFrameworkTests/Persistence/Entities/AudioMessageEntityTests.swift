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

final class AudioMessageEntityTests: XCTestCase {
    
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
        let testBundle = Bundle(for: AudioMessageEntityTests.self)
        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))
        let data = try XCTUnwrap(Data(contentsOf: testVoiceURL))
        let audioBlobID = MockData.generateBlobID()
        let audioSize: NSNumber = 256
        let duration: NSNumber = 10
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }

        let audioDataEntity = entityManager.performAndWaitSave {
            let audioDataEntity = entityManager.entityCreator.audioDataEntity(data: data)
            return audioDataEntity
        }

        // Count only encrypt calls while saving `AudioMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let audioMessageEntity = entityManager.performAndWaitSave {
            AudioMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                audioBlobID: audioBlobID,
                audioSize: UInt32(truncating: audioSize),
                duration: Float(truncating: duration),
                encryptionKey: encryptionKey,
                progress: Float(truncating: progress),
                conversation: conversation,
                audio: audioDataEntity
            )
        }

        let fetchedAudioMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: audioMessageEntity.objectID) as? AudioMessageEntity
        )

        // Assert
        XCTAssertEqual(messageID, fetchedAudioMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedAudioMessageEntity.isOwnMessage)
        XCTAssertEqual(audioBlobID, fetchedAudioMessageEntity.audioBlobID)
        XCTAssertEqual(audioSize, fetchedAudioMessageEntity.audioSize)
        XCTAssertEqual(duration, fetchedAudioMessageEntity.duration)
        XCTAssertEqual(encryptionKey, fetchedAudioMessageEntity.encryptionKey)
        XCTAssertEqual(progress, fetchedAudioMessageEntity.progress)
        XCTAssertEqual(conversation.objectID, fetchedAudioMessageEntity.conversation.objectID)
        XCTAssertEqual(audioDataEntity.objectID, fetchedAudioMessageEntity.audio?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 9) // Plus 5 of `BaseMessageEntity`

            // Test faulting
            testDatabase.context.main.refresh(fetchedAudioMessageEntity, mergeChanges: false)

            XCTAssertEqual(audioBlobID, fetchedAudioMessageEntity.audioBlobID)
            XCTAssertEqual(audioSize, fetchedAudioMessageEntity.audioSize)
            XCTAssertEqual(duration, fetchedAudioMessageEntity.duration)
            XCTAssertEqual(encryptionKey, fetchedAudioMessageEntity.encryptionKey)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 4)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 9) // Plus 5 of `BaseMessageEntity`
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
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let audioMessageEntity = entityManager.performAndWaitSave {
            AudioMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                conversation: conversation
            )
        }

        let fetchedAudioMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher.existingObject(with: audioMessageEntity.objectID) as? AudioMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedAudioMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedAudioMessageEntity.isOwnMessage)
        XCTAssertEqual(conversation.objectID, fetchedAudioMessageEntity.conversation.objectID)
    }
}
