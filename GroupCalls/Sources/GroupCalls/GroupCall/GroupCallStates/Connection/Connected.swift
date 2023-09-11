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
            groupCallActor.stateQueue.map { StateStreamValue.uiAction($0) }
        ) {
            DDLogNotice("[GroupCall] [DEBUG] Start Process \(newValue.self)")
            
            guard !Task.isCancelled else {
                DDLogNotice("[GroupCall] Our task was cancelled. Exit call.")
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
                // TODO: IOS-3743 Group Calls Graceful Error Handling
                // We might be able to recover from some errors here
                DDLogError("[GroupCall] An error occurred \(error)")
                throw error
            }
            
            DDLogNotice("[GroupCall] [DEBUG] End Process \(newValue.self)")
        }
        
        DDLogNotice("[GroupCall] Group Call has ended")
        
        await groupCallContext.leave()
        return Ended(groupCallActor: groupCallActor)
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
    private func sendInitialHandshakeHellos(to remoteParticipants: [RemoteParticipant]) throws {
        DDLogNotice("[GroupCall] Number of initially pending participants \(remoteParticipants.count)")
        
        for pendingParticipant in remoteParticipants {
            let handshakeMessage = pendingParticipant.handshakeHelloMessage(for: groupCallActor.localIdentity)
            
            let outer = groupCallContext.outerEnvelope(for: handshakeMessage, to: pendingParticipant)
            
            do {
                try groupCallContext.relay(outer)
            }
            catch {
                guard !(error is GroupCallError) else {
                    throw error
                }
                
                DDLogError(
                    "[GroupCall] An error occurred when sending initial handshake hello to participant with id \(pendingParticipant.id) \(error)"
                )
            }
            
            DDLogNotice("[GroupCall] Sent participant handshake hello to \(pendingParticipant.id)")
        }
    }
}

// - MARK: Update Functions / Event Processing

extension Connected {
    private func process(_ uiAction: GroupCallUIAction) async throws -> ProcessResult {
        switch uiAction {
        case .none:
            break
       
        case let .unsubscribeVideo(participantID):
            DDLogNotice("Unsubscribe Video for \(participantID)")
            // TODO: This should only be done over the not pending participants but they are currently not properly separated
            guard let remoteParticipant = groupCallContext.participants
                .first(where: { $0.id == participantID.id }) else {
                DDLogError("Could not find participant with id \(participantID)")
                return .success
            }
            // TODO: (IOS-3813) try? correct?
            try? groupCallContext.send(remoteParticipant.unsubscribeVideo())
            
        case .muteVideo:
            // TODO: Do we announce video to new participants nevertheless?
            for participant in groupCallContext.participants {
                guard let videoMuteMessage = try? participant.videoMuteMessage() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoMuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                
                guard let serialized = try? outer.serializedData() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                groupCallContext.send(serialized)
            }
            
            await groupCallContext.stopVideoCapture()
            groupCallActor.uiContinuation.yield(.videoMuteChange(.muted))

        case let .unmuteVideo(position):
            for participant in groupCallContext.participants {
                guard let videoUnmuteMessage = try? participant.videoUnmuteMessage() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                
                let videoUnmuteEnvelope = groupCallContext.outerEnvelope(for: videoUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = videoUnmuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                guard let serialized = try? outer.serializedData() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                groupCallContext.send(serialized)
            }
            await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoMuteChange(.unmuted))
            
        case let .switchCamera(position):
            await groupCallContext.startVideoCapture(position: position)
            groupCallActor.uiContinuation.yield(.videoCameraChange(position))

        case .muteAudio:
            for participant in groupCallContext.participants {
                guard let videoUnmuteMessage = try? participant.audioMuteMessage() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: videoUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                guard let serialized = try? outer.serializedData() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                groupCallContext.send(serialized)
            }
            await groupCallContext.stopAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.muted))

        case .unmuteAudio:
            for participant in groupCallContext.participants {
                guard let videoUnmuteMessage = try? participant.audioUnmuteMessage() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                
                let audioMuteEnvelope = groupCallContext.outerEnvelope(for: videoUnmuteMessage, to: participant)
                
                var outer = Groupcall_ParticipantToSfu.Envelope()
                outer.relay = audioMuteEnvelope
                outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
                guard let serialized = try? outer.serializedData() else {
                    // TODO: IOS-3813 Group Calls Graceful Error Handling
                    fatalError()
                }
                groupCallContext.send(serialized)
            }
            await groupCallContext.startAudioCapture()
            groupCallActor.uiContinuation.yield(.audioMuteChange(.unmuted))

        case let .subscribeVideo(participantID):
            DDLogNotice("Subscribe Video for \(participantID)")
            // TODO: This should only be done over the not pending participants but they are currently not properly separated
            guard let remoteParticipant = groupCallContext.participant(with: participantID) else {
                DDLogError("Could not find participant with id \(participantID)")
                return .success
            }
            let answer = try remoteParticipant.subscribeVideo(subscribe: true)
            try groupCallContext.send(answer)
            
        case .unsubscribeAudio:
            fatalError()
            
        case .subscribeAudio:
            fatalError()
            
        case .leave:
            await groupCallContext.leave()
            return .ended
            
        case .connectedConfirmed:
            try await connectedConfirmed()
            
            try await groupCallContext.updatePendingParticipants(
                add: participantIDs.map { ParticipantID(id: $0) },
                remove: [],
                existingParticipants: true
            )
            
            try sendInitialHandshakeHellos(to: groupCallContext.pendingParticipants)
            
            return .success
        }
        
        // By default we assume everything was successful unless we returned `.ended` earlier or we threw an error
        return .success
    }
    
    private func process(_ buffer: PeerConnectionMessage) async throws {
        guard let sfuToParticipant = try? Groupcall_SfuToParticipant.Envelope(serializedData: buffer.data) else {
            fatalError()
        }
        
        // TODO: (IOS-3813) Error handling below
        switch sfuToParticipant.content {
        case .none:
            fatalError()
            
        case let .some(content):
            switch content {
            case let .relay(relay):
                assert(relay.unknownFields.data.isEmpty)
                
                guard groupCallContext.verifyReceiver(for: relay) else {
                    // TODO: What do we need to do here
                    throw GroupCallError.badMessage
                }
                
                DDLogNotice("[GroupCall] Message received from \(relay.sender)")
                
                switch try await groupCallContext.handle(relay) {
                case let .participantToParticipant(participant, data):
                    try serializeAndSend(data, to: participant)
                    
                case let .participantToSFU(envelope, participant, participantStateChange):
                    if envelope.requestParticipantCamera.isInitialized { }
                    try groupCallContext.send(envelope)
                    await groupCallActor.uiContinuation
                        .yield(.participantStateChange(participant.getID(), participantStateChange))
                    
                case let .muteStateChanged(participant, participantStateChange):
                    DDLogNotice(
                        "[GroupCall] [Connected] Participant \(participant.id) State changed to \(participantStateChange)"
                    )
                    groupCallActor.uiContinuation
                        .yield(.participantStateChange(ParticipantID(id: participant.id), participantStateChange))
                    
                case let .handshakeCompleted(participant):
                    await handshakeCompleted(with: participant)
                    
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
                DDLogError("[GroupCall] We should not receive a hello in the connected state")
                
            case let .participantJoined(message):
                assert(message.unknownFields.data.isEmpty)
                
                try groupCallContext.ratchetAndApplyNewKeys()
                
                try await groupCallContext.updatePendingParticipants(
                    add: [ParticipantID(id: message.participantID)],
                    remove: [],
                    existingParticipants: false
                )
                
                try groupCallContext.startStateUpdateTaskIfNecessary()
                
            case let .participantLeft(message):
                assert(message.unknownFields.data.isEmpty)
                
                guard let participant = groupCallContext.participant(with: ParticipantID(id: message.participantID))
                else {
                    return
                }
                
                try await groupCallContext.updatePendingParticipants(
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
    // TODO: (IOS-3813) Try! are ugly
    private func handshakeCompleted(with participant: RemoteParticipant) async {
        // TODO: Add to non-pending participants
        // Add to view
        await groupCallActor.add(participant)

        if await groupCallActor.viewModel.ownAudioMuteState == .unmuted {
            try! await sendAudioUnmuteMessages(to: participant)
        }
        
        if await groupCallActor.viewModel.ownVideoMuteState == .unmuted {
            try! await sendVideoUnmuteMessages(to: participant)
        }
        
        if participant.needsPostHandshakeRekey {
            try! await groupCallContext.sendPostHandshakeMediaKeys(to: participant)
            participant.needsPostHandshakeRekey = false
        }
    }
    
    private func serializeAndSend(_ data: Data, to participant: RemoteParticipant) throws {
        let participantToParticipantEnvelope = groupCallContext.outerEnvelope(for: data, to: participant)
        
        var outer = Groupcall_ParticipantToSfu.Envelope()
        outer.relay = participantToParticipantEnvelope
        outer.padding = groupCallActor.dependencies.groupCallCrypto.padding()
        
        // TODO: (IOS-3813) fatal error and try? is ugly
        guard let serialized = try? outer.serializedData() else {
            fatalError()
        }
        
        groupCallContext.send(serialized)
    }
    
    private func sendAudioUnmuteMessages(to participant: RemoteParticipant) async throws {
        // Send Microphone Unmute
        // TODO: (IOS-3813) fatal error and try? is ugly
        guard let audioUnmuteMessage = try? participant.audioUnmuteMessage() else {
            fatalError()
        }
        
        try serializeAndSend(audioUnmuteMessage, to: participant)
    }
    
    private func sendVideoUnmuteMessages(to participant: RemoteParticipant) async throws {
        // Send Video Unmute
        // TODO: We could have already disabled video here. This needs to be handled somehow
        if groupCallContext.hasVideoCapturer {
            DDLogNotice("[GroupCall] Correct Capturer, send unmute")
            // TODO: (IOS-3813) fatal error and try? is ugly
            guard let videoUnmuteMessage = try? participant.videoUnmuteMessage() else {
                fatalError()
            }
            
            try serializeAndSend(videoUnmuteMessage, to: participant)
            
            if groupCallContext.localVideoTrack() == nil {
                await groupCallContext.startVideoCapture(position: .front)
            }
        }
        else {
            DDLogWarn("[GroupCall] We do not have a video capturer")
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
