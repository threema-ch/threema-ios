//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

@GlobalGroupCallActor
/// Manages lists of participants and whether they are in normal or pending state
final class ParticipantStateActor {
    // MARK: - Internal Properties
    
    let localParticipant: LocalParticipant
    
    // MARK: - Private Properties
    
    // TODO: (IOS-4059) These should/could be sets. It doesn't make sense to have the same participant twice.
    // We also don't need ordering.
    private var pendingParticipants = [RemoteParticipant]()
    private var participants = [RemoteParticipant]()
    
    // MARK: - Lifecycle
    
    init(
        localParticipant: LocalParticipant,
        pendingParticipants: [RemoteParticipant] = [RemoteParticipant](),
        participants: [RemoteParticipant] = [RemoteParticipant]()
    ) {
        self.localParticipant = localParticipant
        self.pendingParticipants = pendingParticipants
        self.participants = participants
    }
    
    // MARK: - Update Functions
    
    func add(pending: RemoteParticipant) {
        DDLogNotice("[GroupCall] [Rekey] \(#function) Added pending participant \(pending.participantID.id)")
        pendingParticipants.append(pending)
    }
    
    /// Promotes the participant from pending to normal participant
    /// - Parameter participant: The participant to promote
    /// - Returns: True if promoted, false if was already promoted
    func promote(_ participant: RemoteParticipant) throws -> Bool {
        DDLogNotice("[GroupCall] [Rekey] \(#function) Promoted participant \(participant.participantID.id)")
        guard participant.isHandshakeCompleted else {
            throw GroupCallError.promotionError
        }
        
        guard !participants.contains(where: { $0.participantID == participant.participantID }) else {
            return false
        }
        
        pendingParticipants.removeAll(where: { $0.participantID == participant.participantID })
        participants.append(participant)
        
        return true
    }
    
    func remove(_ participantID: ParticipantID) {
        pendingParticipants.removeAll(where: { $0.participantID == participantID })
        participants.removeAll(where: { $0.participantID == participantID })
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
            DDLogError(msg)
            assertionFailure(msg)
        }
    }
}

extension ParticipantStateActor {
    // State Getters; Required for Protocol Conformance
    func getCurrentParticipants() -> [RemoteParticipant] {
        participants
    }
    
    func getPendingParticipants() -> [RemoteParticipant] {
        pendingParticipants
    }
    
    func getAllParticipants() -> [RemoteParticipant] {
        participants + pendingParticipants
    }
    
    func getLocalParticipant() -> LocalParticipant {
        localParticipant
    }
}
