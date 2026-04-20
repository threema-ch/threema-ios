import ThreemaEssentials

import XCTest
@testable import ThreemaFramework

final class LastGroupSyncRequestEntityTests: XCTestCase {
    
    // MARK: - Properties

    private var testDatabase: TestDatabase!

    // MARK: - Setup

    override func setUpWithError() throws {
        testDatabase = TestDatabase()
    }
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let groupCreator = "TESTER01"
        let groupID = BytesUtility.generateGroupID()
        let lastSyncRequest = Date.now
        let entityManager = testDatabase.entityManager

        // Act
        let lastGroupSyncRequestEntity = entityManager.performAndWaitSave {
            LastGroupSyncRequestEntity(
                context: self.testDatabase.context.main,
                groupCreator: groupCreator,
                groupID: groupID,
                lastSyncRequest: lastSyncRequest
            )
        }

        let fetchedLastGroupSyncRequestEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: lastGroupSyncRequestEntity.objectID) as? LastGroupSyncRequestEntity
        )
        
        // Assert
        XCTAssertEqual(groupCreator, fetchedLastGroupSyncRequestEntity.groupCreator)
        XCTAssertEqual(groupID, fetchedLastGroupSyncRequestEntity.groupID)
        XCTAssertEqual(lastSyncRequest, fetchedLastGroupSyncRequestEntity.lastSyncRequest)
    }
}
