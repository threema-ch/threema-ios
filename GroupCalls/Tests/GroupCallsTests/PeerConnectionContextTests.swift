import Foundation
import XCTest
@testable import GroupCalls
@testable import WebRTC

final class PeerConnectionContextTests: XCTestCase {

    /// The peer connection context is the `RTCPeerConnectionDelegate` of its peer connection and forwards ICE
    /// connection state changes on `peerConnectionResultStream`. This is the only signal we get when a connection dies.
    @GlobalGroupCallActor
    func testIceConnectionStateChangeIsForwardedOnStream() async throws {
        let peerConnectionContext = PeerConnectionContext(
            peerConnection: MockRTCPeerConnection(),
            dataChannelContext: MockDataChannelContext()
        )

        // The delegate callbacks take a concrete `RTCPeerConnection`, thus we need a real one to call them. The context
        // under test still uses the mock above.
        let realPeerConnection = try XCTUnwrap(PeerConnectionContext.peerConnectionFactory.peerConnection(
            with: RTCConfiguration(),
            constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
            delegate: nil
        ))

        peerConnectionContext.peerConnection(realPeerConnection, didChange: RTCIceConnectionState.failed)

        var iterator = peerConnectionContext.peerConnectionResultStream.makeAsyncIterator()
        let nextResult = await iterator.next()
        let result = try XCTUnwrap(nextResult)

        guard case let .connectionStateChange(newState) = result else {
            XCTFail("Expected a `connectionStateChange` but got \(result)")
            return
        }

        XCTAssertEqual(newState, .failed)
    }
}
