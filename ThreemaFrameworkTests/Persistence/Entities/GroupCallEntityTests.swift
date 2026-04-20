import RemoteSecretProtocolTestHelper

import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class GroupCallEntityTests: XCTestCase {
    
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

        let gck = BytesUtility.generateGCK()
        let protocolVersion = Int32(32)
        let sfuBaseURL = "fakeURL"
        let startMessageReceiveDate = Date.now
        
        // Act
        let groupEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.groupEntity(groupID: BytesUtility.generateGroupID(), state: 0)
        }
        
        // Count only encrypt calls while saving `GroupCallEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let groupCallEntity = entityManager.performAndWaitSave {
            GroupCallEntity(
                context: testDatabase.context.main,
                gck: gck,
                protocolVersion: protocolVersion,
                sfuBaseURL: sfuBaseURL,
                startMessageReceiveDate: startMessageReceiveDate,
                group: groupEntity
            )
        }

        let fetchedGroupCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupCallEntity.objectID) as? GroupCallEntity
        )
        
        // Assert
        XCTAssertEqual(gck, fetchedGroupCallEntity.gck)
        XCTAssertEqual(protocolVersion, try Int32(truncating: XCTUnwrap(fetchedGroupCallEntity.protocolVersion)))
        XCTAssertEqual(sfuBaseURL, fetchedGroupCallEntity.sfuBaseURL)
        XCTAssertEqual(
            startMessageReceiveDate,
            fetchedGroupCallEntity.startMessageReceiveDate
        )
        XCTAssertEqual(groupEntity.objectID, fetchedGroupCallEntity.group?.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 4)

            // Test faulting
            testDatabase.context.main.refresh(fetchedGroupCallEntity, mergeChanges: false)

            XCTAssertEqual(gck, fetchedGroupCallEntity.gck)
            XCTAssertEqual(protocolVersion, try Int32(truncating: XCTUnwrap(fetchedGroupCallEntity.protocolVersion)))
            XCTAssertEqual(sfuBaseURL, fetchedGroupCallEntity.sfuBaseURL)
            XCTAssertEqual(
                startMessageReceiveDate.timeIntervalSince1970,
                fetchedGroupCallEntity.startMessageReceiveDate?.timeIntervalSince1970
            )

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 4)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 4)
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
        let groupCallEntity = entityManager.performAndWaitSave {
            GroupCallEntity(context: testDatabase.context.main)
        }

        let fetchedGroupCallEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: groupCallEntity.objectID) as? GroupCallEntity
        )
        
        // Assert
        XCTAssertNotNil(fetchedGroupCallEntity)
    }
}
