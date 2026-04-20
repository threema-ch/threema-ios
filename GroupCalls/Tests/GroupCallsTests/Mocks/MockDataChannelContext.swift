import Foundation
import ThreemaEssentials
import WebRTC
@testable import GroupCalls

final class MockDataChannelContext: DataChannelContextProtocol {
    let messageStream: AsyncStream<GroupCalls.PeerConnectionMessage>
    let cont: AsyncStream<PeerConnectionMessage>.Continuation
    
    private var sentMessages = 0
    
    let lock = NSLock()
    
    var isClosed = false
    
    init() {
        (self.messageStream, self.cont) = AsyncStream.makeStream(of: PeerConnectionMessage.self)
    }
    
    func sendData(_ buffer: RTCDataBuffer) {
        lock.withLock {
            sentMessages += 1
        }
    }
    
    func dataChannelDidChangeState(_ readyState: RTCDataChannelState) {
        // Noop
    }
    
    func dataChannel(didReceiveMessageWith buffer: RTCDataBuffer) {
        // Noop
    }
    
    func close() {
        // Noop
        isClosed = true
    }
    
    func getNumberOfSentMessages() -> Int {
        lock.withLock {
            self.sentMessages
        }
    }
}
