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
/// Group Call Connection State
/// Starts the WebRTC connection to the SFU and hands it over to the `Connected` state once established
struct Connecting: GroupCallState {
    // MARK: - Internal Properties

    let groupCallActor: GroupCallActor
    let joinResponse: Groupcall_SfuHttpResponse.Join
    let certificate: RTCCertificate
    
    // MARK: - Private Properties

    private let connectionContext: ConnectionContext<PeerConnectionContext, RTCRtpTransceiver>
    private let groupCallContext: GroupCallContext<PeerConnectionContext, RTCRtpTransceiver>
    
    // MARK: - Lifecycle

    init(
        groupCallActor: GroupCallActor,
        joinResponse: Groupcall_SfuHttpResponse.Join,
        certificate: RTCCertificate
    ) throws {
        
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Init Connecting \(groupCallActor.callID.bytes.hexEncodedString())")
        
        self.groupCallActor = groupCallActor
        self.joinResponse = joinResponse
        self.certificate = certificate
        
        let participantID = ParticipantID(id: joinResponse.participantID)
        let iceParameters = IceParameters(
            usernameFragment: joinResponse.iceUsernameFragment,
            password: joinResponse.icePassword
        )
        let dtlsParameters = DtlsParameters(fingerprint: Array(joinResponse.dtlsFingerprint))
        
        let sessionParameters = SessionParameters(
            participantID: participantID,
            iceParameters: iceParameters,
            dtlsParameters: dtlsParameters
        )
        
        let groupCallDescription = groupCallActor.groupCallBaseStateCopy
        
        self.connectionContext = try ConnectionContext(
            certificate: certificate,
            cryptoContext: groupCallDescription,
            sessionParameters: sessionParameters,
            dependencies: groupCallActor.dependencies
        )
        
        let localParticipantID = ParticipantID(id: joinResponse.participantID)
                
        let localParticipant = LocalParticipant(
            participantID: localParticipantID,
            localContext: LocalContext(),
            localContactModel: self.groupCallActor.localContactModel,
            dependencies: self.groupCallActor.dependencies
        )
        
        self.groupCallContext = try GroupCallContext(
            connectionContext: connectionContext,
            localParticipant: localParticipant,
            dependencies: groupCallActor.dependencies,
            groupCallDescription: groupCallDescription
        )
        
        Task {
            await groupCallActor.add(localParticipant)
        }
    }
    
    func next() async throws -> GroupCallState? {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] State is Connecting \(groupCallActor.callID.bytes.hexEncodedString())")
        
        /// **Protocol Step: Group Call Join Steps** 5. Establish a WebRTC connection to the SFU with the information
        /// provided in the Join response. Wait until the SFU sent the initial SfuToParticipant.Hello message via the
        /// associated data channel. Let hello be that message.
        connectionContext.createLocalMediaSenders()
        
        try await connectionContext.createAndApplyInitialOfferAndAnswer()
        
        guard !Task.isCancelled else {
            return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
        }
        
        try await connectionContext.addIceCandidates(addresses: joinResponse.addresses)
        
        guard !Task.isCancelled else {
            return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
        }
        
        var messageData: Data?
        
        for await message in connectionContext.messageStream {
            guard !Task.isCancelled else {
                return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
            }
            messageData = message.data
            break
        }
        
        guard let messageData else {
            throw GroupCallError.firstMessageNotReceived
        }
        
        guard let envelope = try? Groupcall_SfuToParticipant.Envelope(serializedData: messageData).hello else {
            throw GroupCallError.serializationFailure
        }
        
        // swiftformat:disable:next acronyms
        let participantIDs = envelope.participantIds
        
        /// **Protocol Step: Group Call Join Steps** 6. If the hello.participants contains less than 4 items, set the
        /// initial capture state of the microphone to on. We only do this if the microphone access was granted.
        
        // swiftformat:disable:next acronyms
        if envelope.participantIds.count < 4, AVAudioSession.sharedInstance().recordPermission == .granted {
            await groupCallActor.toggleOwnAudio(false)
        }
        
        guard !Task.isCancelled else {
            return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
        }
        
        /// **Protocol Step: Group Call Join Steps** 7. If call is marked as new:
        if await groupCallActor.isNew {
            if try await !groupCallActor.sendStartMessageWithDelay() {
                return Ending(groupCallActor: groupCallActor, groupCallContext: groupCallContext)
            }
        }
        
        return Connected(
            groupCallActor: groupCallActor,
            groupCallContext: groupCallContext,
            participantIDs: participantIDs
        )
    }
    
    func localVideoTrack() -> RTCVideoTrack? {
        groupCallContext.localVideoTrack()
    }
}
