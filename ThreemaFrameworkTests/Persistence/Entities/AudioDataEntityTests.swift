import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class AudioDataEntityTests: XCTestCase {
    
    // MARK: - Properties

    private let testBundle = Bundle(for: AudioDataEntityTests.self)

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

        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))
        let data = try XCTUnwrap(Data(contentsOf: testVoiceURL))
        
        // Act
        let audioMessageEntity = entityManager.performAndWaitSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            
            return AudioMessageEntity(
                context: testDatabase.context.main,
                id: BytesUtility.generateMessageID(),
                isOwn: true,
                conversation: conversation
            )
        }

        // Count only encrypt calls while saving `AudioDataEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let audioDataEntity = entityManager.performAndWaitSave {
            AudioDataEntity(
                context: testDatabase.context.main,
                data: data,
                message: audioMessageEntity
            )
        }

        let fetchedAudioDataEntity = try XCTUnwrap(
            entityManager.entityFetcher.existingObject(with: audioDataEntity.objectID) as? AudioDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedAudioDataEntity.data)
        XCTAssertEqual(audioMessageEntity.objectID, fetchedAudioDataEntity.message?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedAudioDataEntity, mergeChanges: false)

            XCTAssertEqual(data, fetchedAudioDataEntity.data)

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

        let testVoiceURL = try XCTUnwrap(testBundle.url(forResource: "SmallVoice", withExtension: "mp3"))
        let data = try XCTUnwrap(Data(contentsOf: testVoiceURL))
        
        // Act
        let audioDataEntity = testDatabase.entityManager.performAndWaitSave {
            AudioDataEntity(
                context: testDatabase.context.main,
                data: data,
            )
        }

        let fetchedAudioDataEntity = try XCTUnwrap(
            testDatabase.entityManager.entityFetcher.existingObject(with: audioDataEntity.objectID) as? AudioDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedAudioDataEntity.data)
    }
}
