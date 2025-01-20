//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
