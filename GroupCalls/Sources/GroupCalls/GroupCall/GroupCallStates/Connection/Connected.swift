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

import AsyncAlgorithms
import CocoaLumberjackSwift
import CryptoKit
import Foundation
import ThreemaProtocols
import WebRTC

// MARK: - Nested Types

extension Connected {
    fileprivate enum StateStreamValue {
        case buffer(PeerConnectionMessage)
        case uiAction(GroupCallUIAction)
    }
    
    fileprivate enum ProcessResult {
        case success
        case ended
    }
}

@GlobalGroupCallActor
struct Connected: GroupCallState {
    
    // MARK: - Private Properties
    
    private let groupCallActor: GroupCallActor
    private let groupCallContext: GroupCallContextProtocol
    private let participantIDs: [UInt32]
    private let emptyCallTimeout: EmptyCallTimeout
    
    // MARK: - Lifecycle
    
    init(
        groupCallActor: GroupCallActor,
        groupCallContext: GroupCallContextProtocol,
        participantIDs: [UInt32]
    ) {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Init Connected \(groupCallActor.callID)")
        self.groupCallActor = groupCallActor
        self.groupCallContext = groupCallContext
        self.participantIDs = participantIDs
        self.emptyCallTimeout = EmptyCallTimeout(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
    }
    
    func next() async throws -> GroupCallState? {
        DDLogNotice("[GroupCall] Connected `next()` in \(groupCallActor.callID)")
        
        /// **Protocol Step: Group Call Join Steps**
        /// 8. The group call is now considered established and should asynchronously
        ///   invoke the SFU to Participant and Participant to Participant flows.
        /// Note: This is done via the state change in the `GroupCallActor`.
        
        if Task.isCancelled {
            // Teardown
            await groupCallContext.leave()
            // TODO: (IOS-4124) Should we return here?
        }
        
        // We need to update the group call state, if we're alone in the call, or if we expect to be the lowest ID
        // after all participant handshakes went through.
        // This doesn't actually happen unless we start the call ourselves.
        if participantIDs.isEmpty, participantIDs.filter({ $0 < groupCallContext.myParticipantID().id }).isEmpty {
            try groupCallContext.startStateUpdateTaskIfNecessary()
        }
        
        // Start timeout as there might be no existing participants in this call. It will be canceled if there is a
        // successful handshake with any participant
        emptyCallTimeout.start()
        
        // Add all initial participants
        try await groupCallContext.updateParticipants(
            add: participantIDs.map { ParticipantID(id: $0) },
            remove: [],
            existingParticipants: true
        )
        
        // Start the handshakes if there are any participants
        try sendInitialHandshakeHellos(to: groupCallContext.pendingParticipants)
        
        // Main process loop: All events are handled here
        processLoop: for await newValue in merge(
            groupCallContext.messageStream.map { StateStreamValue.buffer($0) },
            groupCallActor.uiActionQueue.map { StateStreamValue.uiAction($0) }
        ) {
            DDLogNotice("[GroupCall] [DEBUG] Start Process \(newValue.self)")
            
            guard !Task.isCancelled else {
                DDLogNotice("[GroupCall] Our task was cancelled. Leave call.")
                break processLoop
            }
        
            do {
                switch newValue {
                case let .buffer(buffer):
                    try await process(buffer)
                
                case let .uiAction(uiAction):
                    let result = try await process(uiAction)
                    
                    switch result {
                    case .success:
                        DDLogNotice("[GroupCall] Action \(uiAction) processed")
                    
                    case .ended:
                        break processLoop
                    }
                }
            }
            catch {
                // TODO: (IOS-4124) We might be able to recover from some errors here
                DDLogError("[GroupCall] An error occurred \(error)")
                throw error
            }
        }
        
        /// **Leave Call** 4. Stop sending video as soon as the leave starts...
        await groupCallContext.stopAudioCapture()
        await groupCallContext.stopVideoCapture()
        
        return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
    }
}

// - MARK: Configuration Functions

extension Connected {
    private func sendInitialHandshakeHellos(to pendingRemoteParticipants: Set<PendingRemoteParticipant>) throws {
        DDLogNotice("[GroupCall] Number of initially pending remote participants \(pendingRemoteParticipants.count)")
        
        for pendingRemoteParticipant in pendingRemoteParticipants {
            let handshakeMessage = try pendingRemoteParticipant.handshakeHelloMessage(
                for: groupCallActor.localContactModel.identity,
                localNickname: groupCallActor.localContactModel.nickname
            )
            
            let outer = groupCallContext.outerEnvelope(for: handshakeMessage, to: pendingRemoteParticipant)
            
            do {
                try groupCallContext.relay(outer)
            }
            catch {
                guard !(error is GroupCallError) else {
                    throw error
                }
                
                DDLogError(
                    "[GroupCall] An error occurred when sending initial handshake hello to participant \(pendingRemoteParticipant.participantID): \(error)"
                )
            }
            
            DDLogNotice("[GroupCall] Sent participant handshake hello to \(pendingRemoteParticipant.participantID)")
        }
    }
}

// - MARK: Update Functions / Event Processing

extension Connected {
    private func process(_ uiAction: GroupCallUIAction) async throws -> ProcessResult {
        switch uiAction {
        case .none:
            break
        
        // MARK: Local Participant
        
        case .leave:
            /// **Leave Call** 3. We start the ending of the call
            return .ended
            
        // Local video
        case .muteVideo:
            await groupCallContext.stopVideoCapture()
            groupCallActor.uiContinuation.yield(.videoMuteChange(.muted))
            
            for participant in groupCallContext.joinedParticipants {
                let videoMuteMessage = try participant.videoMuteMessage()
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoMuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }

        case let .unmuteVideo(position):
            try await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoMuteChange(.unmuted))
            
            for participant in groupCallContext.joinedParticipants {
                let videoUnmuteMessage = try participant.videoUnmuteMessage()
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
        
        case let .switchCamera(position):
            try await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoCameraChange(position))
            
        // Local audio
        case .muteAudio:
            await groupCallContext.stopAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.muted))
            
            for participant in groupCallContext.joinedParticipants {
                let audioUnmuteMessage = try participant.audioMuteMessage()
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: audioUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }

        case .unmuteAudio:
            await groupCallContext.startAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.unmuted))
            
            for participant in groupCallContext.joinedParticipants {
                let audioUnmuteMessage = try participant.audioUnmuteMessage()
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: audioUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
        
        // MARK: Remote Participant

        case let .subscribeVideo(participantID):
            DDLogNotice("Subscribe Video for \(participantID)")

            guard let remoteParticipant = groupCallContext.participant(with: participantID) else {
                DDLogError("Could not find participant with id \(participantID)")
                return .success
            }
            let answer = remoteParticipant.subscribeVideo()
            try groupCallContext.send(answer)
        
        case let .unsubscribeVideo(participantID):
            DDLogNotice("Unsubscribe Video for \(participantID)")

            guard let remoteParticipant = groupCallContext.joinedParticipants
                .first(where: { $0.participantID == participantID }) else {
                DDLogError("Could not find participant with id \(participantID)")
                return .success
            }
            
            try groupCallContext.send(remoteParticipant.unsubscribeVideo())
        }
        
        // By default we assume everything was successful unless we returned `.ended` earlier or we threw an error
        return .success
    }
    
    private func process(_ buffer: PeerConnectionMessage) async throws {
        guard let sfuToParticipant = try? Groupcall_SfuToParticipant.Envelope(serializedData: buffer.data) else {
            DDLogWarn(
                "[GroupCall] Could not create `Groupcall_SfuToParticipant.Envelope` from `PeerConnectionMessage`, thus ignoring it."
            )
            return
        }
        
        switch sfuToParticipant.content {
        case .none:
            DDLogWarn(
                "[GroupCall] Creating content for `Groupcall_SfuToParticipant.Envelope` failed, ignoring `PeerConnectionMessage`."
            )
            
        case let .some(content):
            switch content {
            case let .relay(relay):
                DDLogNotice("[GroupCall] Message received from \(relay.sender)")
                
                switch try await groupCallContext.handle(relay) {
                case let .participantToParticipant(participant, data):
                    try serializeAndSend(data, to: participant)
                    
                case let .participantToSFU(envelope, participant, participantStateChange):
                    groupCallActor.uiContinuation
                        .yield(.participantStateChange(participant.participantID, participantStateChange))
                    try groupCallContext.send(envelope)
                    
                case let .muteStateChanged(participant, participantStateChange):
                    DDLogNotice(
                        "[GroupCall] Participant \(participant.participantID) State changed to \(participantStateChange)"
                    )
                    groupCallActor.uiContinuation
                        .yield(.participantStateChange(participant.participantID, participantStateChange))
                    
                case let .handshakeCompleted(participant):
                    try await handshakeCompleted(with: participant)
                    try groupCallContext.startStateUpdateTaskIfNecessary()
                    
                    if !groupCallContext.joinedParticipants.isEmpty {
                        emptyCallTimeout.cancel()
                    }
                    
                case let .sendAuth(participant, data):
                    try serializeAndSend(data, to: participant)
                    
                case let .epHelloAndAuth(participant, (hello, auth)):
                    try serializeAndSend(hello, to: participant)
                    try serializeAndSend(auth, to: participant)
                    
                case let .rekeyReceived(participant, mediaKeys):
                    try groupCallContext.rekeyReceived(from: participant, with: mediaKeys)
                
                case let .dropPendingParticipant(participantID):
                    try await groupCallContext.updateParticipants(
                        add: [],
                        remove: [ParticipantID(id: participantID.id)],
                        existingParticipants: false
                    )
                    
                case .none:
                    // No action necessary
                    DDLogNotice("[GroupCall] No action necessary")
                }
                
            case .hello:
                DDLogWarn("[GroupCall] We should not receive a hello in the connected state")
                
            case let .participantJoined(message):
                /// **Protocol Step: Join/Leave of Other Participants (Join 1. - 3.)**
                try groupCallContext.ratchetAndApplyNewKeys()
                
                /// **Protocol Step: Join/Leave of Other Participants (Join 4.)**
                /// Join: 4. is completed in this call as long as `existingParticipants` is `false`
                try await groupCallContext.updateParticipants(
                    add: [ParticipantID(id: message.participantID)],
                    remove: [],
                    existingParticipants: false
                )
                
                try groupCallContext.startStateUpdateTaskIfNecessary()
                
            case let .participantLeft(message):
                guard let participant = groupCallContext.participant(with: ParticipantID(id: message.participantID))
                else {
                    DDLogWarn("[GroupCall] Participant left message for an unknown participant")
                    return
                }
                
                try await groupCallContext.updateParticipants(
                    add: [],
                    remove: [ParticipantID(id: message.participantID)],
                    existingParticipants: false
                )
                await groupCallActor.remove(participant)
                try groupCallContext.removeDecryptor(for: participant)
                
                try groupCallContext.startStateUpdateTaskIfNecessary()
                
                // Protocol steps for replacing the pcmk
                try await groupCallContext.replaceAndApplyNewMediaKeys()
                
                try groupCallContext.startStateUpdateTaskIfNecessary()
                
                if !groupCallContext.hasAnyParticipants {
                    emptyCallTimeout.start()
                }

            case .timestampResponse: break
            }
        }
    }
}

// MARK: Helper functions

extension Connected {

    private func handshakeCompleted(with participant: JoinedRemoteParticipant) async throws {
        
        /// **Protocol Step: Post-Handshake**
        /// 1. Subscribe to the other participant's microphone feed (i.e. send a `ParticipantMicrophone` message to the
        /// SFU).
        try groupCallContext.send(participant.subscribeAudio())
        
        // Add to view
        await groupCallActor.add(participant)

        if await groupCallActor.viewModel.ownAudioMuteState == .unmuted {
            try await sendAudioUnmuteMessages(to: participant)
        }

        if await groupCallActor.viewModel.ownVideoMuteState == .unmuted {
            try await sendVideoUnmuteMessages(to: participant)
        }
    }
    
    private func serializeAndSend(_ data: Data, to participant: RemoteParticipant) throws {
        let participantToParticipantEnvelope = groupCallContext.outerEnvelope(for: data, to: participant)
        
        var outer = Groupcall_ParticipantToSfu.Envelope()
        outer.relay = participantToParticipantEnvelope
        outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
        
        let serialized = try outer.ownSerializedData()
        groupCallContext.send(serialized)
    }
    
    private func sendAudioUnmuteMessages(to participant: JoinedRemoteParticipant) async throws {
        let audioUnmuteMessage = try participant.audioUnmuteMessage()
        try serializeAndSend(audioUnmuteMessage, to: participant)
    }
    
    private func sendVideoUnmuteMessages(to participant: JoinedRemoteParticipant) async throws {
        let videoUnmuteMessage = try participant.videoUnmuteMessage()
        try serializeAndSend(videoUnmuteMessage, to: participant)
        
        if groupCallContext.localVideoTrack() == nil {
            try await groupCallContext.startVideoCapture(position: .front)
        }
    }
}

// MARK: - State Access

extension Connected {
    func getRemoteContext(for participantID: ParticipantID) async -> RemoteContext? {
        guard let remoteContext = await groupCallContext.participant(with: participantID)?.getRemoteContext() else {
            DDLogWarn("[GroupCall] Remote context for participant \(participantID) was nil")
            return nil
        }
        
        return remoteContext
    }
    
    func localVideoTrack() async -> RTCVideoTrack? {
        groupCallContext.localVideoTrack()
    }
}
