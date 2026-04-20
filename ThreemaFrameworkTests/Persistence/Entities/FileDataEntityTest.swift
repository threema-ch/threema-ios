import RemoteSecretProtocolTestHelper
import ThreemaEssentials

import XCTest
@testable import ThreemaFramework

final class FileDataEntityTests: XCTestCase {
    
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

        let data = BytesUtility.generateRandomBytes(length: 32)
        
        // Act
        let fileMessageEntity = entityManager.performAndWaitSave {
            let conversation = entityManager.entityCreator.conversationEntity()
            
            return FileMessageEntity(
                context: testDatabase.context.main,
                id: BytesUtility.generateMessageID(),
                isOwn: true,
                conversation: conversation
            )
        }
        
        // Count only encrypt calls while saving `FileDataEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let fileDataEntity = entityManager.performAndWaitSave {
            FileDataEntity(context: testDatabase.context.main, data: data, message: fileMessageEntity)
        }

        let fetchedFileDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: fileDataEntity.objectID) as? FileDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedFileDataEntity.data)
        XCTAssertEqual(fileMessageEntity.objectID, fetchedFileDataEntity.message?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedFileDataEntity, mergeChanges: false)

            XCTAssertEqual(data, fetchedFileDataEntity.data)
            
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

        let data = BytesUtility.generateRandomBytes(length: 32)
        
        // Act
        let fileDataEntity = entityManager.performAndWaitSave {
            FileDataEntity(context: testDatabase.context.main, data: data)
        }

        let fetchedFileDataEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: fileDataEntity.objectID) as? FileDataEntity
        )
        
        // Assert
        XCTAssertEqual(data, fetchedFileDataEntity.data)
    }
}
