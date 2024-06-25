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
    private var groupCallContext: GroupCallContextProtocol
    private let participantIDs: [UInt32]
    
    // MARK: - Lifecycle
    
    init(
        groupCallActor: GroupCallActor,
        groupCallContext: GroupCallContextProtocol,
        participantIDs: [UInt32]
    ) {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Init Connected \(groupCallActor.callID.bytes.hexEncodedString())")
        self.groupCallActor = groupCallActor
        self.groupCallContext = groupCallContext
        self.participantIDs = participantIDs
    }
    
    func next() async throws -> GroupCallState? {
        
        /// **Protocol Step: Group Call Join Steps**
        /// 7.3 Add the call to the list of group calls that are currently considered running.
        await groupCallActor.addSelfToCurrentlyRunningCalls()
        
        /// 7.4 Asynchronously run the Group Call Refresh Steps
        await groupCallActor.startRefreshSteps()
        
        /// **Protocol Step: Group Call Join Steps** 8. The group call is now considered established and should
        /// asynchronously invoke the SFU to Participant and Participant to Participant flows. Note: This is done via
        /// the state change in the `GroupCallActor`.
        DDLogNotice("[GroupCall] State is Connected \(groupCallActor.callID.bytes.hexEncodedString())")
        if Task.isCancelled {
            // Teardown
            await groupCallContext.leave()
        }
        
        // We need to update the group call state, if we're alone in the call, or if we expect to be the lowest ID
        // after all participant handshakes went through.
        // This doesn't actually happen unless we start the call ourselves.
        if participantIDs.isEmpty, participantIDs.filter({ $0 < groupCallContext.myParticipantID().id }).isEmpty {
            try groupCallContext.startStateUpdateTaskIfNecessary()
        }
        
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
                        DDLogNotice("[GroupCall] Action \(uiAction) Processed")
                    
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
            
            DDLogNotice("[GroupCall] [DEBUG] End Process \(newValue.self)")
        }
        
        return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
    }
    
    func connectedConfirmed() async throws {
        let ownAudioMuteState = await groupCallActor.viewModel.ownAudioMuteState
        let ownVideoMuteState = await groupCallActor.viewModel.ownVideoMuteState
        
        try await groupCallContext.mapLocalTransceivers(
            ownAudioMuteState: ownAudioMuteState,
            ownVideoMuteState: ownVideoMuteState
        )
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
                    "[GroupCall] An error occurred when sending initial handshake hello to participant with id \(pendingRemoteParticipant.participantID.id) \(error)"
                )
            }
            
            DDLogNotice("[GroupCall] Sent participant handshake hello to \(pendingRemoteParticipant.participantID.id)")
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

        case .connectedConfirmed:
            try await connectedConfirmed()
            
            try await groupCallContext.updateParticipants(
                add: participantIDs.map { ParticipantID(id: $0) },
                remove: [],
                existingParticipants: true
            )
            
            // TODO: (IOS-4685) This is currently called after some other Group Call Join Steps to work correctly
            /// **Protocol Step: Group Call Join Steps** 6. If the hello.participants contains less than 4 items, set
            /// the initial capture state of the microphone to on. We only do this if the microphone access was granted.
            
            if participantIDs.count < 4, AVAudioSession.sharedInstance().recordPermission == .granted {
                await groupCallActor.toggleOwnAudio(false)
            }
            
            try sendInitialHandshakeHellos(to: groupCallContext.pendingParticipants)
            
            return .success
        
        case .leave:
            return .ended
            
        // Local video
        case .muteVideo:
            for participant in groupCallContext.joinedParticipants {
                
                let videoMuteMessage = try participant.videoMuteMessage()
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoMuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
            
            await groupCallContext.stopVideoCapture()
            groupCallActor.uiContinuation.yield(.videoMuteChange(.muted))

        case let .unmuteVideo(position):
            for participant in groupCallContext.joinedParticipants {
                let videoUnmuteMessage = try participant.videoUnmuteMessage()
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
            try await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoMuteChange(.unmuted))
        
        case let .switchCamera(position):
            try await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoCameraChange(position))
            
        // Local audio
        case .muteAudio:
            for participant in groupCallContext.joinedParticipants {
                let audioUnmuteMessage = try participant.audioMuteMessage()
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: audioUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
            await groupCallContext.stopAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.muted))

        case .unmuteAudio:
            for participant in groupCallContext.joinedParticipants {
                let audioUnmuteMessage = try participant.audioUnmuteMessage()
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: audioUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                let serialized = try outer.ownSerializedData()
                groupCallContext.send(serialized)
            }
            await groupCallContext.startAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.unmuted))
        
        // MARK: Remote Participant

        case let .subscribeVideo(participantID):
            DDLogNotice("Subscribe Video for \(participantID)")

            guard let remoteParticipant = groupCallContext.participant(with: participantID) else {
                DDLogError("Could not find participant with id \(participantID)")
                return .success
            }
            let answer = try remoteParticipant.subscribeVideo(subscribe: true)
            try groupCallContext.send(answer)
        
        case let .unsubscribeVideo(participantID):
            DDLogNotice("Unsubscribe Video for \(participantID)")

            guard let remoteParticipant = groupCallContext.joinedParticipants
                .first(where: { $0.participantID.id == participantID.id }) else {
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
                guard groupCallContext.verifyReceiver(for: relay) else {
                    // TODO: (IOS-4124) What do we need to do here
                    throw GroupCallError.badMessage
                }
                
                DDLogNotice("[GroupCall] Message received from \(relay.sender)")
                
                switch try await groupCallContext.handle(relay) {
                case let .participantToParticipant(participant, data):
                    try serializeAndSend(data, to: participant)
                    
                case let .participantToSFU(envelope, participant, participantStateChange):
                    try groupCallContext.send(envelope)
                    groupCallActor.uiContinuation
                        .yield(.participantStateChange(participant.participantID, participantStateChange))
                    
                case let .muteStateChanged(participant, participantStateChange):
                    DDLogNotice(
                        "[GroupCall] Participant \(participant.participantID.id) State changed to \(participantStateChange)"
                    )
                    groupCallActor.uiContinuation
                        .yield(.participantStateChange(participant.participantID, participantStateChange))
                    
                case let .handshakeCompleted(participant):
                    try await handshakeCompleted(with: participant)
                    try groupCallContext.startStateUpdateTaskIfNecessary()
                    
                case let .sendAuth(participant, data):
                    try serializeAndSend(data, to: participant)
                    
                case let .epHelloAndAuth(participant, (hello, auth)):
                    try serializeAndSend(hello, to: participant)
                    try serializeAndSend(auth, to: participant)
                    
                case let .rekeyReceived(participant, mediaKeys):
                    try groupCallContext.rekeyReceived(from: participant, with: mediaKeys)
                    
                case .none:
                    // No action necessary
                    DDLogNotice("No action necessary")
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
            }
        }
    }
}

// MARK: Helper functions

extension Connected {

    private func handshakeCompleted(with participant: JoinedRemoteParticipant) async throws {
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
            DDLogWarn("[GroupCall] Remote context for participant \(participantID.id) was nil")
            return nil
        }
        
        return remoteContext
    }
    
    func localVideoTrack() async -> RTCVideoTrack? {
        groupCallContext.localVideoTrack()
    }
}
