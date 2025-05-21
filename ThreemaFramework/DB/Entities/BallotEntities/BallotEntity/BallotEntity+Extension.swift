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
    
    @objc var isOwn: Bool {
        // swiftformat:disable:next acronyms
        creatorId == MyIdentityStore.shared().identity
    }
    
    @objc var isClosed: Bool {
        state?.intValue == BallotState.closed.rawValue
    }
    
    @objc var isIntermediate: Bool {
        type?.intValue == BallotType.intermediate.rawValue
    }

    @objc var isMultipleChoice: Bool {
        assessmentType?.intValue == BallotAssessmentType.multi.rawValue
    }
    
    @objc var localIdentityDidVote: Bool {
        hasVoteForIdentity(MyIdentityStore.shared().identity)
    }
    
    @objc var canEdit: Bool {
        isOwn && state?.intValue == BallotState.open.rawValue
    }
    
    @objc var participantCount: Int {
        // `participants` does not contain local user
        (participants?.count ?? 0) + 1
    }
    
    @objc var conversationParticipantsCount: Int {
        guard let conversation else {
            return 0
        }
        // `conversation.participants` does not contain local user
        return conversation.participants.count + 1
    }
    
    /// True if intermediate results can be viewed or ballot is closed
    @objc var displayResults: Bool {
        type?.intValue == BallotType.intermediate.rawValue || state?.intValue == BallotState.closed.rawValue
    }
    
    @objc var choicesSortedByOrder: [BallotChoiceEntity] {
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

    @objc func close() {
        state = BallotState.closed.rawValue as NSNumber
    }
    
    @objc func numberOfReceivedVotes() -> Int {
        participantIDsThatVoted().count
    }
    
    @objc func voters() -> [ContactEntity] {
        
        guard let participants = conversation?.participants else {
            return []
        }
        
        let ids = participantIDsThatVoted()
        
        return participants.filter { ids.contains($0.identity) }
    }
    
    @objc func nonVoters() -> [ContactEntity] {
        
        guard let participants = conversation?.participants else {
            return []
        }
        
        let ids = participantIDsThatVoted()
        
        return participants.filter { !ids.contains($0.identity) }
    }
    
    @objc public func namesOfChoicesMostVotedFor() -> [String] {
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

    private func participantIDsThatVoted() -> Set<String> {
        guard let choices else {
            return []
        }
        
        var participantsIDs = Set<String>()
        for choice in choices {
            if let ids = choice.participantIDs() {
                participantsIDs = participantsIDs.union(ids)
            }
        }
        return participantsIDs
    }
    
    @objc public func hasVoteForIdentity(_ id: String) -> Bool {
        participantIDsThatVoted().contains(id)
    }
}
