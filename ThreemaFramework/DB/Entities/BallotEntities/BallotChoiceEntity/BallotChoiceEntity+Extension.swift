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
    
    @objc func getResultForLocalIdentity() -> BallotResultEntity? {
        getResultForIdentity(MyIdentityStore.shared().identity)
    }
    
    @objc func getResultForIdentity(_ identity: String) -> BallotResultEntity? {
        guard let result, !result.isEmpty else {
            return nil
        }
        // swiftformat:disable:next acronyms
        return result.first { $0.participantId == identity }
    }
    
    @objc func removeResultForIdentity(_ identity: String) {
        guard let result, !result.isEmpty, let managedObjectContext else {
            return
        }
        // swiftformat:disable:next acronyms
        let filteredResults = result.filter { $0.participantId == identity }
        
        guard !filteredResults.isEmpty else {
            return
        }
        
        for filteredResult in filteredResults {
            removeFromResult(filteredResult)
            managedObjectContext.delete(filteredResult)
        }
    }
    
    @objc func countResultsTrue() -> Int {
        guard let result, !result.isEmpty else {
            return 0
        }
        
        let filtered = result.filter(\.boolValue)
        return filtered.count
    }
    
    @objc func participantIDsForResultsTrue() -> [String] {
        guard let result, !result.isEmpty else {
            return []
        }
        // swiftformat:disable:next acronyms
        let filtered = result.filter { $0.boolValue && isParticipantGroupMember(identity: $0.participantId) }
        
        // swiftformat:disable:next acronyms
        return filtered.map(\.participantId)
    }
    
    @objc func participantIDs() -> Set<String>? {
        guard let result, !result.isEmpty else {
            return nil
        }
        // swiftformat:disable:next acronyms
        return Set(result.filter { isParticipantGroupMember(identity: $0.participantId) }.map(\.participantId))
    }
    
    private func isParticipantGroupMember(identity: String) -> Bool {
        if identity == MyIdentityStore.shared().identity {
            return true
        }
        guard let participants = ballot.conversation?.participants else {
            return false
        }
        
        return participants.contains { $0.identity == identity }
    }
}
