import libthreemaSwift
import Testing
import ThreemaEssentials

@testable import ThreemaFramework

@MainActor
@Suite("Poll Provider Integration Tests")
struct PollProviderTests {

    // MARK: - getMany(batchIndex:) tests

    @Test func `GetMany returns an empty array when the database is empty`() async throws {
        let pollsInDB = entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations()
        #expect(pollsInDB.isEmpty)

        let sut = makeSUT()

        let polls = try sut.getMany(batchIndex: 0)

        #expect(polls.isEmpty)
    }

    @Test func `GetMany includes polls from both contact and group conversations`() async throws {
        // One poll in a contact conversation and one in a group conversation

        let contactConversation = addContactConversation()
        addBallotEntity(openSingleChoiceBallot, in: contactConversation, id: UInt64(1).littleEndianData)

        let groupConversation = try addGroupConversation()
        addBallotEntity(openSingleChoiceBallot, in: groupConversation, id: UInt64(2).littleEndianData)

        let sut = makeSUT()

        let polls = try sut.getMany(batchIndex: 0)

        // Both polls are returned
        #expect(polls.count == 2)
        #expect(Set(polls.map(\.id)) == [1, 2])

        // One from the contact conversation and one from the group conversation
        let contactPoll = try #require(polls.first { $0.id == 1 })
        #expect(contactPoll.conversation == .contact(PollProviderTests.firstVoter))

        let groupPoll = try #require(polls.first { $0.id == 2 })
        if case .group = groupPoll.conversation {
            // expected
        }
        else {
            Issue.record("Expected a group conversation but got \(groupPoll.conversation)")
        }
    }

    @Test func `GetMany maps a poll with summary votes`() async throws {
        // A summary-mode poll stores aggregate counts per choice, not individual votes

        let conversation = addContactConversation()
        addBallotEntity(summaryVotesBallot, in: conversation, id: UInt64(1).littleEndianData)

        let sut = makeSUT()

        let polls = try sut.getMany(batchIndex: 0)
        let poll = try #require(polls.first)

        // `summaryVotesBallot` has choices ["Yes", "No"] with 3 and 1 votes respectively
        #expect(poll.votes == .summary([0: 3, 1: 1]))
    }

    @Test func `GetMany maps a poll with detailed votes`() async throws {
        // A non-summary poll stores the individual selection of every voter

        let conversation = addContactConversation()
        addBallotEntity(detailedVotesBallot, in: conversation, id: UInt64(1).littleEndianData)

        let sut = makeSUT()

        let polls = try sut.getMany(batchIndex: 0)
        let poll = try #require(polls.first)

        guard case let .votes(votes) = poll.votes else {
            Issue.record("Expected detailed votes but got \(poll.votes)")
            return
        }

        // `detailedVotesBallot` has TESTID01 voting for choice 0 and TESTID02 for choice 1
        #expect(votes.count == 2)
        #expect(votes[PollProviderTests.firstVoter]?.choices == [0])
        #expect(votes[PollProviderTests.secondVoter]?.choices == [1])
    }

    @Test func `GetMany maps nil ballot attributes to their defaults`() async throws {
        let conversation = addContactConversation()

        addBallotEntity(
            BallotFixture(state: nil, assessmentType: nil, announceType: nil, displayMode: nil),
            in: conversation,
            id: UInt64(1).littleEndianData
        )

        let sut = makeSUT()

        let polls = try sut.getMany(batchIndex: 0)
        let poll = try #require(polls.first)

        #expect(poll.state == .open)
        #expect(poll.answerType == .singleChoice)
        #expect(poll.announceType == .creatorOnly)
        #expect(poll.displayMode == .list)
    }

    @Test func `GetMany returns a full batch when exactly batchCount polls exist`() async throws {
        // Prepare the DB with 5 polls available

        let conversation = addContactConversation()
        seedPolls(100, in: conversation)

        let sut = makeSUT(batchSize: 100)

        #expect(try sut.getMany(batchIndex: 0).count == 100)
    }

    @Test func `GetMany returns a partial batch when fewer than batchCount polls remain`() async throws {
        // Prepare the DB with 5 polls available

        let conversation = addContactConversation()
        seedPolls(5, in: conversation)

        let sut = makeSUT(batchSize: 2)

        // Batch 0 holds first 2 polls
        #expect(try sut.getMany(batchIndex: 0).count == 2)

        // Batch 1 holds next 2 polls
        #expect(try sut.getMany(batchIndex: 1).count == 2)

        // Batch 2 holds the last poll
        #expect(try sut.getMany(batchIndex: 2).count == 1)

        // Batch 3 is empty
        #expect(try sut.getMany(batchIndex: 3).isEmpty)
    }

    @Test func `GetMany returns an empty array when batchIndex is beyond the available polls`() async throws {
        // Prepare the DB with 4 polls available

        let conversation = addContactConversation()
        seedPolls(4, in: conversation)

        let sut = makeSUT(batchSize: 2)

        // Batch 0 holds first 2 polls
        #expect(try sut.getMany(batchIndex: 0).count == 2)

        // Batch 1 holds last 2 polls
        #expect(try sut.getMany(batchIndex: 1).count == 2)

        // Batch 2 returns empty polls
        #expect(try sut.getMany(batchIndex: 2).isEmpty)
    }

    @Test func `GetMany returns non-overlapping polls across consecutive batches`() async throws {
        // Prepare the DB with 5 polls with known, distinct ids

        let conversation = addContactConversation()
        let expectedIDs: Set<UInt64> = [11, 22, 33, 44, 55]
        for id in expectedIDs {
            addBallotEntity(openSingleChoiceBallot, in: conversation, id: id.littleEndianData)
        }

        let sut = makeSUT(batchSize: 2)

        let batch0 = try Set(sut.getMany(batchIndex: 0).map(\.id))
        let batch1 = try Set(sut.getMany(batchIndex: 1).map(\.id))
        let batch2 = try Set(sut.getMany(batchIndex: 2).map(\.id))

        // Each batch holds its own slice
        #expect(batch0.count == 2)
        #expect(batch1.count == 2)
        #expect(batch2.count == 1)

        // Consecutive batches share no poll
        #expect(batch0.isDisjoint(with: batch1))
        #expect(batch1.isDisjoint(with: batch2))

        // Together they return exactly the seeded poll ids, each exactly once
        #expect(batch0.union(batch1).union(batch2) == expectedIDs)
    }

    @Test func `GetMany throws when batchIndex is too large`() async throws {
        let batchSize = 100
        let sut = makeSUT(batchSize: batchSize)

        let invalidBatchIndex = UInt64(Int.max / batchSize) + 1

        let error = ProviderError.InvalidParameter("Invalid Parameter batchIndex too large for batchSize \(batchSize)")

        #expect(throws: error) {
            _ = try sut.getMany(batchIndex: invalidBatchIndex)
        }
    }

    @Test func `GetMany throws when state has an unknown raw value`() async throws {
        expectGetManyThrows(.ballotState) { $0.state = NSNumber(value: 99) }
    }

    @Test func `GetMany throws when assessmentType has an unknown raw value`() async throws {
        expectGetManyThrows(.ballotAssessmentType) { $0.assessmentType = NSNumber(value: 99) }
    }

    @Test func `GetMany throws when type has an unknown raw value`() async throws {
        expectGetManyThrows(.ballotType) { $0.type = NSNumber(value: 99) }
    }

    @Test func `GetMany throws when displayMode has an unknown raw value`() async throws {
        expectGetManyThrows(.ballotDisplayMode) { $0.displayMode = NSNumber(value: 99) }
    }

    @Test func `GetMany throws when createDate is nil`() async throws {
        expectGetManyThrows(.ballotCreatedAt) { $0.createDate = nil }
    }

    @Test func `GetMany throws when title is nil`() async throws {
        expectGetManyThrows(.ballotTitle) { $0.title = nil }
    }

    @Test func `GetMany throws when creator is nil`() async throws {
        expectGetManyThrows(.ballotCreator) { $0.creatorID = nil }
    }

    // MARK: - add(polls:) tests

    @Test func `Add does nothing when the polls array is empty`() async throws {
        let sut = makeSUT()

        try sut.add(polls: [])

        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add persists a poll in a contact conversation`() async throws {
        // The contact conversation must already exist for the poll to be restored into it
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            creator: PollProviderTests.userIdentity,
            description: "Lunch?",
            choices: [
                PollChoice(id: 0, description: "Choice 1"),
                PollChoice(id: 1, description: "Choice 2"),
            ]
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // The ballot is persisted into the contact conversation with its core attributes and choices
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(ballot.assessmentType?.intValue == Int(PollAnswerType.singleChoice.rawValue))
        #expect(ballot.choicesType?.intValue == 0)
        #expect(ballot.createDate?.millisecondsSince1970 == 0)
        #expect(ballot.creatorID == PollProviderTests.userIdentity)
        #expect(ballot.displayMode?.intValue == 0)
        #expect(ballot.id == pollID.littleEndianData)
        #expect(ballot.modifyDate?.millisecondsSince1970 == 0)
        #expect(ballot.state?.intValue == Int(PollState.open.rawValue))
        #expect(ballot.title == "Lunch?")
        #expect(ballot.type?.intValue == 1)
        let choiceNames = Set((ballot.choices ?? []).compactMap(\.name))
        #expect(choiceNames == ["Choice 1", "Choice 2"])
        #expect(ballot.conversation?.contact?.identity == PollProviderTests.firstVoter)
    }

    @Test func `Add persists a poll in a group conversation`() async throws {
        // The group conversation must already exist for the poll to be restored into it
        let groupConversation = try addGroupConversation()
        let groupID = try #require(groupConversation.groupID)
        let groupIdentity = ThreemaEssentials.GroupIdentity(id: groupID, creatorID: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = try makePoll(
            id: pollID,
            in: .group(LibthreemaGroupIdentity(groupIdentity: groupIdentity)),
            creator: PollProviderTests.userIdentity,
            description: "Lunch?",
            choices: [
                PollChoice(id: 0, description: "Choice 1"),
                PollChoice(id: 1, description: "Choice 2"),
            ]
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // The ballot is persisted into the group conversation with its core attributes and choices
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(ballot.assessmentType?.intValue == Int(PollAnswerType.singleChoice.rawValue))
        #expect(ballot.choicesType?.intValue == 0)
        #expect(ballot.createDate?.millisecondsSince1970 == 0)
        #expect(ballot.creatorID == PollProviderTests.userIdentity)
        #expect(ballot.displayMode?.intValue == 0)
        #expect(ballot.id == pollID.littleEndianData)
        #expect(ballot.modifyDate?.millisecondsSince1970 == 0)
        #expect(ballot.state?.intValue == Int(PollState.open.rawValue))
        #expect(ballot.title == "Lunch?")
        #expect(ballot.type?.intValue == 1)
        let choiceNames = Set((ballot.choices ?? []).compactMap(\.name))
        #expect(choiceNames == ["Choice 1", "Choice 2"])
        #expect(ballot.conversation?.groupID == groupID)
    }

    @Test func `Add persists a poll with multiple choices`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            choices: [
                PollChoice(id: 0, description: "Red"),
                PollChoice(id: 1, description: "Green"),
                PollChoice(id: 2, description: "Blue"),
            ]
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        let ballot = try persistedBallot(forPollID: pollID)
        let choices = ballot.choices ?? []
        #expect(choices.count == 3)

        let namesByID = Dictionary(uniqueKeysWithValues: choices.map { ($0.id.uint32Value, $0.name ?? "") })
        #expect(namesByID == [0: "Red", 1: "Green", 2: "Blue"])

        // Order positions follow the input order
        let orderByID = Dictionary(
            uniqueKeysWithValues: choices.map { ($0.id.uint32Value, $0.orderPosition?.intValue ?? -1) }
        )
        #expect(orderByID == [0: 0, 1: 1, 2: 2])
    }

    @Test func `Add persists a poll when the votes are empty`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(id: pollID, in: .contact(PollProviderTests.firstVoter), votes: .votes([:]))

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // The choices are persisted but no results exist
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(ballot.choices?.count == 2)
        #expect((ballot.choices ?? []).flatMap { $0.result ?? [] }.isEmpty)
    }

    @Test func `Add persists a poll when all voters are known contacts`() async throws {
        // Both voters are known contacts (TESTID01 backs the conversation, TESTID02 is added separately)
        addContactConversation(with: PollProviderTests.firstVoter)
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: PollProviderTests.secondVoter)
        }

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            choices: [
                PollChoice(id: 0, description: "Yes"),
                PollChoice(id: 1, description: "No"),
            ],
            votes: .votes([
                PollProviderTests.firstVoter: PollVote(choices: [0], createdAt: 0, modifiedAt: nil),
                PollProviderTests.secondVoter: PollVote(choices: [1], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // A result is persisted for every (voter, choice) pair, recording each voter's selection
        let ballot = try persistedBallot(forPollID: pollID)
        let allResults = (ballot.choices ?? []).flatMap { $0.result ?? [] }
        #expect(allResults.count == 4)
        #expect(Set(allResults.map(\.participantID)) == [PollProviderTests.firstVoter, PollProviderTests.secondVoter])

        var selectedChoiceIDsByVoter: [String: Set<UInt32>] = [:]
        for choice in ballot.choices ?? [] {
            for result in choice.result ?? [] where result.boolValue {
                selectedChoiceIDsByVoter[result.participantID, default: []].insert(choice.id.uint32Value)
            }
        }
        #expect(selectedChoiceIDsByVoter == [
            PollProviderTests.firstVoter: [0],
            PollProviderTests.secondVoter: [1],
        ])
    }

    @Test func `Add allows the local user as a voter without a contact lookup`() async throws {
        // The local user is never stored as a contact, yet may appear as a voter
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            votes: .votes([
                PollProviderTests.userIdentity: PollVote(choices: [0], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        // The local user is not a contact
        #expect(entityManager.entityFetcher.contactEntity(for: PollProviderTests.userIdentity) == nil)

        // Still succeeds because the local user is skipped during voter validation
        try sut.add(polls: [poll])

        let ballot = try persistedBallot(forPollID: pollID)
        #expect(selectedChoiceIDs(for: PollProviderTests.userIdentity, in: ballot) == [0])
    }

    @Test func `Add persists detailed votes when a voter selected a subset of choices`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            answerType: .multipleChoice,
            choices: [
                PollChoice(id: 0, description: "A"),
                PollChoice(id: 1, description: "B"),
                PollChoice(id: 2, description: "C"),
            ],
            votes: .votes([
                PollProviderTests.firstVoter: PollVote(choices: [0, 2], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // A result exists for every choice, but only the selected ones are marked
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(resultCount(for: PollProviderTests.firstVoter, in: ballot) == 3)
        #expect(selectedChoiceIDs(for: PollProviderTests.firstVoter, in: ballot) == [0, 2])
    }

    @Test func `Add persists detailed votes when a voter selected all choices`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            answerType: .multipleChoice,
            choices: [
                PollChoice(id: 0, description: "A"),
                PollChoice(id: 1, description: "B"),
                PollChoice(id: 2, description: "C"),
            ],
            votes: .votes([
                PollProviderTests.firstVoter: PollVote(choices: [0, 1, 2], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        let ballot = try persistedBallot(forPollID: pollID)
        #expect(resultCount(for: PollProviderTests.firstVoter, in: ballot) == 3)
        #expect(selectedChoiceIDs(for: PollProviderTests.firstVoter, in: ballot) == [0, 1, 2])
    }

    @Test func `Add persists detailed votes when a voter selected no choices`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            choices: [
                PollChoice(id: 0, description: "Yes"),
                PollChoice(id: 1, description: "No"),
            ],
            votes: .votes([
                PollProviderTests.firstVoter: PollVote(choices: [], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // The voter is still recorded with a (false) result for every choice, but selected none
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(resultCount(for: PollProviderTests.firstVoter, in: ballot) == 2)
        #expect(selectedChoiceIDs(for: PollProviderTests.firstVoter, in: ballot).isEmpty)
    }

    @Test func `Add skips voter validation for summary votes`() async throws {
        addContactConversation()

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            displayMode: .summary,
            choices: [
                PollChoice(id: 0, description: "Yes"),
                PollChoice(id: 1, description: "No"),
            ],
            votes: .summary([0: 3, 1: 1])
        )

        let sut = makeSUT()

        // No voter contacts exist, yet add succeeds because summary votes skip voter validation
        try sut.add(polls: [poll])

        // The summary is persisted as a total vote count per choice
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(ballot.displayMode?.intValue == Int(PollDisplayMode.summary.rawValue))

        #expect(totalVotes(in: ballot) == [0: 3, 1: 1])

        // The conversation has no contact created for any voter, confirming validation was skipped
        #expect(entityManager.entityFetcher.contactEntity(for: PollProviderTests.secondVoter) == nil)
    }

    @Test func `Add persists summary vote counts per choice`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            displayMode: .summary,
            choices: [
                PollChoice(id: 0, description: "Yes"),
                PollChoice(id: 1, description: "No"),
            ],
            votes: .summary([0: 5, 1: 2])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        let ballot = try persistedBallot(forPollID: pollID)
        #expect(totalVotes(in: ballot) == [0: 5, 1: 2])
    }

    @Test func `Add ignores a summary count for an unknown choice id`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        // The summary references choice id 99, which is not among the poll's choices
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            displayMode: .summary,
            choices: [
                PollChoice(id: 0, description: "Yes"),
                PollChoice(id: 1, description: "No"),
            ],
            votes: .summary([0: 5, 1: 2, 99: 7])
        )

        let sut = makeSUT()

        try sut.add(polls: [poll])

        // The unknown choice id is dropped; only the declared choices are persisted with their counts
        let ballot = try persistedBallot(forPollID: pollID)
        #expect(ballot.choices?.count == 2)
        #expect(totalVotes(in: ballot) == [0: 5, 1: 2])
    }

    @Test func `Add persists multiple valid polls`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let firstID: LibthreemaPollID = 1
        let secondID: LibthreemaPollID = 2
        let polls = [
            makePoll(id: firstID, in: .contact(PollProviderTests.firstVoter), description: "First"),
            makePoll(id: secondID, in: .contact(PollProviderTests.firstVoter), description: "Second"),
        ]

        let sut = makeSUT()

        try sut.add(polls: polls)

        #expect(entityManager.entityFetcher.ballotEntity(for: firstID.littleEndianData) != nil)
        #expect(entityManager.entityFetcher.ballotEntity(for: secondID.littleEndianData) != nil)
        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().count == 2)
    }

    @Test func `Add throws when the contact conversation does not exist`() async throws {
        // No conversation is created for the contact

        let poll = makePoll(in: .contact(PollProviderTests.firstVoter))

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidParameter("No conversation for contact \(PollProviderTests.firstVoter)")
        #expect(throws: expectedError) {
            try sut.add(polls: [poll])
        }

        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add throws when the group conversation does not exist`() async throws {
        // No conversation is created for the group

        let groupIdentity = ThreemaEssentials.GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: PollProviderTests.firstVoter
        )
        let poll = try makePoll(in: .group(LibthreemaGroupIdentity(groupIdentity: groupIdentity)))

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidParameter("No conversation for group \(groupIdentity)")
        #expect(throws: expectedError) {
            try sut.add(polls: [poll])
        }

        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add throws when the conversation is a distribution list`() async throws {
        // Polls in distribution lists are not supported, regardless of whether the conversation exists

        let poll = makePoll(in: .distributionList(1))

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidParameter("Polls in distribution lists are not supported")
        #expect(throws: expectedError) {
            try sut.add(polls: [poll])
        }

        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add throws when a poll with the same id already exists`() async throws {
        let conversation = addContactConversation()

        let pollID: LibthreemaPollID = 1
        // A ballot with this id already exists in the database
        addBallotEntity(openSingleChoiceBallot, in: conversation, id: pollID.littleEndianData)

        let poll = makePoll(id: pollID, in: .contact(PollProviderTests.firstVoter))

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidState("A poll with id \(pollID) already exists")
        #expect(throws: expectedError) {
            try sut.add(polls: [poll])
        }

        // The pre-existing ballot is untouched and no new one is added
        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().count == 1)
    }

    @Test func `Add throws when the same poll id appears twice within one batch`() async throws {
        // Both polls share an id; the second is caught against the first's still-pending insert
        addContactConversation()

        let pollID: LibthreemaPollID = 1
        let firstPoll = makePoll(id: pollID, in: .contact(PollProviderTests.firstVoter), description: "First")
        let secondPoll = makePoll(id: pollID, in: .contact(PollProviderTests.firstVoter), description: "Second")

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidState("A poll with id \(pollID) already exists")
        #expect(throws: expectedError) {
            try sut.add(polls: [firstPoll, secondPoll])
        }

        // The whole batch is rolled back, so nothing is persisted
        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add throws when a voter is not a known contact`() async throws {
        // The conversation's contact (TESTID01) exists, but the voter (TESTID02) is not a known contact
        addContactConversation(with: PollProviderTests.firstVoter)

        let pollID: LibthreemaPollID = 1
        let poll = makePoll(
            id: pollID,
            in: .contact(PollProviderTests.firstVoter),
            votes: .votes([
                PollProviderTests.secondVoter: PollVote(choices: [0], createdAt: 0, modifiedAt: nil),
            ])
        )

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidState("Voter \(PollProviderTests.secondVoter) is not a known contact")
        #expect(throws: expectedError) {
            try sut.add(polls: [poll])
        }

        // The poll is rejected and nothing is persisted
        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    @Test func `Add throws and rolls back all polls when one poll fails`() async throws {
        addContactConversation(with: PollProviderTests.firstVoter)

        let validPoll = makePoll(id: 1, in: .contact(PollProviderTests.firstVoter))
        // The second poll references a contact conversation that does not exist
        let failingPoll = makePoll(id: 2, in: .contact(PollProviderTests.secondVoter))

        let sut = makeSUT()

        let expectedError = ProviderError.InvalidParameter(
            "No conversation for contact \(PollProviderTests.secondVoter)"
        )
        #expect(throws: expectedError) {
            try sut.add(polls: [validPoll, failingPoll])
        }

        // The valid poll is rolled back too: the batch is all-or-nothing
        #expect(entityManager.entityFetcher.ballotEntitiesInContactOrGroupConversations().isEmpty)
    }

    // MARK: - Private methods

    private nonisolated static let userIdentity = "ECHOECHO"
    private nonisolated static let firstVoter = "TESTID01"
    private nonisolated static let secondVoter = "TESTID02"
    private nonisolated static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private var entityManager: EntityManager { testDatabase.entityManager }
    private let testDatabase = TestDatabase()

    private func makeSUT(batchSize: Int = 100) -> ThreemaFramework.PollProvider {
        PollProvider(
            userIdentity: ThreemaIdentity(rawValue: PollProviderTests.userIdentity),
            entityManager: entityManager,
            batchSize: batchSize
        )
    }

    private struct BallotFixture {
        var creator = PollProviderTests.userIdentity
        var title = "Test poll"
        var state: BallotEntity.BallotState? = .open
        var assessmentType: BallotEntity.BallotAssessmentType? = .single
        var announceType: BallotEntity.BallotType? = .intermediate
        var displayMode: BallotEntity.BallotDisplayMode? = .list
        var choices: [String] = ["Choice 1", "Choice 2"]
        var votes: Votes = .none

        enum Votes {
            case none
            case summary([Int])
            case detailed([String: Set<Int>])
        }
    }

    private var openSingleChoiceBallot: BallotFixture { BallotFixture() }

    private var summaryVotesBallot: BallotFixture {
        BallotFixture(displayMode: .summary, choices: ["Yes", "No"], votes: .summary([3, 1]))
    }

    private var detailedVotesBallot: BallotFixture {
        BallotFixture(choices: ["Yes", "No"], votes: .detailed([
            PollProviderTests.firstVoter: [0],
            PollProviderTests.secondVoter: [1],
        ]))
    }

    @discardableResult
    private func addContactConversation(with identity: String = PollProviderTests.firstVoter) -> ConversationEntity {
        testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: identity)
            return testDatabase.preparer.createConversation(contactEntity: contact)
        }
    }

    private func seedPolls(_ count: Int, in conversation: ConversationEntity) {
        for _ in 0..<count {
            addBallotEntity(openSingleChoiceBallot, in: conversation)
        }
    }

    @discardableResult
    private func addGroupConversation(
        creator: String = PollProviderTests.firstVoter,
        members: [String] = [PollProviderTests.userIdentity]
    ) throws -> ConversationEntity {
        let (_, _, conversation) = testDatabase.preparer.createGroup(
            groupID: BytesUtility.generateGroupID(),
            groupCreatorIdentity: creator,
            members: members
        )
        return conversation
    }

    @discardableResult
    private func addBallotEntity(
        _ fixture: BallotFixture = BallotFixture(),
        in conversation: ConversationEntity,
        id: Data = BytesUtility.generateBallotID(),
        createdAt: Date = PollProviderTests.fixedDate
    ) -> BallotEntity {
        testDatabase.preparer.save {
            let entityCreator = entityManager.entityCreator

            let ballot = entityCreator.ballotEntity(id: id)
            ballot.conversation = conversation
            ballot.creatorID = fixture.creator
            ballot.title = fixture.title
            ballot.createDate = createdAt
            ballot.modifyDate = createdAt
            ballot.state = fixture.state.map { NSNumber(value: $0.rawValue) }
            ballot.assessmentType = fixture.assessmentType.map { NSNumber(value: $0.rawValue) }
            ballot.type = fixture.announceType.map { NSNumber(value: $0.rawValue) }
            ballot.displayMode = fixture.displayMode.map { NSNumber(value: $0.rawValue) }

            var choices: [BallotChoiceEntity] = []
            for (index, name) in fixture.choices.enumerated() {
                let choice = entityCreator.ballotChoiceEntity(ballotEntity: ballot, id: NSNumber(value: index))
                choice.name = name
                choice.orderPosition = NSNumber(value: index)
                choices.append(choice)
            }

            switch fixture.votes {
            case .none:
                break

            case let .summary(totalsPerChoice):
                for (index, total) in totalsPerChoice.enumerated() where choices.indices.contains(index) {
                    choices[index].totalVotes = NSNumber(value: total)
                }

            case let .detailed(selectionsByVoter):
                for (voter, selectedChoiceIndices) in selectionsByVoter {
                    for (index, choice) in choices.enumerated() {
                        let result = entityCreator.ballotResultEntity(
                            participantID: voter,
                            ballotChoiceEntity: choice
                        )
                        result.value = NSNumber(value: selectedChoiceIndices.contains(index))
                        result.createDate = createdAt
                        result.modifyDate = createdAt
                    }
                }
            }

            return ballot
        }
    }

    private func expectGetManyThrows(
        _ expectedError: MappingError,
        sourceLocation: SourceLocation = #_sourceLocation,
        whenCorrupting corrupt: (BallotEntity) -> Void
    ) {
        let conversation = addContactConversation()
        let ballot = addBallotEntity(openSingleChoiceBallot, in: conversation, id: UInt64(1).littleEndianData)

        testDatabase.preparer.save {
            corrupt(ballot)
        }

        let sut = makeSUT()

        #expect(throws: expectedError, sourceLocation: sourceLocation) {
            _ = try sut.getMany(batchIndex: 0)
        }
    }

    private func makePoll(
        id: LibthreemaPollID = 1,
        in conversation: LibthreemaConversationID,
        creator: String = PollProviderTests.userIdentity,
        createdAt: UInt64 = 0,
        state: PollState = .open,
        description: String = "Test poll",
        answerType: PollAnswerType = .singleChoice,
        announceType: PollAnnounceType = .everyone,
        displayMode: PollDisplayMode = .list,
        choices: [PollChoice] = [
            PollChoice(id: 0, description: "Choice 1"),
            PollChoice(id: 1, description: "Choice 2"),
        ],
        votes: PollVotes = .votes([:])
    ) -> LibthreemaPoll {
        LibthreemaPoll(
            id: id,
            conversation: conversation,
            creatorIdentity: creator,
            createdAt: createdAt,
            state: state,
            description: description,
            answerType: answerType,
            announceType: announceType,
            displayMode: displayMode,
            choices: choices,
            votes: votes
        )
    }

    private func persistedBallot(forPollID pollID: LibthreemaPollID) throws -> BallotEntity {
        try #require(entityManager.entityFetcher.ballotEntity(for: pollID.littleEndianData))
    }

    private func totalVotes(in ballot: BallotEntity) -> [UInt32: UInt16] {
        Dictionary(
            uniqueKeysWithValues: (ballot.choices ?? []).map { ($0.id.uint32Value, $0.totalVotes?.uint16Value ?? 0) }
        )
    }

    private func selectedChoiceIDs(for voter: String, in ballot: BallotEntity) -> Set<UInt32> {
        var selected: Set<UInt32> = []
        for choice in ballot.choices ?? [] {
            for result in choice.result ?? [] where result.participantID == voter && result.boolValue {
                selected.insert(choice.id.uint32Value)
            }
        }
        return selected
    }

    private func resultCount(for voter: String, in ballot: BallotEntity) -> Int {
        let allResults = (ballot.choices ?? []).flatMap { $0.result ?? [] }
        return allResults.count(where: { $0.participantID == voter })
    }
}
