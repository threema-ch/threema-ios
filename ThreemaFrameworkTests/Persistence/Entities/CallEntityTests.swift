import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class CallEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var testDatabase: TestDatabase!

    // MARK: - Setup

    override func setUpWithError() throws {
        testDatabase = TestDatabase()
    }
    
    // MARK: - Tests

    func testCreationFull() throws {
        // Arrange
        let contactID = "TESTER01"
        let callID: NSNumber = 10
        let date = Date.now

        let entityManager = testDatabase.entityManager

        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let callEntity = entityManager.performAndWaitSave {
            CallEntity(
                context: self.testDatabase.context.main,
                callID: Int32(truncating: callID),
                date: date,
                contactEntity: contactEntity
            )
        }

        let fetchedCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: callEntity.objectID) as? CallEntity
        )
        
        // Assert
        XCTAssertEqual(callID, fetchedCallEntity.callID)
        XCTAssertEqual(date, fetchedCallEntity.date)
        XCTAssertEqual(contactEntity.objectID, fetchedCallEntity.contact?.objectID)
    }
    
    func testCreationMinimal() throws {
        // Arrange
        let contactID = "TESTER01"
        let entityManager = testDatabase.entityManager

        // Act
        let contactEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.contactEntity(
                identity: contactID,
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let callEntity = entityManager.performAndWaitSave {
            CallEntity(
                context: self.testDatabase.context.main,
                contactEntity: contactEntity
            )
        }

        let fetchedCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: callEntity.objectID) as? CallEntity
        )
        
        // Assert
        XCTAssertEqual(contactEntity.objectID, fetchedCallEntity.contact?.objectID)
    }
}
