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

import Foundation
import ThreemaEssentials
import ThreemaProtocols
import WebRTC
@testable import GroupCalls

final class MockGroupCallContext: GroupCallContextProtocol {

    var keyRefreshTask: Task<Void, Error>?

    var dependencies: Dependencies
    var groupCallMessageCrypto: GroupCallMessageCryptoProtocol
    
    var refreshTask: Task<Void, Never>?

    // MARK: - Test helper properties

    var handleCallCount = 0
    var updateParticipantCount = 0
    var updatePendingParticipantCount = 0
    
    let continuation: AsyncStream<PeerConnectionMessage>.Continuation
    
    // MARK: - Lifecycle
    
    init(dependencies: Dependencies, groupCallMessageCrypto: GroupCallMessageCryptoProtocol) {
        self.dependencies = dependencies
        self.groupCallMessageCrypto = groupCallMessageCrypto
        (self.messageStream, self.continuation) = AsyncStream.makeStream(of: PeerConnectionMessage.self)
    }
    
    func ratchetAndApplyNewKeys() throws {
        // Noop
    }
    
    func replaceAndApplyNewMediaKeys() throws {
        // Noop
    }
    
    func rekeyReceived(from: GroupCalls.JoinedRemoteParticipant, with mediaKeys: GroupCalls.MediaKeys) throws {
        // Noop
    }
    
    func removeDecryptor(for participant: GroupCalls.JoinedRemoteParticipant) throws {
        // Noop
    }
    
    // MARK: - Teardown

    func leave() {
        // Noop
    }
    
    // MARK: - Message Handling

    func handle(_ message: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) async -> GroupCalls
        .MessageResponseAction {
        handleCallCount += 1
        return GroupCalls.MessageResponseAction.none
    }
    
    // MARK: - Message Sending

    func outerEnvelope(for innerData: Data, to participant: GroupCalls.RemoteParticipant) -> ThreemaProtocols
        .Groupcall_ParticipantToParticipant.OuterEnvelope {
        // Noop
        ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope()
    }
    
    func verifyReceiver(for message: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) -> Bool {
        true
    }
   
    // MARK: - SFU State Updates

    func startStateUpdateTaskIfNecessary() throws {
        // Noop
    }
    
    // MARK: - State Updates

    func mapLocalTransceivers(
        ownAudioMuteState: GroupCalls.OwnMuteState,
        ownVideoMuteState: GroupCalls.OwnMuteState
    ) async throws {
        // Noop
    }
    
    func updateParticipants(
        add: [GroupCalls.ParticipantID],
        remove: [GroupCalls.ParticipantID],
        existingParticipants: Bool
    ) async throws {
        updateParticipantCount += 1
        for addParticipant in add {
            let participant = try PendingRemoteParticipant(
                participantID: addParticipant,
                dependencies: dependencies,
                groupCallMessageCrypto: groupCallMessageCrypto,
                isExistingParticipant: existingParticipants
            )
            
            pendingParticipants.insert(participant)
        }
    }
    
    // MARK: - Call State
    
    var pendingParticipants = Set<GroupCalls.PendingRemoteParticipant>()
    var joinedParticipants = Set<GroupCalls.JoinedRemoteParticipant>()
    
    var hasAnyParticipants: Bool {
        !pendingParticipants.isEmpty || !joinedParticipants.isEmpty
    }
    
    var messageStream: AsyncStream<GroupCalls.PeerConnectionMessage>
    
    func participant(with participantID: GroupCalls.ParticipantID) -> GroupCalls.JoinedRemoteParticipant? {
        nil
    }
    
    func myParticipantID() -> GroupCalls.ParticipantID {
        GroupCalls.ParticipantID(id: 0)
    }
    
    // MARK: -  Media Capture

    func stopVideoCapture() async {
        // Noop
    }
    
    func startVideoCapture(position: GroupCalls.CameraPosition?) async {
        // Noop
    }
    
    func stopAudioCapture() async {
        // Noop
    }
    
    func startAudioCapture() async {
        // Noop
    }
    
    func localVideoTrack() -> RTCVideoTrack? {
        nil
    }
    
    // MARK: - Connection

    func relay(_ relay: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) {
        // Noop
    }
    
    func send(_ data: Data) {
        // Noop
    }
    
    func send(_ envelope: ThreemaProtocols.Groupcall_ParticipantToSfu.Envelope) throws {
        // Noop
    }
}
