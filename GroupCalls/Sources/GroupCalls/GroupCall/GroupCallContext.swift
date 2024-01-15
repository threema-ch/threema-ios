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
import CryptoKit
import Foundation
import ThreemaEssentials
import ThreemaProtocols
import WebRTC

@GlobalGroupCallActor
protocol GroupCallContextProtocol: AnyObject {
    // MARK: Internal Properties
    
    var pendingParticipants: [RemoteParticipant] { get }
    var participants: [RemoteParticipant] { get }
    
    func localParticipant() -> LocalParticipant?

    var messageStream: AsyncStream<PeerConnectionMessage> { get }
    
    var keyRefreshTask: Task<Void, Error>? { get }
        
    // MARK: - SFU Connection
    
    func outerEnvelope(for innerData: Data, to participant: RemoteParticipant)
        -> Groupcall_ParticipantToParticipant.OuterEnvelope
    
    func relay(_ relay: Groupcall_ParticipantToParticipant.OuterEnvelope) throws
    
    func send(_ data: Data)
    
    func send(_ envelope: Groupcall_ParticipantToSfu.Envelope) throws
    
    // MARK: Media Capture

    // TODO: (IOS-4085) Remove
    var hasVideoCapturer: Bool { get }
    
    func stopVideoCapture() async
    func startVideoCapture(position: CameraPosition?) async throws
    
    func stopAudioCapture() async
    func startAudioCapture() async
    
    func localVideoTrack() -> RTCVideoTrack?

    // MARK: Frame Crypto
    
    func ratchetAndApplyNewKeys() throws
    func replaceAndApplyNewMediaKeys() async throws
    func sendPostHandshakeMediaKeys(to remoteParticipant: RemoteParticipant) async throws
    
    func rekeyReceived(from: RemoteParticipant, with mediaKeys: MediaKeys) throws
    
    func removeDecryptor(for participant: RemoteParticipant) throws
    
    // MARK: Call State
    
    func startStateUpdateTaskIfNecessary() throws
    
    func myParticipantID() -> ParticipantID
    
    func verifyReceiver(for message: Groupcall_ParticipantToParticipant.OuterEnvelope) -> Bool
    
    func handle(_ message: Groupcall_ParticipantToParticipant.OuterEnvelope) async throws
        -> RemoteParticipant.MessageResponseAction
    
    func mapLocalTransceivers(ownAudioMuteState: OwnMuteState, ownVideoMuteState: OwnMuteState) async throws
    
    func updatePendingParticipants(
        add: [ParticipantID],
        remove: [ParticipantID],
        existingParticipants: Bool
    ) async throws
    
    func participant(with participantID: ParticipantID) -> RemoteParticipant?
    
    func leave() async
}

@GlobalGroupCallActor
final class GroupCallContext<
    PeerConnectionCtxImpl: PeerConnectionContextProtocol,
    RTCRtpTransceiverImpl: RTCRtpTransceiverProtocol
>: Sendable, GroupCallContextProtocol {
    
    var keyRefreshTask: Task<Void, Error>?
    
    // MARK: Private variables
    
    private let connectionContext: ConnectionContext<PeerConnectionCtxImpl, RTCRtpTransceiverImpl>
    private let participantState: ParticipantStateActor
    private let groupCallBaseState: GroupCallBaseState
    
    private var dependencies: Dependencies
    
    // MARK: - Helper Variables
    
    /// The current group call state refresh task
    private var refreshTask: Task<Void, Error>?
    
    init(
        connectionContext: ConnectionContext<PeerConnectionCtxImpl, RTCRtpTransceiverImpl>,
        localParticipant: LocalParticipant,
        dependencies: Dependencies,
        groupCallDescription: GroupCallBaseState
    ) throws {
        DDLogNotice("[GroupCall] \(#function)")
        
        self.connectionContext = connectionContext
        self.participantState = ParticipantStateActor(localParticipant: localParticipant)
        self.dependencies = dependencies
        self.groupCallBaseState = groupCallDescription
        
        localParticipant.createNewMediaKeys()
        try groupCallDescription.applyMediaKeys(from: localParticipant)
    }
    
    func ratchetAndApplyNewKeys() throws {
        DDLogNotice("[GroupCall] \(#function)")
        
        /// **Protocol Step: Join/Leave of Other Participants (Join 3.)**
        /// Join 3. Advance the ratchet of `pcmk` once (i.e. replace the key by deriving PCMK') and apply for media
        /// encryption immediately. Note: Do **not** reset the MFSN!
        try participantState.localParticipant.ratchetMediaKeys()
        try groupCallBaseState.applyMediaKeys(from: participantState.localParticipant)
    }
    
    func sendPostHandshakeMediaKeys(to remoteParticipant: RemoteParticipant) async throws {
        DDLogNotice(
            "[GroupCall] [Rekey] Send Immedate Post Handshake Rekey to Participant \(remoteParticipant.participantID.id) which has received old keys in the authentication message"
        )
        
        let currentKeys = participantState.localParticipant.protocolMediaKeys
        let innerRekeyMessage = try remoteParticipant.rekeyMessage(with: currentKeys)
        let outerEnvelope = outerEnvelope(for: innerRekeyMessage, to: remoteParticipant)
        try relay(outerEnvelope)
    }
    
    /// **Protocol Step: Join/Leave of Other Participants (Leave 1. - 6.)**
    func replaceAndApplyNewMediaKeys() async throws {
        DDLogNotice("[GroupCall] [Rekey] \(#function)")
        
        // TODO: (IOS-4047) Are the following two canceling tasks needed?
        
        await Task.yield()
        guard !Task.isCancelled else {
            DDLogNotice("[GroupCall] [Rekey] Task was cancelled. Do not proceed with media key update.")
            keyRefreshTask = nil
            return
        }
        
        if let keyRefreshTask {
            guard !keyRefreshTask.isCancelled else {
                DDLogNotice("[GroupCall] [Rekey] Task was cancelled. Do not proceed with media key update.")
                return
            }
        }

        do {
            /// **Protocol Step: Join/Leave of Other Participants (Leave 1. - 4.)**
            /// When a participant leaves, all other participants run the following steps:
            try participantState.localParticipant.replaceAndApplyNewMediaKeys()
        }
        catch LocalParticipant.Error.existingPendingMediaKeys {
            /// **Protocol Step: Join/Leave of Other Participants (Leave 2. second part)**
            /// [...] abort these steps.
            return
        }
        catch {
            let message = "[GroupCall] An unexpected error happened during media key replacement: \(error)"
            DDLogError(message)
            assertionFailure(message)
            throw error
        }
        
        /// **Protocol Step: Join/Leave of Other Participants (Leave 5.)**
        /// Leave 5. Send pending-pcmk to all authenticated participants via a _rekey_ message.
        
        guard let pendingProtocolMediaKeys = participantState.localParticipant.pendingProtocolMediaKeys else {
            DDLogNotice("[GroupCall] Expected to have pending media keys but we do not have any.")
            throw GroupCallError.localProtocolViolation
        }
        
        let preRekeyCurrentParticipants = participantState.getCurrentParticipants()
        
        for participant in preRekeyCurrentParticipants {
            let innerRekeyMessage = try participant.rekeyMessage(with: pendingProtocolMediaKeys)
            let outerEnvelope = outerEnvelope(for: innerRekeyMessage, to: participant)
            try relay(outerEnvelope)
        }
        
        if let keyRefreshTask {
            // This should normally not happen as we have stale keys if this is the case and we abort above
            DDLogNotice("[GroupCall] [Rekey] Wait for previous rekey to finish")
            try await keyRefreshTask.value
            self.keyRefreshTask = nil
            return
        }
        
        /// **Protocol Step: Join/Leave of Other Participants (Leave 6.)**
        /// Leave 6. Schedule a task to run the following steps after 2s:
        keyRefreshTask = Task {
            try await Task.sleep(seconds: 2)
            
            DDLogNotice("[GroupCall] [Rekey] Protocol Step 6.")
            
            // TODO: (IOS-4131) This probably fixes IOS-4131
            // Not-Protocol Step: Send New Media Key to all participants that have been added since we created the new
            // key but have received the old key as the key was not yet rotated
            
            let participantsAddedSincePendingKeyWasCreated = participantState.getCurrentParticipants()
                .filter { participant in
                    !preRekeyCurrentParticipants.contains(where: { $0.participantID == participant.participantID })
                }
            
            for participant in participantsAddedSincePendingKeyWasCreated {
                DDLogNotice("[GroupCall] [Rekey] Send rekey to \(participant.participantID.id)")
                
                let innerRekeyMessage = try participant.rekeyMessage(with: pendingProtocolMediaKeys)
                let outerEnvelope = outerEnvelope(for: innerRekeyMessage, to: participant)
                try relay(outerEnvelope)
            }
            
            /// **Protocol Step: Join/Leave of Other Participants (Leave 6.1.)**
            /// Leave 6.1. Apply `pending-pcmk` for media encryption. This means that `pending-pcmk` now replaces the
            /// _applied_ PCMK and is no longer _pending_.
            DDLogNotice("[GroupCall] [Rekey] Protocol Step 6.1.")
            let wasStale = try self.participantState.localParticipant.switchCurrentForPendingKeys()
            
            await Task.yield()
            guard !Task.isCancelled else {
                DDLogNotice("[GroupCall] [Rekey] Task was cancelled. Do not proceed with media key update.")
                keyRefreshTask = nil
                return
            }
            
            try self.groupCallBaseState.applyMediaKeys(from: self.participantState.localParticipant)
            
            // TODO: (IOS-4047) Is this the right place to reset this reference?
            keyRefreshTask = nil
            
            /// **Protocol Step: Join/Leave of Other Participants (Leave 6.2)**
            /// Leave 6.2 If `pending-pcmk` is marked as _stale_, run the parent steps from the beginning.
            if wasStale {
                await Task.yield()
                Task {
                    try await self.replaceAndApplyNewMediaKeys()
                }
            }
        }
    }
    
    func rekeyReceived(from remoteParticipant: RemoteParticipant, with mediaKeys: MediaKeys) throws {
        try groupCallBaseState.apply(mediaKeys: mediaKeys, for: remoteParticipant.participantID)
    }
    
    func removeDecryptor(for participant: RemoteParticipant) throws {
        try groupCallBaseState.removeDecryptor(for: participant.participantID)
    }
}

// MARK: - Teardown

extension GroupCallContext {
    func leave() async {
        DDLogVerbose("[GroupCall] Leave: GroupCallContext")

        keyRefreshTask?.cancel()
        keyRefreshTask = nil
        
        refreshTask?.cancel()
        refreshTask = nil
        
        await connectionContext.teardown()
        
        groupCallBaseState.disposeFrameCryptoContext()
    }
}

// MARK: - Message Handling

extension GroupCallContext {
    func handle(
        _ message: Groupcall_ParticipantToParticipant.OuterEnvelope
    ) async throws -> RemoteParticipant.MessageResponseAction {
        
        /// **Protocol Step: ParticipantToParticipant.OuterEnvelope (Receiving 1.)**
        /// Receiving 1. If the `receiver` is not the user's assigned participant id, discard the message and abort
        /// these steps.
        guard verifyReceiver(for: message) else {
            fatalError()
        }
        
        /// **Protocol Step: ParticipantToParticipant.OuterEnvelope (Receiving 2.)**
        /// Receiving 2. If the `sender` is unknown, discard the message and abort these steps.
        guard let participant = participantState.getAllParticipants()
            .first(where: { $0.participantID.id == message.sender })
        else {
            DDLogError("Could not find participant for message from  \(message.sender) \(message.debugDescription)")
            return .none
        }
        
        /// **Protocol Step: ParticipantToParticipant.OuterEnvelope (Receiving 3.)**
        let message = try participant.handle(message: message, localParticipant: participantState.localParticipant)
        
        // If the handshake was completed, and the participant is no longer pending, we add the decryptor
        if participant.isHandshakeCompleted {
            DDLogNotice("[GroupCall] Promote RemoteParticipant \(participant.participantID.id) from pending.")
            if try participantState.promote(participant) {
                DDLogNotice("[GroupCall] Add decryptor for \(participant.participantID.id).")
                try await groupCallBaseState.addDecryptor(to: participant)
            }
        }
            
        return message
    }
}

// MARK: - Message Sending

extension GroupCallContext {
    func outerEnvelope(for innerData: Data, to participant: RemoteParticipant) -> Groupcall_ParticipantToParticipant
        .OuterEnvelope {
        var outer = Groupcall_ParticipantToParticipant.OuterEnvelope()
        outer.receiver = participant.participantID.id
        outer.sender = participantState.localParticipant.participantID.id
        outer.encryptedData = innerData
            
        return outer
    }
    
    /// Are we the intended receiver?
    @inlinable
    func verifyReceiver(for message: Groupcall_ParticipantToParticipant.OuterEnvelope) -> Bool {
        message.receiver == participantState.localParticipant.participantID.id
    }
}

// MARK: - SFU State Updates

extension GroupCallContext {
    /// **Protocol Step: State Update (all)**
    func startStateUpdateTaskIfNecessary() throws {
        
        /// **Protocol Step: State Update (1. - 5.)**
        /// 1. Cancel any running timer to update the call state. (We spit that)
        /// 2. Let `candidates` be a list of all currently authenticated non-guest participants.
        /// 3. If `candidates` is empty, add all currently authenticated guest participants to the list. (There are no
        /// guest participants for now.)
        /// 4. If the user is not in `candidates`, abort these steps.
        /// 5. If the user does not have the lowest participant ID in `candidates`, abort these steps.
        
        if let minOtherParticipantID = participants.map(\.participantID.id).min(),
           myParticipantID().id > minOtherParticipantID {
            refreshTask?.cancel()
            refreshTask = nil
            return
        }
        
        guard refreshTask == nil else {
            return
        }
        
        refreshTask = Task {
            while !Task.isCancelled {
                
                /// **Protocol Step: State Update (6.)**
                /// 6. Send a `ParticipantToSfu.UpdateCallState` message to the SFU and schedule a repetitive timer to
                /// repeat this step every 10s.
                try sendCallStateUpdateToSfu()
                try await Task.sleep(seconds: 10)
            }
        }
    }
    
    private func sendCallStateUpdateToSfu() throws {
        let groupCallState = try Groupcall_ParticipantToSfu.UpdateCallState.with {
            $0.encryptedCallState = try encryptedCallState(from: participants)
        }
        
        let outer = Groupcall_ParticipantToSfu.Envelope.with {
            $0.updateCallState = groupCallState
            $0.padding = dependencies.groupCallCrypto.padding()
        }
        
        let serializedOuter = try outer.ownSerializedData()
        
        DDLogNotice("[GroupCall] Update Call State")
        connectionContext.send(serializedOuter)
    }
}

// MARK: - State Updates

extension GroupCallContext {
    func mapLocalTransceivers(ownAudioMuteState: OwnMuteState, ownVideoMuteState: OwnMuteState) async throws {
        try await connectionContext.mapLocalTransceivers(
            ownAudioMuteState: ownAudioMuteState,
            ownVideoMuteState: ownVideoMuteState
        )
    }
    
    func updatePendingParticipants(
        add: [ParticipantID],
        remove: [ParticipantID],
        existingParticipants: Bool
    ) async throws {
        for participantID in remove {
            participantState.remove(participantID)
        }
        
        try await connectionContext.updateCall(call: participantState, remove: Set(remove), add: [])
        
        for participant in add {
            let newParticipant = RemoteParticipant(
                participantID: ParticipantID(id: participant.id),
                dependencies: dependencies,
                groupCallMessageCrypto: groupCallBaseState,
                isExistingParticipant: existingParticipants
            )
            
            participantState.add(pending: newParticipant)
        }
        
        try await connectionContext.updateCall(call: participantState, remove: Set(remove), add: Set(add))
    }
}

// MARK: - Call State

extension GroupCallContext {
    var pendingParticipants: [RemoteParticipant] {
        // TODO: (IOS-4059) Properly separate pending and other participants
        participantState.getPendingParticipants()
    }
    
    var participants: [RemoteParticipant] {
        participantState.getCurrentParticipants()
    }
    
    var messageStream: AsyncStream<PeerConnectionMessage> {
        connectionContext.messageStream
    }
    
    func participant(with participantID: ParticipantID) -> RemoteParticipant? {
        guard let participant = participants.filter({ $0.participantID == participantID }).first else {
            DDLogWarn("[GroupCall] Could not find RemoteParticipant with id: \(participantID.id) in participants")
            #if DEBUG
                if pendingParticipants.filter({ $0.participantID == participantID }).first != nil {
                    DDLogError(
                        "[GroupCall] RemoteParticipant was not found in participants but in pending participants. This might be an issue in participant state handling."
                    )
                }
            #endif
            return nil
        }
        
        return participant
    }
    
    func localParticipant() -> LocalParticipant? {
        participantState.localParticipant
    }
    
    func myParticipantID() -> ParticipantID {
        participantState.localParticipant.participantID
    }
}

// MARK: Media Capture

extension GroupCallContext {
    var hasVideoCapturer: Bool {
        connectionContext.videoCapturer != nil
    }
    
    func stopVideoCapture() async {
        await connectionContext.videoCapturer?.stopCapture()
    }
    
    func startVideoCapture(position: CameraPosition?) async throws {
        try await connectionContext.startVideoCapture(position: position)
    }
    
    func stopAudioCapture() async {
        await connectionContext.updateAudioMute(with: .muted)
    }

    func startAudioCapture() async {
        await connectionContext.updateAudioMute(with: .unmuted)
    }
    
    func localVideoTrack() -> RTCVideoTrack? {
        connectionContext.localVideoTrack()
    }
}

// MARK: - Connection

extension GroupCallContext {
    func relay(_ relay: Groupcall_ParticipantToParticipant.OuterEnvelope) throws {
        try connectionContext.relay(relay)
    }
    
    func send(_ data: Data) {
        connectionContext.send(data)
    }
    
    func send(_ envelope: Groupcall_ParticipantToSfu.Envelope) throws {
        let serialized = try envelope.ownSerializedData()
        connectionContext.send(serialized)
    }
}

// MARK: - Protobuf Helpers

extension GroupCallContext {
    private func encryptedCallState(from allParticipants: [RemoteParticipant]) throws -> Data {
        let callState = groupCallState(from: allParticipants)
        let serialized = try callState.ownSerializedData()
        let nonce = dependencies.groupCallCrypto.randomBytes(of: 24)
        
        guard let encryptedState = groupCallBaseState.symmetricEncryptByGSCK(serialized, nonce: nonce) else {
            throw GroupCallError.encryptionFailure
        }
        
        var encrypted = nonce
        encrypted.append(encryptedState)
        
        return encrypted
    }
    
    private func groupCallState(from participants: [RemoteParticipant]) -> Groupcall_CallState {
        var callState = Groupcall_CallState()
        callState.stateCreatedAt = UInt64(Date().timeIntervalSinceReferenceDate)
        callState.stateCreatedBy = participantState.localParticipant.participantID.id
        callState.participants = groupCallParticipants(from: participants)
        
        return callState
    }
    
    private func groupCallParticipants(from participants: [RemoteParticipant])
        -> [UInt32: Groupcall_CallState.Participant] {
        var dict = [UInt32: Groupcall_CallState.Participant]()
        
        for participant in participants {
            var gcParticipant = Groupcall_CallState.Participant.Normal()
            guard let identity = participant.threemaIdentity else {
                // In the future this could be a guest participant
                DDLogError(
                    "[GroupCall] Cannot add participant with id \(participant.participantID.id) to state update because it doesn't have an associated Threema ID."
                )
                continue
            }
            
            gcParticipant.identity = identity.string
            gcParticipant.nickname = participant.nickname ?? identity.string

            var test = Groupcall_CallState.Participant()
            test.threema = gcParticipant
            
            dict[participant.participantID.id] = test
        }
        
        return dict
    }
}
