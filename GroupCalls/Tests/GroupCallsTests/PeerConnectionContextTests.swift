import Foundation
import XCTest
@testable import GroupCalls
@testable import WebRTC

final class PeerConnectionContextTests: XCTestCase {
    
    @GlobalGroupCallActor func testBasicInit() async throws {
        let mockPeerConnection = MockRTCPeerConnection()
        
        let mockDataChannelCtx = MockDataChannelContext()
        
        let peerConnectionCtx = PeerConnectionContext(
            peerConnection: mockPeerConnection,
            dataChannelContext: mockDataChannelCtx
        )
    }
}
