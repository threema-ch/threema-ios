import RemoteSecretProtocolTestHelper
import ThreemaEssentials

import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class ConversationEntityTests: XCTestCase {
    
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

        let category: ConversationEntity.Category = .private
        let groupID = BytesUtility.generateGroupID()
        let groupImageSetDate = Date.now
        let groupMyIdentity = "MYIDENTI"
        let groupName = "Group Name"
        let lastTypingStart = Date.now
        let lastUpdate = Date.now
        let typing = true
        let unreadMessageCount: NSNumber = 10
        let visibility: ConversationEntity.Visibility = .pinned

        // Act
        let imageDateEntity = entityManager.performAndWaitSave {
            ImageDataEntity(context: testDatabase.context.main, data: Data(), height: 1, width: 1)
        }
        let contactEntity = entityManager.performAndWaitSave {
            ContactEntity(
                context: testDatabase.context.main,
                identity: "TESTER01",
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: false
            )
        }
        let members: Set<ContactEntity> = entityManager.performAndWaitSave {
            [
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER02",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER03",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
                ContactEntity(
                    context: testDatabase.context.main,
                    identity: "TESTER04",
                    publicKey: BytesUtility.generatePublicKey(),
                    sortOrderFirstName: false
                ),
            ]
        }

        // Count only encrypt calls while saving `ConversationEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let conversationEntity = entityManager.performAndWaitSave {
            ConversationEntity(
                context: testDatabase.context.main,
                category: category,
                groupID: groupID,
                groupImageSetDate: groupImageSetDate,
                groupMyIdentity: groupMyIdentity,
                groupName: groupName,
                lastTypingStart: lastTypingStart,
                lastUpdate: lastUpdate,
                typing: typing,
                unreadMessageCount: unreadMessageCount,
                visibility: visibility,
                groupImage: imageDateEntity,
                lastMessage: nil,
                distributionList: nil,
                contact: contactEntity,
                members: members
            )
        }
        
        let fetchedConversationEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: conversationEntity.objectID) as? ConversationEntity
        )
        
        // Assert
        XCTAssertEqual(category, fetchedConversationEntity.conversationCategory)
        XCTAssertEqual(groupID, fetchedConversationEntity.groupID)
        XCTAssertEqual(
            groupImageSetDate,
            fetchedConversationEntity.groupImageSetDate
        )
        XCTAssertEqual(groupMyIdentity, fetchedConversationEntity.groupMyIdentity)
        XCTAssertEqual(groupName, fetchedConversationEntity.groupName)
        XCTAssertFalse(fetchedConversationEntity.marked.boolValue)
        XCTAssertEqual(lastUpdate, fetchedConversationEntity.lastUpdate)
        XCTAssertEqual(NSNumber(booleanLiteral: typing), fetchedConversationEntity.typing)
        XCTAssertEqual(unreadMessageCount, fetchedConversationEntity.unreadMessageCount)
        XCTAssertEqual(visibility, fetchedConversationEntity.conversationVisibility)
        XCTAssertEqual(imageDateEntity.objectID, fetchedConversationEntity.groupImage?.objectID)
        XCTAssertEqual(contactEntity.objectID, fetchedConversationEntity.contact?.objectID)
        XCTAssertEqual(members.count, fetchedConversationEntity.members?.count)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 2)

            // Test faulting
            testDatabase.context.main.refresh(fetchedConversationEntity, mergeChanges: false)

            XCTAssertEqual(groupName, fetchedConversationEntity.groupName)
            XCTAssertFalse(fetchedConversationEntity.marked.boolValue)
            
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 2)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 2)
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
        let conversationEntity = entityManager.performAndWaitSave {
            ConversationEntity(context: testDatabase.context.main)
        }
        
        let fetchedConversationEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: conversationEntity.objectID) as? ConversationEntity
        )
        
        // Assert
        XCTAssertNotNil(fetchedConversationEntity)
    }
}
