//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import ThreemaMacros

// The goal of this struct is to move to using it as business object for `BallotEntity`, similarly to how we use
// `Contact` for `ContactEntity`.
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
        public let voters: [Voter]
        public let order: Int
    }

    public struct Voter: Identifiable, Hashable, Comparable {
        public let id = UUID()
        public let identity: String
        public let displayName: String
        public let profilePicture: UIImage?
        
        public static func < (lhs: Voter, rhs: Voter) -> Bool {
            lhs.identity < rhs.identity
        }
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
    public let nonRespondents: [Voter]
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
        
        var participants = participantsEntity.compactMap { participant -> Voter? in
            let identity = participant.identity
            let contact = Contact(contactEntity: participant)
            return Voter(
                identity: identity,
                displayName: contact.displayName,
                profilePicture: contact.profilePicture,
            )
        }
        participants.append(Voter(
            identity: identityStore.identity,
            displayName: identityStore.displayName(),
            profilePicture: identityStore.resolvedProfilePicture,
        ))
        
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
                .compactMap { voter -> Voter? in
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
        let nonRespondents = participants
            .filter { nonRespondentIDs.contains($0.identity) }
            .sorted()
        
        self.id = entity.objectID
        self.creator = creator
        self.created = entity.createDate
        self.isClosed = entity.isClosed
        self.isSummary = entity.isSummary
        self.isIntermediate = entity.isIntermediate
        self.isMultiSelection = entity.isMultipleChoice
        self.title = entity.title ?? ""
        self.nonRespondents = nonRespondents
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
