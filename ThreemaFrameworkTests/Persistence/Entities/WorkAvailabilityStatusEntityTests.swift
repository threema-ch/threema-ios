import Foundation
import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class WorkAvailabilityStatusEntityTests: XCTestCase {
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

        let contactID = "TESTER01"

        let value = 1
        let text = "Custom Text"
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let workAvailabilityStatusEntity = entityManager.performAndWaitSave {
            WorkAvailabilityStatusEntity(
                context: testDatabase.context.main,
                value: value,
                text: text,
                contact: contactEntity
            )
        }

        let fetchedWorkAvailabilityStatusEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: workAvailabilityStatusEntity.objectID) as? WorkAvailabilityStatusEntity
        )
        
        // Assert
        XCTAssertEqual(value, fetchedWorkAvailabilityStatusEntity.value.intValue)
        XCTAssertEqual(text, fetchedWorkAvailabilityStatusEntity.text)

        XCTAssertEqual(contactEntity.objectID, fetchedWorkAvailabilityStatusEntity.contact.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
            ) // Plus 5 `ContactEntity` fields

            // Test faulting
            testDatabase.context.main.refresh(fetchedWorkAvailabilityStatusEntity, mergeChanges: false)

            XCTAssertEqual(value, fetchedWorkAvailabilityStatusEntity.value.intValue)
            XCTAssertEqual(text, fetchedWorkAvailabilityStatusEntity.text)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 2)
            XCTAssertEqual(
                testDatabase.remoteSecretCryptoMock.encryptCalls,
                7
            )
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

        let contactID = "TESTER01"

        let value = 1
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let workAvailabilityStatusEntity = entityManager.performAndWaitSave {
            WorkAvailabilityStatusEntity(
                context: testDatabase.context.main,
                value: value,
                contact: contactEntity
            )
        }

        let fetchedWorkAvailabilityStatusEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: workAvailabilityStatusEntity.objectID) as? WorkAvailabilityStatusEntity
        )
        
        // Assert
        XCTAssertEqual(value, fetchedWorkAvailabilityStatusEntity.value.intValue)
        XCTAssertEqual(contactEntity.objectID, fetchedWorkAvailabilityStatusEntity.contact.objectID)
    }
    
    func testTrimmingText() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let contactID = "TESTER01"

        let value = 1
        let text = " Multiline Text \n "
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let workAvailabilityStatusEntity = entityManager.performAndWaitSave {
            WorkAvailabilityStatusEntity(
                context: testDatabase.context.main,
                value: value,
                text: text,
                contact: contactEntity
            )
        }

        let fetchedWorkAvailabilityStatusEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: workAvailabilityStatusEntity.objectID) as? WorkAvailabilityStatusEntity
        )
        XCTAssertEqual("Multiline Text", fetchedWorkAvailabilityStatusEntity.text)

        // Assert
        XCTAssertEqual(value, fetchedWorkAvailabilityStatusEntity.value.intValue)
        XCTAssertEqual(contactEntity.objectID, fetchedWorkAvailabilityStatusEntity.contact.objectID)
    }
    
    func testTrimmingTextNil() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let entityManager = testDatabase.entityManager

        let contactID = "TESTER01"

        let value = 1
        let text = " \n "
        
        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let workAvailabilityStatusEntity = entityManager.performAndWaitSave {
            WorkAvailabilityStatusEntity(
                context: testDatabase.context.main,
                value: value,
                text: text,
                contact: contactEntity
            )
        }

        let fetchedWorkAvailabilityStatusEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: workAvailabilityStatusEntity.objectID) as? WorkAvailabilityStatusEntity
        )
        XCTAssertEqual(nil, fetchedWorkAvailabilityStatusEntity.text)

        // Assert
        XCTAssertEqual(value, fetchedWorkAvailabilityStatusEntity.value.intValue)
        XCTAssertEqual(contactEntity.objectID, fetchedWorkAvailabilityStatusEntity.contact.objectID)
    }
}
