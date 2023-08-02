//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import WebRTC
@testable import GroupCalls

final class MockDataChannelCtx: DataChannelContextProtocol {
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
