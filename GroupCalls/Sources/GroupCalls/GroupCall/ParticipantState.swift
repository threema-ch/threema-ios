//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
    
    private var pendingParticipants = Set<RemoteParticipant>()
    private var participants = Set<RemoteParticipant>()
    
    // MARK: - Lifecycle
    
    init(
        localParticipant: LocalParticipant,
        pendingParticipants: Set<RemoteParticipant> = Set<RemoteParticipant>(),
        participants: Set<RemoteParticipant> = Set<RemoteParticipant>()
    ) {
        self.localParticipant = localParticipant
        self.pendingParticipants = pendingParticipants
        self.participants = participants
    }
    
    // MARK: - Update Functions
    
    func add(pending: RemoteParticipant) {
        DDLogNotice("[GroupCall] \(#function) Added pending participant \(pending.participantID.id)")
        pendingParticipants.insert(pending)
    }
    
    /// Promotes the participant from pending to normal participant
    /// - Parameter participant: The participant to promote
    /// - Returns: True if promoted, false if was already promoted
    func promote(_ participant: RemoteParticipant) throws -> Bool {
        DDLogNotice("[GroupCall] \(#function) Promoted participant \(participant.participantID.id)")
        guard participant.isHandshakeCompleted else {
            throw GroupCallError.promotionError
        }
        
        guard !participants.contains(where: { $0.participantID == participant.participantID }) else {
            return false
        }
        
        pendingParticipants.remove(participant)
        participants.insert(participant)
        
        return true
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
        guard let participant = participants.first(where: { $0.participantID == participantID }) else {
            return
        }
        
        participants.remove(participant)
    }
    
    func setRemoteContext(participantID: ParticipantID, remoteContext: RemoteContext) {
        if let index = participants.firstIndex(where: { $0.participantID == participantID }) {
            participants[index].setRemoteContext(remoteContext)
            DDLogNotice(
                "[GroupCall] updated transceivers for regular participant \(participantID.id)"
            )
        }
        else if let index = pendingParticipants.firstIndex(where: { $0.participantID == participantID }) {
            pendingParticipants[index].setRemoteContext(remoteContext)
            DDLogNotice(
                "[GroupCall] updated transceivers for pending participant \(participantID.id)"
            )
        }
        else {
            let msg = "[GroupCall] Could not set transceivers for participant \(participantID.id)"
            DDLogError("\(msg)")
            assertionFailure(msg)
        }
    }
}

extension ParticipantState {
    // State Getters; Required for Protocol Conformance
    func getCurrentParticipants() -> Set<RemoteParticipant> {
        participants
    }
    
    func getPendingParticipants() -> Set<RemoteParticipant> {
        pendingParticipants
    }
    
    func getAllParticipants() -> Set<RemoteParticipant> {
        participants.union(pendingParticipants)
    }
    
    func getLocalParticipant() -> LocalParticipant {
        localParticipant
    }
}
