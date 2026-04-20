import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class BallotChoiceEntityTests: XCTestCase {
    
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

        let createDate = Date.now
        let id = NSNumber(integerLiteral: 0)
        let modifyDate = Date.now
        let name = "Test Choice"
        let orderPosition = NSNumber(integerLiteral: 1)
        let totalVotes = NSNumber(integerLiteral: 2)
        
        // Act
        let ballotEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotEntity(id: BytesUtility.generateBallotID())
        }

        // Count only encrypt calls while saving `BallotChoiceEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let ballotChoiceEntity = entityManager.performAndWaitSave {
            BallotChoiceEntity(
                context: testDatabase.context.main,
                createDate: createDate,
                id: id,
                modifyDate: modifyDate,
                name: name,
                orderPosition: orderPosition,
                totalVotes: totalVotes,
                ballot: ballotEntity,
                result: nil
            )
        }
        
        let fetchedBallotChoiceEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotChoiceEntity.objectID) as? BallotChoiceEntity
        )
        
        // Assert
        XCTAssertEqual(createDate, fetchedBallotChoiceEntity.createDate)
        XCTAssertEqual(id, fetchedBallotChoiceEntity.id)
        XCTAssertEqual(modifyDate, fetchedBallotChoiceEntity.modifyDate)
        XCTAssertEqual(name, fetchedBallotChoiceEntity.name)
        XCTAssertEqual(orderPosition, fetchedBallotChoiceEntity.orderPosition)
        XCTAssertEqual(totalVotes, fetchedBallotChoiceEntity.totalVotes)
        XCTAssertEqual(ballotEntity.objectID, fetchedBallotChoiceEntity.ballot.objectID)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 4)

            // Test faulting
            testDatabase.context.main.refresh(fetchedBallotChoiceEntity, mergeChanges: false)

            XCTAssertEqual(
                createDate.timeIntervalSince1970,
                fetchedBallotChoiceEntity.createDate?.timeIntervalSince1970
            )
            XCTAssertEqual(
                modifyDate.timeIntervalSince1970,
                fetchedBallotChoiceEntity.modifyDate?.timeIntervalSince1970
            )
            XCTAssertEqual(name, fetchedBallotChoiceEntity.name)
            XCTAssertEqual(totalVotes, fetchedBallotChoiceEntity.totalVotes)
            
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

        let id = NSNumber(integerLiteral: 0)
        // Act
        let ballotEntity = entityManager.performAndWaitSave {
            entityManager.entityCreator.ballotEntity(id: BytesUtility.generateBallotID())
        }
        
        let ballotChoiceEntity = entityManager.performAndWaitSave {
            BallotChoiceEntity(context: testDatabase.context.main, id: id, ballot: ballotEntity)
        }
        
        let fetchedBallotChoiceEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotChoiceEntity.objectID) as? BallotChoiceEntity
        )
        
        // Assert
        XCTAssertEqual(id, fetchedBallotChoiceEntity.id)
        XCTAssertEqual(ballotEntity.objectID, fetchedBallotChoiceEntity.ballot.objectID)
    }
}
