import Foundation
import libthreemaSwift
import ThreemaEssentials

extension libthreemaSwift.Poll {
    init(ballotEntity: BallotEntity, entityManager: EntityManager, userIdentity: ThreemaIdentity) throws {
        let id: LibthreemaPollID = try ballotEntity.id.littleEndian()

        guard let conversationEntity = ballotEntity.conversation else {
            throw MappingError.ballotConversation
        }

        let conversation = try LibthreemaConversationID(
            conversationEntity: conversationEntity,
            entityManager: entityManager,
            userIdentity: userIdentity
        )

        try self.init(
            id: id,
            conversation: conversation,
            creatorIdentity: ballotEntity.creatorID.getOrThrow(MappingError.ballotCreator),
            createdAt: ballotEntity.createDate.getOrThrow(MappingError.ballotCreatedAt).millisecondsSince1970,
            state: PollState(ballotState: ballotEntity.state),
            description: ballotEntity.title.getOrThrow(MappingError.ballotTitle),
            answerType: PollAnswerType(ballotAssessmentType: ballotEntity.assessmentType),
            announceType: PollAnnounceType(ballotType: ballotEntity.type),
            displayMode: PollDisplayMode(ballotDisplayMode: ballotEntity.displayMode),
            choices: ballotEntity.choicesSortedByOrder.map { try PollChoice(ballotChoiceEntity: $0) },
            votes: PollVotes(ballotEntity: ballotEntity, userIdentity: userIdentity)
        )
    }
}

extension libthreemaSwift.PollChoice {
    init(ballotChoiceEntity: BallotChoiceEntity) throws {
        guard let description = ballotChoiceEntity.name, !description.isEmpty else {
            throw MappingError.ballotTitle
        }
        self.init(id: ballotChoiceEntity.id.uint32Value, description: description)
    }
}

extension libthreemaSwift.PollVotes {
    init(ballotEntity: BallotEntity, userIdentity: ThreemaIdentity) {
        // In summary mode individual votes are not known, we only the aggregate count per choice.
        if ballotEntity.isSummary {
            var summary: [LibthreemaPollChoiceID: UInt16] = [:]
            for choice in ballotEntity.choices ?? [] {
                summary[choice.id.uint32Value] = choice.totalVotes?.uint16Value ?? 0
            }

            let userChoices: Set<LibthreemaPollChoiceID> =
                if let choicesWithResult = ballotEntity.choices?.filter(
                    { $0.result != nil }
                ) {
                    Set(
                        choicesWithResult.filter(
                            { $0.result!.contains(where: { $0.participantID == userIdentity.rawValue }) }
                        ).map(\.id.uint32Value)
                    )
                }
                else {
                    Set()
                }

            self = .summary(PollVotesSummary(summary: summary, userChoices: userChoices))
            return
        }

        // Otherwise we invert the per-choice results (Core Data) into per-voter votes (libthreema).
        var choicesByVoter: [LibthreemaThreemaID: Set<LibthreemaPollChoiceID>] = [:]
        var createdAtByVoter: [LibthreemaThreemaID: UInt64] = [:]
        var modifiedAtByVoter: [LibthreemaThreemaID: UInt64] = [:]

        for choice in ballotEntity.choices ?? [] {
            let choiceID = choice.id.uint32Value
            for result in choice.result ?? [] {
                let voter = result.participantID

                // Record the voter even if they did not select this particular choice.
                if choicesByVoter[voter] == nil {
                    choicesByVoter[voter] = []
                }
                if result.boolValue {
                    choicesByVoter[voter]?.insert(choiceID)
                }

                if let createdAt = result.createDate?.millisecondsSince1970 {
                    createdAtByVoter[voter] = min(createdAtByVoter[voter] ?? createdAt, createdAt)
                }
                if let modifiedAt = result.modifyDate?.millisecondsSince1970 {
                    modifiedAtByVoter[voter] = max(modifiedAtByVoter[voter] ?? modifiedAt, modifiedAt)
                }
            }
        }

        let votes = choicesByVoter.reduce(into: [LibthreemaThreemaID: PollVote]()) { votes, entry in
            votes[entry.key] = PollVote(
                choices: entry.value,
                createdAt: createdAtByVoter[entry.key] ?? 0,
                modifiedAt: modifiedAtByVoter[entry.key]
            )
        }
        self = .votes(votes)
    }
}

extension libthreemaSwift.PollState {
    init(ballotState: NSNumber?) throws {
        guard let value = ballotState?.int32Value else {
            self = .open
            return
        }
        guard let state = PollState(rawValue: value) else {
            throw MappingError.ballotState
        }
        self = state
    }
}

extension libthreemaSwift.PollAnswerType {
    init(ballotAssessmentType: NSNumber?) throws {
        guard let value = ballotAssessmentType?.int32Value else {
            self = .singleChoice
            return
        }
        guard let answer = PollAnswerType(rawValue: value) else {
            throw MappingError.ballotAssessmentType
        }
        self = answer
    }
}

extension libthreemaSwift.PollAnnounceType {
    init(ballotType: NSNumber?) throws {
        guard let value = ballotType?.int32Value else {
            self = .creatorOnly
            return
        }
        guard let mode = PollAnnounceType(rawValue: value) else {
            throw MappingError.ballotType
        }
        self = mode
    }
}

extension libthreemaSwift.PollDisplayMode {
    init(ballotDisplayMode: NSNumber?) throws {
        guard let value = ballotDisplayMode?.int32Value else {
            self = .list
            return
        }
        guard let mode = PollDisplayMode(rawValue: value) else {
            throw MappingError.ballotDisplayMode
        }
        self = mode
    }
}
