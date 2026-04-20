import ThreemaMacros

public struct Poll: Identifiable, Hashable {

    // MARK: Internal types

    public enum Creator: Hashable {
        case me
        case other(displayName: String)

        public var label: String {
            switch self {
            case .me:
                #localize("me")
            case let .other(displayName):
                displayName
            }
        }
    }

    public enum ChoiceSortOrder {
        case order
        case votes
    }

    public struct VoteCount: Hashable {
        public let countParticipants: Int
        public let countVotes: Int
    }

    public struct Choice: Identifiable, Hashable {
        public let id: NSManagedObjectID
        public let text: String
        public let votes: Int
        public let voters: [PollVoter]
        public let order: Int
    }

    // MARK: - Properties

    public let id: NSManagedObjectID
    public let title: String?
    public let creator: Creator?
    public let created: Date?
    public let isClosed: Bool
    public let isSummary: Bool
    public let isIntermediate: Bool
    public let isMultiSelection: Bool
    public let choices: [Choice]
    public let nonRespondents: [PollVoter]
    public let voteCountInfo: VoteCount

    // MARK: - Lifecycle

    public init(
        for entity: BallotEntity,
        creator: Poll.Creator? = nil,
        sortOrder: ChoiceSortOrder = .order,
        identityStore: MyIdentityStoreProtocol
    ) {
        let entityChoices = entity.choices ?? []
        let participantsEntity = entity.conversationParticipants ?? []

        var participants = participantsEntity.compactMap { participant -> PollVoter? in
            let identity = participant.identity
            let contact = Contact(contactEntity: participant)
            return PollVoter(
                identity: identity,
                displayName: contact.displayName,
                source: .contact(participant)
            )
        }

        let identityVoter = PollVoter(
            identity: identityStore.identity,
            displayName: identityStore.displayName(),
            source: .me(identityStore)
        )

        participants.append(identityVoter)

        let choices = entityChoices.map { element in
            let text = element.name ?? ""
            let order = element.orderPosition?.intValue ?? 0

            guard let resultSet = element.result else {
                return Choice(
                    id: element.objectID,
                    text: text,
                    votes: 0,
                    voters: [],
                    order: order
                )
            }

            let voters = resultSet
                .filter { $0.value?.boolValue == true }
                .compactMap { voter -> PollVoter? in
                    participants.first { participant in
                        participant.identity == voter.participantID
                    }
                }
                .sorted()

            return Choice(
                id: element.objectID,
                text: text,
                votes: element.totalVotes?.intValue ?? voters.count,
                voters: voters,
                order: order
            )
        }

        let allVoterIDs = Set(participants.map(\.identity))
        let respondedIDs = Set(choices.flatMap { $0.voters.map(\.identity) })
        let nonRespondentIDs = allVoterIDs.subtracting(respondedIDs)

        self.id = entity.objectID
        self.creator = creator
        self.created = entity.createDate
        self.isClosed = entity.isClosed
        self.isSummary = entity.isSummary
        self.isIntermediate = entity.isIntermediate
        self.isMultiSelection = entity.isMultipleChoice
        self.title = entity.title ?? ""
        self.nonRespondents = participants.filter { nonRespondentIDs.contains($0.identity) }.sorted()
        self.voteCountInfo = VoteCount(
            countParticipants: entity.conversationParticipantsCount,
            countVotes: entity.numberOfReceivedVotes(myIdentity: identityStore.identity)
        )

        switch sortOrder {
        case .order:
            self.choices = choices.sorted { $0.order < $1.order }
        case .votes:
            self.choices = choices.sorted {
                if $0.votes == $1.votes {
                    return $0.order < $1.order
                }
                return $0.votes > $1.votes
            }
        }
    }
}
