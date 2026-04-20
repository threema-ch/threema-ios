import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class TextMessageEntityTests: XCTestCase {
    
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
        let text = "Test Text"
        let quoteID = BytesUtility.generateMessageID()

        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }

        // Count only encrypt calls while saving `TextMessageEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let textMessageEntity = entityManager.performAndWaitSave {
            TextMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                text: text,
                quotedMessageID: quoteID,
                conversation: conversation
            )
        }

        let fetchedTextMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: textMessageEntity.objectID) as? TextMessageEntity
        )

        // Assert
        XCTAssertEqual(messageID, fetchedTextMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedTextMessageEntity.isOwnMessage)
        XCTAssertEqual(text, fetchedTextMessageEntity.text)
        XCTAssertEqual(quoteID, fetchedTextMessageEntity.quotedMessageID)
        XCTAssertEqual(conversation.objectID, fetchedTextMessageEntity.conversation.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
            ) // Plus 5 `BaseMessageEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedTextMessageEntity, mergeChanges: false)

            XCTAssertEqual(text, fetchedTextMessageEntity.text)
            XCTAssertEqual(quoteID, fetchedTextMessageEntity.quotedMessageID)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 2)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
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
        let text = "Test Text"
        
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
                
        let textMessageEntity = entityManager.performAndWaitSave {
            TextMessageEntity(
                context: testDatabase.context.main,
                id: messageID,
                isOwn: isOwn,
                text: text,
                conversation: conversation
            )
        }

        let fetchedTextMessageEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: textMessageEntity.objectID) as? TextMessageEntity
        )
        
        // Assert
        XCTAssertEqual(messageID, fetchedTextMessageEntity.id)
        XCTAssertEqual(isOwn, fetchedTextMessageEntity.isOwnMessage)
        XCTAssertEqual(text, fetchedTextMessageEntity.text)
        XCTAssertEqual(conversation.objectID, fetchedTextMessageEntity.conversation.objectID)
    }
}
