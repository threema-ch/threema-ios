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
@testable import ThreemaProtocols
@testable import WebRTC

final class GroupCallContextTests: XCTestCase {
    
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!

    @GlobalGroupCallActor
    func testBasicInit() throws {
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
        
        let localParticipant = LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )
        
        let gck = Data(repeating: 0x01, count: 32)
        let groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: ThreemaIdentity("ECHOECHO"))

        let groupCallDescription = try! GroupCallBaseState(
            group: GroupCallsThreemaGroupModel(
                groupIdentity: groupIdentity,
                groupName: "ECHOECHO"
            ),
            startedAt: Date(),
            dependencies: dependencies,
            groupCallStartData: GroupCallStartData(protocolVersion: 0, gck: gck, sfuBaseURL: sfuBaseURL)
        )
        
        mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .sendOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .sendOnly)
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
        
        _ = try GroupCallContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
            connectionContext: connectionCtx,
            localParticipant: localParticipant,
            dependencies: dependencies,
            groupCallDescription: groupCallDescription
        )
    }
    
    @GlobalGroupCallActor
    func testSendCallStateUpdateToSFU() async throws {
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
            localContactModel: localContactModel,
            dependencies: dependencies
        )
        
        let groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: ThreemaIdentity("ECHOECHO"))
        let groupCallDescription = try! GroupCallBaseState(
            group: GroupCallsThreemaGroupModel(
                groupIdentity: groupIdentity,
                groupName: "ECHOECHO"
            ),
            startedAt: Date(),
            dependencies: dependencies,
            groupCallStartData: GroupCallStartData(
                protocolVersion: 0,
                gck: Data(repeating: 0x01, count: 32),
                sfuBaseURL: sfuBaseURL
            )
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()
        
        mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .sendOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .sendOnly)
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
        
        let groupCallContext = try GroupCallContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
            connectionContext: connectionCtx,
            localParticipant: localParticipant,
            dependencies: dependencies,
            groupCallDescription: groupCallDescription
        )
        
        XCTAssertNoThrow(try groupCallContext.startStateUpdateTaskIfNecessary())
        
        await Task.yield()
        
        // This isn't great since our tests will either succeed or fail by timing out
        // we never quickly discover that our tests fail. But otherwise we might not wait long enough for the state to
        // converge.
        while mockDataChannelCtx.getNumberOfSentMessages() != 1 {
            await Task.yield()
        }
        
        XCTAssertEqual(mockDataChannelCtx.getNumberOfSentMessages(), 1)
    }
    
    //    @ActualGlobalActor
    #if compiler(>=5.8)
        func testHandoverMessageToCorrectParticipant() async throws {
            let expectation = XCTestExpectation(description: "Outer Expectation")
            Task.detached {
                let certificate = RTCCertificate(
                    privateKey: "helloWorld",
                    certificate: "helloWorld",
                    fingerprint: "helloWorld"
                )
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
            
                let localParticipant = await LocalParticipant(
                    participantID: ParticipantID(id: 0),
                    localContactModel: self.localContactModel,
                    dependencies: dependencies
                )
                
                let groupIdentity = GroupIdentity(
                    id: Data(repeating: 0x00, count: 8),
                    creator: ThreemaIdentity("ECHOECHO")
                )
                let groupCallDescription = try! GroupCallBaseState(
                    group: GroupCallsThreemaGroupModel(
                        groupIdentity: groupIdentity,
                        groupName: "ECHOECHO"
                    ),
                    startedAt: Date(),
                    dependencies: dependencies,
                    groupCallStartData: GroupCallStartData(
                        protocolVersion: 0,
                        gck: Data(repeating: 0x01, count: 32),
                        sfuBaseURL: self.sfuBaseURL
                    )
                )
                
                let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()
            
                mockPeerConnectionCtx.transceivers = [MockRTCRtpTransceiver]()
                let newMockTransceiver1 = MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .sendOnly)
                let newMockTransceiver2 = MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .sendOnly)
            
                mockPeerConnectionCtx.transceivers.append(newMockTransceiver1)
                mockPeerConnectionCtx.transceivers.append(newMockTransceiver2)
            
                let connectionCtx = await ConnectionContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
                    certificate: certificate,
                    cryptoContext: mockCryptoAdapter,
                    sessionParameters: sessionParameters,
                    dependencies: dependencies,
                    peerConnectionContext: mockPeerConnectionCtx
                )
            
                let groupCallContext = try await GroupCallContext<MockPeerConnectionCtx, MockRTCRtpTransceiver>(
                    connectionContext: connectionCtx,
                    localParticipant: localParticipant,
                    dependencies: dependencies,
                    groupCallDescription: groupCallDescription
                )
            
                try await connectionCtx.mapLocalTransceivers(ownAudioMuteState: .muted, ownVideoMuteState: .muted)
            
                try await groupCallContext.startStateUpdateTaskIfNecessary()
            
                var add = [ParticipantID]()
            
                for i in 1..<100 {
                    add.append(ParticipantID(id: UInt32(i)))
                }
            
                for participant in add {
                    mockPeerConnectionCtx.transceivers.append(contentsOf: self.transceivers(for: participant))
                }
            
                try! await groupCallContext.updateParticipants(add: add, remove: [], existingParticipants: true)
                
                if #available(iOS 16.0, *) {
                    try await Task.sleep(for: .seconds(2))
                }
                else {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 2)
                }
                
                XCTAssertEqual(mockDataChannelCtx.getNumberOfSentMessages(), 1)
                
                var helloMessage = Groupcall_ParticipantToParticipant.Handshake.Hello()
                helloMessage.identity = "ECHOECHO"
                helloMessage.nickname = "ECHOECHO"
                // The random bytes of the crypto mock also returns 0x01 thus we have to use something different here
                helloMessage.pcck = Data(repeating: 0x03, count: 32)
                helloMessage.pck = Data(repeating: 0x02, count: 32)
            
                let nonce = Data(repeating: 0x03, count: 24)
            
                var handshakeHello = Groupcall_ParticipantToParticipant.Handshake.HelloEnvelope()
                handshakeHello.hello = helloMessage
                handshakeHello.padding = nonce
            
                let serialized = try handshakeHello.ownSerializedData()
            
                let encrypted = try XCTUnwrap(groupCallDescription.symmetricEncryptByGCHK(serialized, nonce: nonce))
            
                var data = nonce
                data.append(encrypted)
            
                var envelope = Groupcall_ParticipantToParticipant.OuterEnvelope()
                envelope.encryptedData = data
                envelope.receiver = 0
                envelope.sender = 1
            
                let reaction = try! await groupCallContext.handle(envelope)
            
                if case let .participantToParticipant(participant, data) = reaction {
                    let id = await participant.participantID.id
                    print("ID is \(id)")
                    XCTAssertEqual(id, envelope.sender)
                    XCTAssertGreaterThan(data.count, 0)
                }
                expectation.fulfill()
            }
        
            // TODO: (IOS-3875) Timeout
            await fulfillment(of: [expectation], timeout: 100.0)
        }
    #endif
}

extension GroupCallContextTests {
    
    func transceivers(for participantID: ParticipantID) -> [MockRTCRtpTransceiver] {
        var transceivers = [MockRTCRtpTransceiver]()
        
        let mids = Mids(from: participantID)
        
        let newMockTransceiver1 = MockRTCRtpTransceiver(mid: mids.microphone, mediaType: .audio, direction: .recvOnly)
        let newMockTransceiver2 = MockRTCRtpTransceiver(mid: mids.camera, mediaType: .video, direction: .recvOnly)
        
        transceivers.append(newMockTransceiver1)
        transceivers.append(newMockTransceiver2)
        
        return transceivers
    }
}
