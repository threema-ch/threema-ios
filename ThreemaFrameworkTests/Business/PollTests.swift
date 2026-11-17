import Testing
import ThreemaEssentials

@testable import ThreemaFramework

@MainActor
@Suite("Poll")
struct PollTests {

    enum Vote {
        case selection
        case abstention
    }

    init() {
        AppGroup.setGroupID("group.ch.threema")
        self.testDatabase = TestDatabase()
        self.identityStore = MyIdentityStoreMock()
    }

    // MARK: - Non-respondents

    @Test(arguments: [Vote.selection, .abstention])
    func `A member who voted is not a non-respondent`(vote: Vote) {
        let ballot = addGroupBallot()
        addVote(vote, by: PollTests.firstMember, in: ballot)

        let poll = Poll(for: ballot, identityStore: identityStore)

        #expect(!poll.nonRespondents.map(\.identity).contains(PollTests.firstMember))
        #expect(poll.voteCountInfo.countVotes == 1)
    }

    @Test func `A member without a vote is a non-respondent`() {
        let ballot = addGroupBallot()
        addVote(.selection, by: PollTests.firstMember, in: ballot)

        let poll = Poll(for: ballot, identityStore: identityStore)

        let myIdentity: String = identityStore.identity
        #expect(poll.nonRespondents.map(\.identity).sorted() == [PollTests.secondMember, myIdentity])
    }

    @Test func `An abstention is not listed as a voter of any choice`() {
        let ballot = addGroupBallot()
        addVote(.abstention, by: PollTests.firstMember, in: ballot)

        let poll = Poll(for: ballot, identityStore: identityStore)

        // swiftformat:disable:next all
        #expect(poll.choices.allSatisfy { $0.voters.isEmpty })
    }

    @Test func `An own abstention counts as a vote`() {
        let ballot = addGroupBallot()
        addVote(.abstention, by: identityStore.identity, in: ballot)

        let poll = Poll(for: ballot, identityStore: identityStore)

        #expect(!poll.nonRespondents.map(\.identity).contains(identityStore.identity))
        #expect(poll.voteCountInfo.countVotes == 1)
    }

    // MARK: - Private methods

    private static let firstMember = "MEMBER01"
    private static let secondMember = "MEMBER02"

    private let testDatabase: TestDatabase
    private let identityStore: MyIdentityStoreMock

    private func addGroupBallot() -> BallotEntity {
        testDatabase.preparer.save {
            let members = [PollTests.firstMember, PollTests.secondMember].map {
                testDatabase.preparer.createContact(identity: $0)
            }
            let conversation = testDatabase.preparer.createConversation(groupID: BytesUtility.generateGroupID())
            conversation.members = Set(members)

            let ballot = testDatabase.preparer.createBallot(conversation: conversation)
            for position in 0..<2 {
                _ = BallotChoiceEntity(
                    context: testDatabase.context.main,
                    id: NSNumber(value: position),
                    name: "Choice \(position)",
                    orderPosition: NSNumber(value: position),
                    ballot: ballot
                )
            }
            return ballot
        }
    }

    private func addVote(_ vote: Vote, by identity: String, in ballot: BallotEntity) {
        testDatabase.preparer.save {
            for (index, choice) in ballot.choicesSortedByOrder.enumerated() {
                _ = BallotResultEntity(
                    context: testDatabase.context.main,
                    participantID: identity,
                    value: vote == .selection && index == 0,
                    ballotChoice: choice
                )
            }
        }
    }
}
