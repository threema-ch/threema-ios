import Foundation
import ThreemaEssentials
import XCTest

@testable import GroupCalls
@testable import WebRTC

final class ConnectionContextTests: XCTestCase {
    
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")

    @GlobalGroupCallActor func testTeardownClosesConnections() async throws {
        let certificate = TestDataProvider.certificate()
        let sessionParameters = TestDataProvider.sessionParameters()

        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelContext()
        
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
        let certificate = TestDataProvider.certificate()
        let sessionParameters = TestDataProvider.sessionParameters()

        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelContext()
        
        let mockPeerConnectionCtx = MockPeerConnectionContext(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
        
        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        mockPeerConnectionCtx.transceivers = [
            MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .recvOnly),
            MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .recvOnly),
        ]

        let connectionCtx = ConnectionContext<MockPeerConnectionContext, MockRTCRtpTransceiver>(
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
        let certificate = TestDataProvider.certificate()
        let sessionParameters = TestDataProvider.sessionParameters()

        let dependencies = MockDependencies().create()
        
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelContext()

        let mockPeerConnectionCtx = MockPeerConnectionContext(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )

        let localParticipant = try LocalParticipant(
            participantID: ParticipantID(id: 0),
            localContactModel: localContactModel,
            dependencies: dependencies
        )

        let mockCryptoAdapter = MockGroupCallFrameCryptoAdapter()

        let participantStateActor = ParticipantState(localParticipant: localParticipant)

        mockPeerConnectionCtx.transceivers = [
            MockRTCRtpTransceiver(mid: "!", mediaType: .audio, direction: .recvOnly),
            MockRTCRtpTransceiver(mid: "#", mediaType: .video, direction: .recvOnly),
        ]

        let connectionCtx = ConnectionContext<MockPeerConnectionContext, MockRTCRtpTransceiver>(
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
    }
}
