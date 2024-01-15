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

import Foundation
import ThreemaEssentials
import XCTest

@testable import GroupCalls
@testable import WebRTC

final class ConnectionCtxTests: XCTestCase {
    
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    
    @GlobalGroupCallActor func testBasicInit() async throws {
        let certificate = RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
        let sessionParameters = SessionParameters(
            participantID: ParticipantID(id: 0),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: [])
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()
        
        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelCtx()
        
        let peerConnectionCtx = PeerConnectionContext(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        _ = ConnectionContext<PeerConnectionContext, MockRTCRtpTransceiver>(
            certificate: certificate,
            cryptoContext: mockCryptoAdapter,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: peerConnectionCtx
        )
    }
    
    @GlobalGroupCallActor func testTeardownClosesConnections() async throws {
        let certificate = RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
        let sessionParameters = SessionParameters(
            participantID: ParticipantID(id: 0),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: [])
        )
        
        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelCtx()
        
        let peerConnectionCtx = PeerConnectionContext(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        let connectionCtx = ConnectionContext<PeerConnectionContext, MockRTCRtpTransceiver>(
            certificate: certificate,
            cryptoContext: mockCryptoAdapter,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: peerConnectionCtx
        )
        
        await connectionCtx.teardown()
        
        XCTAssertTrue(mockDataChannelCtx.isClosed)
        XCTAssertTrue(mockPeerConnection.isClosed)
    }
    
    @GlobalGroupCallActor func testMapLocalTransceivers() async throws {
        let certificate = RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
        let sessionParameters = SessionParameters(
            participantID: ParticipantID(id: 0),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: [])
        )
        
        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelCtx()
        
        let mockPeerConnectionCtx = MockPeerConnectionCtx(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .recvOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .recvOnly)
        
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver1)
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver2)
        
        let connectionCtx = ConnectionContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
            certificate: certificate,
            cryptoContext: mockCryptoAdapter,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: mockPeerConnectionCtx
        )
        
        try! await connectionCtx.mapLocalTransceivers(ownAudioMuteState: .muted, ownVideoMuteState: .muted)
        
        for loggedActivations in mockPeerConnectionCtx.transceivers.map({ $0 as! MockRTCRtpTransceiver })
            .map(\.loggedActivation) {
            XCTAssertEqual(loggedActivations, 1)
        }
    }
    
    @GlobalGroupCallActor func testMapAndRemapLocalTransceivers() async throws {
        let certificate = RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
        let sessionParameters = SessionParameters(
            participantID: ParticipantID(id: 0),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: [])
        )
        
        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelCtx()
        
        //        let peerConnectionCtx = PeerConnectionCtx(peerConnection: mockPeerConnection, dataChannelCtx:
        //        mockDataChannelCtx)
        
        let mockPeerConnectionCtx = MockPeerConnectionCtx(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        let localParticipant = LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContext: LocalContext(),
            localContactModel: localContactModel,
            dependencies: dependencies
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        let participantStateActor = ParticipantStateActor(localParticipant: localParticipant)
        
        mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .recvOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .recvOnly)
        //        let newMockTransceiver3 = MockRTCRtpTransceiver(mid: "$", mediaType: .data, direction: .recvOnly)
        
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver1)
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver2)
        //        mockPeerConnectionCtx.transceivers.append(newMockTransceiver3)
        
        let connectionCtx = ConnectionContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
            certificate: certificate,
            cryptoContext: mockCryptoAdapter,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: mockPeerConnectionCtx
        )
        
        try! await connectionCtx.mapLocalTransceivers(ownAudioMuteState: .muted, ownVideoMuteState: .muted)
        
        for loggedActivations in mockPeerConnectionCtx.transceivers.map({ $0 as! MockRTCRtpTransceiver })
            .map(\.loggedActivation) {
            XCTAssertEqual(loggedActivations, 1)
        }
        
        try! await connectionCtx.updateCall(call: participantStateActor, remove: [], add: [])
        
        for loggedActivations in mockPeerConnectionCtx.transceivers.map({ $0 as! MockRTCRtpTransceiver })
            .map(\.loggedActivation) {
            XCTAssertEqual(loggedActivations, 1)
        }
        
        XCTAssertTrue(participantStateActor.getAllParticipants().isEmpty)
    }
    
    @GlobalGroupCallActor func testMapAndRemapAndAddLocalTransceivers() async throws {
        let certificate = RTCCertificate(privateKey: "helloWorld", certificate: "helloWorld", fingerprint: "helloWorld")
        let sessionParameters = SessionParameters(
            participantID: ParticipantID(id: 0),
            iceParameters: IceParameters(usernameFragment: "", password: ""),
            dtlsParameters: DtlsParameters(fingerprint: [])
        )
        
        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelCtx()
        
        //        let peerConnectionCtx = PeerConnectionCtx(peerConnection: mockPeerConnection, dataChannelCtx:
        //        mockDataChannelCtx)
        
        let mockPeerConnectionCtx = MockPeerConnectionCtx(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        let localParticipant = LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContext: LocalContext(),
            localContactModel: localContactModel,
            dependencies: dependencies
        )
        
        let gck = Data(repeating: 0x01, count: 32)
        let groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: ThreemaIdentity("ECHOECHO"))

        let groupCallDescription = try GroupCallBaseState(
            group: GroupCallsThreemaGroupModel(
                groupIdentity: groupIdentity,
                groupName: "ECHOECHO"
            ),
            startedAt: Date(),
            maxParticipants: 100,
            dependencies: dependencies,
            groupCallStartData: GroupCallStartData(protocolVersion: 0, gck: gck, sfuBaseURL: "")
        )
        
        let participantStateActor = ParticipantStateActor(localParticipant: localParticipant)
        
        mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .sendOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .sendOnly)
        //        let newMockTransceiver3 = MockRTCRtpTransceiver(mid: "$", mediaType: .data, direction: .recvOnly)
        
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver1)
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver2)
        //        mockPeerConnectionCtx.transceivers.append(newMockTransceiver3)
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        let connectionCtx = ConnectionContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
            certificate: certificate,
            cryptoContext: mockCryptoAdapter,
            sessionParameters: sessionParameters,
            dependencies: dependencies,
            peerConnectionContext: mockPeerConnectionCtx
        )
        
        try! await connectionCtx.mapLocalTransceivers(ownAudioMuteState: .muted, ownVideoMuteState: .muted)
        
        for loggedActivations in mockPeerConnectionCtx.transceivers.map({ $0 as! MockRTCRtpTransceiver })
            .map(\.loggedActivation) {
            XCTAssertEqual(loggedActivations, 1)
        }
        
        let newRemoteParticipant = ParticipantID(id: 1)
        
        let newMockTransceiver4 = MockRTCRtpTransceiver(mid: "-", mediaType: .audio, direction: .recvOnly)
        let newMockTransceiver5 = MockRTCRtpTransceiver(mid: ".", mediaType: .video, direction: .recvOnly)
        
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver4)
        mockPeerConnectionCtx.transceivers.append(newMockTransceiver5)
        
        XCTAssertTrue(participantStateActor.getAllParticipants().isEmpty)
        
        let add = [newRemoteParticipant]
        
        for particpant in add {
            let newParticipant = RemoteParticipant(
                participantID: ParticipantID(id: particpant.id),
                dependencies: dependencies,
                groupCallMessageCrypto: groupCallDescription,
                isExistingParticipant: false
            )
            
            participantStateActor.add(pending: newParticipant)
        }
        
        try! await connectionCtx.updateCall(call: participantStateActor, remove: [], add: Set(add))
        
        for loggedActivations in mockPeerConnectionCtx.transceivers.map({ $0 as! MockRTCRtpTransceiver })
            .map(\.loggedActivation) {
            XCTAssertEqual(loggedActivations, 1)
        }
        
        XCTAssertEqual(participantStateActor.getPendingParticipants().count, 1)
        XCTAssertEqual(participantStateActor.getAllParticipants().count, 1)
        XCTAssertEqual(participantStateActor.getCurrentParticipants().count, 0)
    }
}
