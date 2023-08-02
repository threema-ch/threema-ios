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

import Foundation
import ThreemaProtocols
import WebRTC
@testable import GroupCalls

final class MockGroupCallCtx: GroupCallContextProtocol {
    
    var keyRefreshTask: Task<Void, Error>?
    
    func sendPostHandshakeMediaKeys(to remoteParticipant: GroupCalls.RemoteParticipant) async throws {
        // Noop
    }
    
    func removeDecryptor(for participant: GroupCalls.RemoteParticipant) throws {
        // Noop
    }
    
    func updatePendingParticipants(
        add: [GroupCalls.ParticipantID],
        remove: [GroupCalls.ParticipantID],
        existingParticipants: Bool
    ) async throws {
        for addParticipant in add {
            let participant = await RemoteParticipant(
                participant: addParticipant,
                dependencies: dependencies,
                groupCallCrypto: groupCallMessageCrypto,
                isExistingParticipant: existingParticipants
            )
            
            pendingParticipants.append(participant)
        }
    }
    
    var refreshTask: Task<Void, Never>?
    
    fileprivate var dependencies: Dependencies
    fileprivate var groupCallMessageCrypto: GroupCallMessageCryptoProtocol
    
    var cont: AsyncStream<PeerConnectionMessage>.Continuation
    
    init(dependencies: Dependencies, groupCallMessageCrypto: GroupCallMessageCryptoProtocol) {
        self.dependencies = dependencies
        self.groupCallMessageCrypto = groupCallMessageCrypto
        (self.messageStream, self.cont) = AsyncStream.makeStream(of: PeerConnectionMessage.self)
    }
    
    func mapLocalTransceivers(
        ownAudioMuteState: GroupCalls.OwnMuteState,
        ownVideoMuteState: GroupCalls.OwnMuteState
    ) async throws {
        // Noop
    }
    
    func updatePendingParticipants(add: [GroupCalls.ParticipantID], remove: [GroupCalls.ParticipantID]) async throws {
        for addParticipant in add {
            let participant = await RemoteParticipant(
                participant: addParticipant,
                dependencies: dependencies,
                groupCallCrypto: groupCallMessageCrypto,
                isExistingParticipant: true
            )
            
            pendingParticipants.append(participant)
        }
    }
    
    var pendingParticipants = [GroupCalls.RemoteParticipant]()
    
    var participants = [GroupCalls.RemoteParticipant]()
    
    func participant(with participantID: GroupCalls.ParticipantID) -> GroupCalls.RemoteParticipant? {
        nil
    }
    
    var messageStream: AsyncStream<GroupCalls.PeerConnectionMessage>
    
    func outerEnvelope(for innerData: Data, to participant: GroupCalls.RemoteParticipant) -> ThreemaProtocols
        .Groupcall_ParticipantToParticipant.OuterEnvelope {
        // Noop
        ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope()
    }
    
    func relay(_ relay: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) {
        // Noop
    }
    
    func send(_ data: Data) {
        // Noop
    }
    
    func send(_ envelope: ThreemaProtocols.Groupcall_ParticipantToSfu.Envelope) throws {
        // Noop
    }
    
    var hasVideoCapturer = true
    
    func stopVideoCapture() async {
        // Noop
    }
    
    func startVideoCapture() async {
        // Noop
    }
    
    func leave() {
        // Noop
    }
    
    func ratchetAndApplyNewKeys() throws {
        // Noop
    }
    
    func replaceAndApplyNewMediaKeys() throws {
        // Noop
    }
    
    func rekeyReceived(from: GroupCalls.RemoteParticipant, with mediaKeys: GroupCalls.MediaKeys) throws {
        // Noop
    }
    
    func myParticipantID() -> GroupCalls.ParticipantID {
        GroupCalls.ParticipantID(id: 0)
    }
    
    func verifyReceiver(for message: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) -> Bool {
        true
    }
    
    func handle(_ message: ThreemaProtocols.Groupcall_ParticipantToParticipant.OuterEnvelope) async -> GroupCalls
        .RemoteParticipant.MessageResponseAction {
        GroupCalls.RemoteParticipant.MessageResponseAction.none
    }
    
    func startStateUpdateTaskIfNecessary() throws {
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
    
    func numberOfParticipants() -> Int {
        participants.count
    }

    func numberOfPendingParticipants() -> Int {
        pendingParticipants.count
    }
    
    func localParticipant() -> GroupCalls.LocalParticipant? {
        nil
    }
    
    func localVideoTrack() -> RTCVideoTrack? {
        nil
    }
}
