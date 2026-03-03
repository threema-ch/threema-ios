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

extension BallotChoiceEntity {
    
    @objc public func getResultForIdentity(_ identity: String) -> BallotResultEntity? {
        guard let result, !result.isEmpty else {
            return nil
        }

        return result.first { $0.participantID == identity }
    }
    
    public func removeResultForIdentity(_ identity: String) {
        guard let result, !result.isEmpty, let managedObjectContext else {
            return
        }

        let filteredResults = result.filter { $0.participantID == identity }
        
        guard !filteredResults.isEmpty else {
            return
        }
        
        for filteredResult in filteredResults {
            removeFromResult(filteredResult)
            managedObjectContext.delete(filteredResult)
        }
    }
    
    func countResultsTrue() -> Int {
        guard let result, !result.isEmpty else {
            return 0
        }
        
        let filtered = result.filter(\.boolValue)
        return filtered.count
    }
    
    func participantIDsForResultsTrue(myIdentity: String) -> [String] {
        guard let result, !result.isEmpty else {
            return []
        }

        let filtered = result.filter { $0.boolValue && isParticipantGroupMember(
            identity: $0.participantID,
            myIdentity: myIdentity
        )
        }

        return filtered.map(\.participantID)
    }
    
    func participantIDs(myIdentity: String) -> Set<String>? {
        guard let result, !result.isEmpty else {
            return nil
        }

        return Set(
            result.filter { isParticipantGroupMember(identity: $0.participantID, myIdentity: myIdentity) }
                .map(\.participantID)
        )
    }
    
    private func isParticipantGroupMember(identity: String, myIdentity: String) -> Bool {
        if identity == myIdentity {
            return true
        }
        guard let participants = ballot.conversation?.participants else {
            return false
        }
        
        return participants.contains { $0.identity == identity }
    }
}
