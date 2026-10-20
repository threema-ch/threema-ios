import libthreemaSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

struct DeletedMessageStateTests {

    @Test func `Deleted message state for not deleted message entity`() async throws {
        let testDatabase = TestDatabase()

        // Setup

        let baseMessage: BaseMessageEntity = testDatabase.preparer.save {
            let conversation = testDatabase.preparer.createConversation()
            return testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: nil,
                remoteSentDate: nil
            )
        }

        // Act

        #expect(throws: MappingError.messageDeletedAtMissing) {
            _ = try DeletedMessageState(baseMessageEntity: baseMessage)
        }
    }

    @Test func `Deleted message state for deleted message entities`() async throws {
        let testDatabase = TestDatabase()

        // Setup

        let expectedDeletedAt = Date()

        let testCases: [(baseMessage: BaseMessageEntity, expectedType: MessageStateBodyType)] = testDatabase.preparer.save {
            let conversation = testDatabase.preparer.createConversation()
            let ballot = testDatabase.preparer.createBallot(conversation: conversation)

            let ballotMessage = testDatabase.preparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: false
            )
            ballotMessage.ballotState = nil
            ballotMessage.deletedAt = expectedDeletedAt

            let ballotMessageClosed = testDatabase.preparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: false
            )
            ballotMessageClosed.ballotState = NSNumber(integerLiteral: BallotEntity.BallotState.closed.rawValue)
            ballotMessageClosed.deletedAt = expectedDeletedAt

            let ballotMessageOpen = testDatabase.preparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: false
            )
            ballotMessageOpen.ballotState = NSNumber(integerLiteral: BallotEntity.BallotState.open.rawValue)
            ballotMessageOpen.deletedAt = expectedDeletedAt

            let locationMessage = testDatabase.preparer.createLocationMessage(
                conversation: conversation,
                accuracy: 0,
                latitude: 0,
                longitude: 0,
                poiName: nil,
                isOwn: false
            )
            locationMessage.deletedAt = expectedDeletedAt

            let textMessage = testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: nil,
                remoteSentDate: nil
            )
            textMessage.deletedAt = expectedDeletedAt

            return [
                (ballotMessage, .deleted),
                (ballotMessageClosed, .pollClose),
                (ballotMessageOpen, .pollOpen),
                (locationMessage, .location),
                (textMessage, .text),
            ]
        }

        // Act

        for testCase in testCases {
            let deletedMassegeState = try DeletedMessageState(baseMessageEntity: testCase.baseMessage)

            #expect(deletedMassegeState.deletedAt == expectedDeletedAt.millisecondsSince1970.littleEndian)
            #expect(deletedMassegeState.previousMessageType == testCase.expectedType)
        }
    }
}
