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

final class AudioMessageEntityTests: XCTestCase {
    
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
        let testBundle = Bundle(for: AudioDataEntityTests.self)
        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))
        let data = try XCTUnwrap(Data(contentsOf: testVoiceURL))
        let audioBlobID = MockData.generateBlobID()
        let audioSize: NSNumber = 256
        let duration: NSNumber = 10
        let encryptionKey = MockData.generateBlobEncryptionKey()
        let progress: NSNumber = 0.75
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
        
        let audioDataEntity = try entityManager.performAndWaitSave {
            let audioDataEntity = try XCTUnwrap(entityManager.entityCreator.audioDataEntity())
            
            audioDataEntity.data = data
           
            return audioDataEntity
        }
        
        let audioMessageEntity = try entityManager.performAndWaitSave {
            let audioMessageEntity = try XCTUnwrap(entityManager.entityCreator.audioMessageEntity(for: conversation))
            
            // swiftformat:disable:next acronyms
            audioMessageEntity.audioBlobId = audioBlobID
            audioMessageEntity.audioSize = audioSize
            audioMessageEntity.duration = duration
            audioMessageEntity.encryptionKey = encryptionKey
            audioMessageEntity.progress = progress
            
            audioMessageEntity.audio = audioDataEntity
           
            return audioMessageEntity
        }

        let fetchedAudioMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: audioMessageEntity.objectID) as? AudioMessageEntity
        )
        
        // Assert
        // swiftformat:disable:next acronyms
        XCTAssertEqual(audioBlobID, fetchedAudioMessageEntity.audioBlobId)
        XCTAssertEqual(audioSize, fetchedAudioMessageEntity.audioSize)
        XCTAssertEqual(duration, fetchedAudioMessageEntity.duration)
        XCTAssertEqual(encryptionKey, fetchedAudioMessageEntity.encryptionKey)
        XCTAssertEqual(progress, fetchedAudioMessageEntity.progress)

        XCTAssertEqual(audioDataEntity.objectID, fetchedAudioMessageEntity.audio?.objectID)
    }
}
