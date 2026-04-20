import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class GroupEntityTests: XCTestCase {
    
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

        let groupCreator = "TESTERID"
        let groupID = BytesUtility.generateGroupID()
        let lastPeriodicSync = Date.distantPast
        let state = 0

        // Act
        let groupEntity = entityManager.performAndWaitSave {
            GroupEntity(
                context: testDatabase.context.main,
                groupCreator: groupCreator,
                groupID: groupID,
                lastPeriodicSync: lastPeriodicSync,
                state: state as NSNumber
            )
        }

        let fetchedGroupEntity = try XCTUnwrap(
            entityManager.entityFetcher.existingObject(with: groupEntity.objectID) as? GroupEntity
        )
        
        // Assert
        XCTAssertEqual(groupCreator, fetchedGroupEntity.groupCreator)
        XCTAssertEqual(groupID, fetchedGroupEntity.groupID)
        XCTAssertEqual(
            lastPeriodicSync,
            fetchedGroupEntity.lastPeriodicSync
        )
        XCTAssertEqual(state as NSNumber, fetchedGroupEntity.state)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 1)

            // Test faulting
            testDatabase.context.main.refresh(fetchedGroupEntity, mergeChanges: false)

            XCTAssertEqual(
                lastPeriodicSync,
                fetchedGroupEntity.lastPeriodicSync
            )

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

        let groupID = BytesUtility.generateGroupID()
        let state = 0

        // Act
        let groupEntity = entityManager.performAndWaitSave {
            GroupEntity(
                context: testDatabase.context.main,
                groupID: groupID,
                state: 0
            )
        }

        let fetchedGroupEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupEntity.objectID) as? GroupEntity
        )
        
        // Assert
        XCTAssertEqual(groupID, fetchedGroupEntity.groupID)
        XCTAssertEqual(state as NSNumber, fetchedGroupEntity.state)
    }
}
