import RemoteSecretProtocolTestHelper
import ThreemaEssentials
import XCTest
@testable import RemoteSecret
@testable import ThreemaFramework

final class BallotEntityTests: XCTestCase {
    
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

        let assessmentType = BallotEntity.BallotAssessmentType.multi
        let createDate = Date.now
        let creatorID = "TESTER01"
        let displayMode = BallotEntity.BallotDisplayMode.list
        let id = BytesUtility.generateBallotID()
        let modifyDate = Date.now
        let state = BallotEntity.BallotState.open
        let title = "Test Ballot"
        let type = BallotEntity.BallotType.closed
                
        // Act
        let conversation = entityManager.performAndWaitSave {
            entityManager.entityCreator.conversationEntity()
        }
        
        let ballotMessageEntity: Set<BallotMessageEntity> = entityManager.performAndWaitSave {
            [entityManager.entityCreator.ballotMessageEntity(in: conversation)]
        }
        let participants: Set<ContactEntity> = entityManager.performAndWait {
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

        // Count only encrypt calls while saving `BallotEntity`
        testDatabase.remoteSecretCryptoMock.encryptCalls = 0

        let ballotEntity = entityManager.performAndWaitSave {
            BallotEntity(
                context: testDatabase.context.main,
                assessmentType: assessmentType,
                createDate: createDate,
                creatorID: creatorID,
                displayMode: displayMode,
                id: id,
                modifyDate: modifyDate,
                state: state,
                title: title,
                type: type,
                choices: nil,
                conversation: conversation,
                message: ballotMessageEntity,
                participants: participants
            )
        }
        
        let fetchedBallotEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotEntity.objectID) as? BallotEntity
        )
        
        // Assert
        XCTAssertEqual(NSNumber(integerLiteral: assessmentType.rawValue), fetchedBallotEntity.assessmentType)
        XCTAssertEqual(0, fetchedBallotEntity.choicesType)
        XCTAssertEqual(createDate, fetchedBallotEntity.createDate)
        XCTAssertEqual(creatorID, fetchedBallotEntity.creatorID)
        XCTAssertEqual(NSNumber(integerLiteral: displayMode.rawValue), fetchedBallotEntity.displayMode)
        XCTAssertEqual(id, fetchedBallotEntity.id)
        XCTAssertEqual(modifyDate, fetchedBallotEntity.modifyDate)
        XCTAssertEqual(NSNumber(integerLiteral: state.rawValue), fetchedBallotEntity.state)
        XCTAssertEqual(title, fetchedBallotEntity.title)
        XCTAssertEqual(NSNumber(integerLiteral: type.rawValue), fetchedBallotEntity.type)
        XCTAssertEqual(conversation.objectID, fetchedBallotEntity.conversation?.objectID)
        XCTAssertEqual(ballotMessageEntity.count, fetchedBallotEntity.message?.count)
        XCTAssertEqual(participants.count, fetchedBallotEntity.participants?.count)

        if encrypted {
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 0)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 5)

            // Test faulting
            testDatabase.context.main.refresh(fetchedBallotEntity, mergeChanges: false)

            XCTAssertEqual(NSNumber(integerLiteral: assessmentType.rawValue), fetchedBallotEntity.assessmentType)
            XCTAssertEqual(0, fetchedBallotEntity.choicesType)
            XCTAssertEqual(NSNumber(integerLiteral: displayMode.rawValue), fetchedBallotEntity.displayMode)
            XCTAssertEqual(title, fetchedBallotEntity.title)
            XCTAssertEqual(NSNumber(integerLiteral: type.rawValue), fetchedBallotEntity.type)

            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.decryptCalls, 5)
            XCTAssertEqual(testDatabase.remoteSecretCryptoMock.encryptCalls, 5)
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

        let assessmentType = BallotEntity.BallotAssessmentType.multi
        let id = BytesUtility.generateBallotID()
        let state = BallotEntity.BallotState.open
        let type = BallotEntity.BallotType.closed
                
        // Act
        let ballotEntity = entityManager.performAndWaitSave {
            BallotEntity(
                context: testDatabase.context.main,
                assessmentType: assessmentType,
                id: id,
                state: state,
                type: type
            )
        }
        
        let fetchedBallotEntity = try XCTUnwrap(
            entityManager.entityFetcher
                .existingObject(with: ballotEntity.objectID) as? BallotEntity
        )
        
        // Assert
        XCTAssertEqual(NSNumber(integerLiteral: assessmentType.rawValue), fetchedBallotEntity.assessmentType)
        XCTAssertEqual(0, fetchedBallotEntity.choicesType)
        XCTAssertEqual(id, fetchedBallotEntity.id)
        XCTAssertEqual(NSNumber(integerLiteral: state.rawValue), fetchedBallotEntity.state)
        XCTAssertEqual(NSNumber(integerLiteral: type.rawValue), fetchedBallotEntity.type)
    }
}
