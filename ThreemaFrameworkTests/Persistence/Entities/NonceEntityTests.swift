import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class NonceEntityTests: XCTestCase {
    
    // MARK: - Tests

    func testCreation() throws {
        // Arrange
        let testDatabase = TestDatabase()
        let nonce = BytesUtility.generateMessageNonce()
        let entityManager = testDatabase.entityManager

        // Act
        let nonceEntity = entityManager.performAndWaitSave {
            NonceEntity(context: testDatabase.context.main, nonce: nonce)
        }

        let fetchedNonceEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: nonceEntity.objectID) as? NonceEntity
        )
        
        // Assert
        XCTAssertEqual(nonce, fetchedNonceEntity.nonce)
    }
}
