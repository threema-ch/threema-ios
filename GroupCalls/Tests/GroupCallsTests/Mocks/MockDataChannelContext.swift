import Foundation
import ThreemaEssentials
import WebRTC
@testable import GroupCalls

final class MockDataChannelContext: DataChannelContextProtocol, @unchecked Sendable {
    let messageStream: AsyncStream<GroupCalls.PeerConnectionMessage>
    let cont: AsyncStream<PeerConnectionMessage>.Continuation

    private var sentMessages = 0
    private var sentData = [Data]()
    private var closed = false

    let lock = NSLock()

    var isClosed: Bool {
        lock.withLock { closed }
    }

    init() {
        (self.messageStream, self.cont) = AsyncStream.makeStream(of: PeerConnectionMessage.self)
    }
    
    func sendData(_ buffer: RTCDataBuffer) {
        lock.withLock {
            sentMessages += 1
            sentData.append(buffer.data)
        }
    }
    
    func dataChannelDidChangeState(_ readyState: RTCDataChannelState) {
        // Noop
    }
    
    func dataChannel(didReceiveMessageWith buffer: RTCDataBuffer) {
        // Noop
    }
    
    func close() {
        lock.withLock {
            closed = true
        }
    }
    
    func getNumberOfSentMessages() -> Int {
        lock.withLock {
            self.sentMessages
        }
    }

    func getSentData() -> [Data] {
        lock.withLock {
            self.sentData
        }
    }
}
