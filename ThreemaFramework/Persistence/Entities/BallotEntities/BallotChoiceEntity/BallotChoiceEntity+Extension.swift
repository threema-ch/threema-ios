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
