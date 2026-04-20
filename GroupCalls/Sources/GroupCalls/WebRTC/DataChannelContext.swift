import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import WebRTC

protocol DataChannelContextProtocol: AnyObject, Sendable {
    var messageStream: AsyncStream<PeerConnectionMessage> { get }
    
    func sendData(_ buffer: RTCDataBuffer)
    
    func dataChannelDidChangeState(_ readyState: RTCDataChannelState)
    func dataChannel(didReceiveMessageWith buffer: RTCDataBuffer)
    
    func close()
}

final class DataChannelContext: NSObject, Sendable {
    // MARK: Private Properties
    
    fileprivate let dataChannel: RTCDataChannelProtocol
    
    // MARK: Message Streams
    
    fileprivate let cont: AsyncStream<PeerConnectionMessage>.Continuation
    // Conformance for `DataChannelContextProtocol`
    let messageStream: AsyncStream<PeerConnectionMessage>
    
    // MARK: - Lifecycle
    
    convenience init(peerConnection: RTCPeerConnection) {
        let dataChannelConfiguration = RTCDataChannelConfiguration()
        // swiftformat:disable:next all
        dataChannelConfiguration.channelId = 0
        dataChannelConfiguration.isNegotiated = true
        dataChannelConfiguration.isOrdered = true
        
        guard let dataChannel = peerConnection.dataChannel(
            forLabel: "p2s",
            configuration: dataChannelConfiguration
        ) else {
            fatalError()
        }
        
        self.init(dataChannel: dataChannel)
    }
    
    init(dataChannel: RTCDataChannelProtocol) {
        self.dataChannel = dataChannel
        
        (self.messageStream, self.cont) = AsyncStream.makeStream(of: PeerConnectionMessage.self)
        
        super.init()
        
        self.dataChannel.delegate = self
    }
}

// MARK: - DataChannelContextProtocol

extension DataChannelContext: DataChannelContextProtocol {
    func sendData(_ buffer: RTCDataBuffer) {
        _ = dataChannel.sendData(buffer)
    }
    
    func close() {
        cont.finish()
        dataChannel.close()
    }
}

// MARK: - RTCDataChannelDelegate

extension DataChannelContext: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        dataChannelDidChangeState(dataChannel.readyState)
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.dataChannel(didReceiveMessageWith: buffer)
    }
}

extension DataChannelContext {
    func dataChannelDidChangeState(_ readyState: RTCDataChannelState) {
        DDLogNotice("[GroupCall] \(#function) \(readyState)")
        if readyState == .closed {
            cont.finish()
        }
    }
    
    func dataChannel(didReceiveMessageWith buffer: RTCDataBuffer) {
        DDLogNotice("[GroupCall] \(#function)")
        cont.yield(PeerConnectionMessage(data: buffer.data))
    }
}
