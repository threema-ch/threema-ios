//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

/// Manages lists of participants and whether they are in normal or pending state
@GlobalGroupCallActor
final class ParticipantState {
    // MARK: - Internal Properties
    
    let localParticipant: LocalParticipant
    
    // MARK: - Private Properties
    
    private var pendingParticipants = Set<PendingRemoteParticipant>()
    private var joinedParticipants = Set<JoinedRemoteParticipant>()
    
    // MARK: - Lifecycle
    
    init(
        localParticipant: LocalParticipant,
        pendingParticipants: Set<PendingRemoteParticipant> = Set<PendingRemoteParticipant>(),
        joinedParticipants: Set<JoinedRemoteParticipant> = Set<JoinedRemoteParticipant>()
    ) {
        self.localParticipant = localParticipant
        self.pendingParticipants = pendingParticipants
        self.joinedParticipants = joinedParticipants
    }
    
    // MARK: - Update Functions
    
    func add(pending: PendingRemoteParticipant) {
        DDLogNotice("[GroupCall] \(#function) Added pending participant \(pending.participantID)")
        pendingParticipants.insert(pending)
    }
    
    /// Updates the promotion state
    /// - Parameter participant: The participant to promote
    /// - Returns: True if promoted, false if was already promoted
    func registerPromotion(of promotedParticipant: JoinedRemoteParticipant) throws {
        
        guard !joinedParticipants.contains(where: { $0.participantID == promotedParticipant.participantID }) else {
            throw GroupCallError.promotionError
        }
        
        removePendingParticipant(promotedParticipant.participantID)
        
        joinedParticipants.insert(promotedParticipant)
    }
    
    func remove(_ participantID: ParticipantID) {
        removePendingParticipant(participantID)
        removeParticipant(participantID)
    }
    
    func removePendingParticipant(_ participantID: ParticipantID) {
        guard let participant = pendingParticipants.first(where: { $0.participantID == participantID }) else {
            return
        }
        
        pendingParticipants.remove(participant)
    }
    
    func removeParticipant(_ participantID: ParticipantID) {
        guard let joinedParticipant = joinedParticipants.first(where: { $0.participantID == participantID }) else {
            return
        }
        
        joinedParticipants.remove(joinedParticipant)
    }
    
    func find(_ participantID: ParticipantID) -> RemoteParticipant? {
        if let pendingParticipant = findPendingParticipant(participantID) {
            return pendingParticipant
        }
        else if let participant = findJoinedParticipant(participantID) {
            return participant
        }
        return nil
    }
    
    private func findPendingParticipant(_ participantID: ParticipantID) -> PendingRemoteParticipant? {
        pendingParticipants.first(where: { $0.participantID == participantID })
    }
    
    private func findJoinedParticipant(_ participantID: ParticipantID) -> JoinedRemoteParticipant? {
        joinedParticipants.first(where: { $0.participantID == participantID })
    }
    
    func setRemoteContext(participantID: ParticipantID, remoteContext: RemoteContext) {
        if let index = joinedParticipants.firstIndex(where: { $0.participantID == participantID }) {
            joinedParticipants[index].setRemoteContext(remoteContext)
            DDLogNotice(
                "[GroupCall] updated transceivers for regular participant \(participantID)"
            )
        }
        else if let index = pendingParticipants.firstIndex(where: { $0.participantID == participantID }) {
            pendingParticipants[index].setRemoteContext(remoteContext)
            DDLogNotice(
                "[GroupCall] updated transceivers for pending participant \(participantID)"
            )
        }
        else {
            let msg = "[GroupCall] Could not set transceivers for participant \(participantID)"
            DDLogError("\(msg)")
            assertionFailure(msg)
        }
    }
}

extension ParticipantState {
    // State Getters; Required for Protocol Conformance
    func getCurrentParticipants() -> Set<JoinedRemoteParticipant> {
        joinedParticipants
    }
    
    func getPendingParticipants() -> Set<PendingRemoteParticipant> {
        pendingParticipants
    }
    
    func getLocalParticipant() -> LocalParticipant {
        localParticipant
    }
}
