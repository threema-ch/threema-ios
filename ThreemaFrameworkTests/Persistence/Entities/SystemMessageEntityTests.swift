import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class SystemMessageEntityTests: XCTestCase {
    
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

        let messageID = BytesUtility.generateMessageID()
        let isOwn = true
        let arg = String("TestArg").data(using: .utf8)
        let type = SystemMessageEntity.SystemMessageEntityType.renameGroup

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        // Count only encrypt calls while saving `SystemMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let systemMessageEntity = entityManager.performAndWaitSave {
            SystemMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                arg: arg,
                type: Int16(type.rawValue),
                conversation: conversation
            )
        }

        let fetchedSystemMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: systemMessageEntity.objectID) as? SystemMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedSystemMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedSystemMessageEntity.isOwnMessage)
        XCTAssertEqual(arg, fetchedSystemMessageEntity.arg)
        XCTAssertEqual(type.rawValue, fetchedSystemMessageEntity.type.intValue)
        XCTAssertEqual(conversation.objectID, fetchedSystemMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                6
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedSystemMessageEntity, mergeChanges: false)

            XCTAssertEqual(arg, fetchedSystemMessageEntity.arg)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 1)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                6
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

        let messageID = BytesUtility.generateMessageID()
        let isOwn = true
        let type = 1
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let systemMessageEntity = entityManager.performAndWaitSave {
            SystemMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                type: Int16(type),
                conversation: conversation
            )
        }

        let fetchedSystemMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: systemMessageEntity.objectID) as? SystemMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedSystemMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedSystemMessageEntity.isOwnMessage)
        XCTAssertEqual(type, fetchedSystemMessageEntity.type.intValue)
        XCTAssertEqual(conversation.objectID, fetchedSystemMessageEntity.conversation.objectID)
    }
}
