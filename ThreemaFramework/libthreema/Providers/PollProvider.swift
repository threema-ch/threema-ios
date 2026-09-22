import Foundation
import libthreemaSwift
import ThreemaEssentials

public final class PollProvider: libthreemaSwift.PollProvider {

    nonisolated(unsafe) let entityManager: EntityManager

    private let batchSize: Int
    private let minimumChoiceCount = 2
    private let userIdentity: ThreemaIdentity

    public init(userIdentity: ThreemaIdentity, entityManager: EntityManager, batchSize: Int = 100) {
        self.userIdentity = userIdentity
        self.entityManager = entityManager
        self.batchSize = batchSize
    }

    public func getMany(batchIndex: UInt64) throws -> [libthreemaSwift.Poll] {
        // 1. Look up all polls of all contact and group conversations.
        // 2. Deterministically partition them into non-overlapping, incrementally zero-based numbered batches of
        //    about `batchCount` polls. The fetcher orders by the unique `id`, so paging with offset/limit yields a
        //    stable, non-overlapping partition (the surrounding protocol guarantees a read-only state while batching).
        // 3. Return the batch at `batchIndex`. An empty batch signals that no further polls are available.

        guard batchIndex <= UInt64(Int.max / batchSize) else {
            throw ProviderError.InvalidParameter("Invalid Parameter batchIndex too large for batchSize \(batchSize)")
        }

        let start = Int(batchIndex) * batchSize

        let entityFetcher = self.entityManager.entityFetcher

        return try entityManager.performAndWait {
            let ballotEntities = entityFetcher
                .ballotEntitiesInContactOrGroupConversations(
                    offset: start,
                    limit: self.batchSize
                )

            return try ballotEntities.map { ballotEntity in
                try libthreemaSwift.Poll(
                    ballotEntity: ballotEntity,
                    entityManager: self.entityManager,
                    userIdentity: self.userIdentity
                )
            }
        }
    }

    public func add(polls: [libthreemaSwift.Poll]) throws {
        // 1. For each poll:
        //     1. Let conversation be the associated conversation for `poll.conversation`.
        //     2. If conversation does not exist, throw `ProviderError.InvalidParameter`.
        //     3. If conversation refers to a distribution list, throw `ProviderError.InvalidParameter`.
        //     4. If a poll with `poll.id` already exists, throw `ProviderError.InvalidState`.
        //     5. If `poll.votes` is of type `PollVotes.votes`: for each voter that is not the local user, if the voter
        //        is not a known contact (any acquaintance level, including deleted), throw
        //        `ProviderError.InvalidState`.
        // 2. Add each poll to its associated conversation.

        do {
            try entityManager.performAndWaitSave {
                for poll in polls {
                    try self.validateUniqueness(of: poll)
                    try self.validateVoters(of: poll)
                    let conversation = try self.conversationEntity(for: poll.conversation)
                    try self.persistPoll(poll, in: conversation)
                }
            }
        }
        catch {
            entityManager.rollback()
            throw error
        }
    }

    // MARK: - Private helpers

    private func validateUniqueness(of poll: LibthreemaPoll) throws {
        // Catches both pre-existing ballots and in-batch duplicates (the fetch sees earlier pending inserts).
        if entityManager.entityFetcher.ballotEntity(for: poll.id.littleEndianData) != nil {
            throw ProviderError.InvalidState("A poll with id \(poll.id) already exists")
        }
    }

    private func validateVoters(of poll: LibthreemaPoll) throws {
        guard case let .votes(votes) = poll.votes else {
            return
        }

        for voter in votes.keys where voter != userIdentity.rawValue {
            if entityManager.entityFetcher.contactEntity(for: voter) == nil {
                throw ProviderError.InvalidState("Voter \(voter) is not a known contact")
            }
        }
    }

    private func conversationEntity(for conversationID: LibthreemaConversationID) throws -> ConversationEntity {
        switch conversationID {
        case let .contact(identity):
            guard let conversation = entityManager.entityFetcher.conversationEntity(for: identity) else {
                throw ProviderError.InvalidParameter("No conversation for contact \(identity)")
            }
            return conversation

        case let .group(libthreemaGroupIdentity):
            let groupIdentity = ThreemaEssentials.GroupIdentity(libthreemaGroupIdentity: libthreemaGroupIdentity)
            guard let conversation = entityManager.entityFetcher.conversationEntity(
                for: groupIdentity,
                myIdentity: userIdentity.rawValue
            ) else {
                throw ProviderError.InvalidParameter("No conversation for group \(groupIdentity)")
            }
            return conversation

        case .distributionList:
            throw ProviderError.InvalidParameter("Polls in distribution lists are not supported")
        }
    }

    private func persistPoll(_ poll: LibthreemaPoll, in conversation: ConversationEntity) throws {
        let entityCreator = entityManager.entityCreator

        let ballot = entityCreator.ballotEntity(id: poll.id.littleEndianData)
        ballot.conversation = conversation
        try ballot.update(with: poll)

        var choicesByID: [LibthreemaPollChoiceID: BallotChoiceEntity] = [:]
        for (index, pollChoice) in poll.choices.enumerated() {
            let choice = entityCreator.ballotChoiceEntity(
                ballotEntity: ballot,
                id: NSNumber(value: pollChoice.id)
            )
            choice.update(
                with: pollChoice,
                orderPosition: index
            )
            choicesByID[pollChoice.id] = choice
        }

        switch poll.votes {
        case let .summary(summary):
            for (choiceID, count) in summary {
                choicesByID[choiceID]?.totalVotes = NSNumber(value: count)
            }

        case let .votes(votes):
            for (voter, vote) in votes {
                let selectedChoiceIDs = Set(vote.choices)
                for (choiceID, choice) in choicesByID {
                    let result = entityCreator.ballotResultEntity(
                        participantID: voter,
                        ballotChoiceEntity: choice
                    )
                    result.update(
                        with: vote,
                        selected: selectedChoiceIDs.contains(choiceID)
                    )
                }
            }
        }
    }
}
