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

import Foundation

extension BallotEntity {
    @objc public enum BallotAssessmentType: Int {
        case single, multi
    }
    
    @objc public enum BallotType: Int {
        case closed, intermediate
    }
    
    @objc public enum BallotState: Int {
        case open, closed
    }
    
    @objc public enum BallotDisplayMode: Int {
        case list, summary
    }

    @objc public var isClosed: Bool {
        state?.intValue == BallotState.closed.rawValue
    }
    
    @objc public var isSummary: Bool {
        displayMode?.intValue == BallotDisplayMode.summary.rawValue
    }
    
    @objc public var isIntermediate: Bool {
        type?.intValue == BallotType.intermediate.rawValue
    }

    public var isMultipleChoice: Bool {
        assessmentType?.intValue == BallotAssessmentType.multi.rawValue
    }
    
    var participantCount: Int {
        // `participants` does not contain local user
        (participants?.count ?? 0) + 1
    }
    
    public var conversationParticipantsCount: Int {
        guard let conversation else {
            return 0
        }
        // `conversation.participants` does not contain local user
        return conversation.participants.count + 1
    }
    
    public var conversationParticipants: Set<ContactEntity>? {
        guard let conversation else {
            return nil
        }
        return conversation.participants
    }
    
    /// True if intermediate results can be viewed or ballot is closed
    @objc public var displayResults: Bool {
        type?.intValue == BallotType.intermediate.rawValue || state?.intValue == BallotState.closed.rawValue
    }
    
    public var choicesSortedByOrder: [BallotChoiceEntity] {
        guard let choices else {
            return []
        }
        return choices.sorted {
            guard let lhsOrderPosition = $0.orderPosition,
                  let rhsOrderPosition = $1.orderPosition else {
                return false
            }
            
            return Int(truncating: lhsOrderPosition) < Int(truncating: rhsOrderPosition)
        }
    }
    
    // MARK: - Public functions

    public func localIdentityDidVote(myIdentity: String) -> Bool {
        hasVoteForIdentity(myIdentity, myIdentity: myIdentity)
    }
    
    public func canEdit(myIdentity: String) -> Bool {
        creatorID == myIdentity && state?.intValue == BallotState.open.rawValue
    }

    public func close() {
        state = BallotState.closed.rawValue as NSNumber
    }
    
    public func numberOfReceivedVotes(myIdentity: String) -> Int {
        participantIDsThatVoted(myIdentity: myIdentity).count
    }
    
    public func voters(myIdentity: String) -> [ContactEntity] {
        
        guard let participants = conversation?.participants else {
            return []
        }
        
        let ids = participantIDsThatVoted(myIdentity: myIdentity)
        
        return participants.filter { ids.contains($0.identity) }
    }
    
    func nonVoters(myIdentity: String) -> [ContactEntity] {
        
        guard let participants = conversation?.participants else {
            return []
        }
        
        let ids = participantIDsThatVoted(myIdentity: myIdentity)
        
        return participants.filter { !ids.contains($0.identity) }
    }
    
    public func namesOfChoicesMostVotedFor() -> [String] {
        var highestVoteCount = 0
        var mostVotedFor: [String] = []
        
        for choice in choicesSortedByOrder {
            let choiceCount = choice.countResultsTrue()
            guard let name = choice.name, choiceCount > 0, choiceCount >= highestVoteCount else {
                continue
            }
            
            if choiceCount == highestVoteCount {
                mostVotedFor.append(name)
                continue
            }
            
            if choiceCount > highestVoteCount {
                highestVoteCount = choiceCount
                mostVotedFor.removeAll()
                mostVotedFor.append(name)
            }
        }
        
        return mostVotedFor
    }
    
    // MARK: - Private functions

    private func participantIDsThatVoted(myIdentity: String) -> Set<String> {
        guard let choices else {
            return []
        }
        
        var participantsIDs = Set<String>()
        for choice in choices {
            if let ids = choice.participantIDs(myIdentity: myIdentity) {
                participantsIDs = participantsIDs.union(ids)
            }
        }
        return participantsIDs
    }
    
    @objc public func hasVoteForIdentity(_ id: String, myIdentity: String) -> Bool {
        participantIDsThatVoted(myIdentity: myIdentity).contains(id)
    }
}
