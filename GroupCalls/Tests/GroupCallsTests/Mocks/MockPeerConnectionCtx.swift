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

final class MockPeerConnectionCtx: PeerConnectionContextProtocol {
    init(
        peerConnection: GroupCalls.RTCPeerConnectionProtocol,
        dataChannelContext: GroupCalls.DataChannelContextProtocol
    ) {
        self.peerConnection = peerConnection
        self.dataChannelContext = dataChannelContext
    }
    
    static func build<T>(from configuration: RTCConfiguration, with constraints: RTCMediaConstraints) throws -> T
        where T: GroupCalls.PeerConnectionContextProtocol {
        fatalError()
    }
    
    var dataChannelContext: GroupCalls.DataChannelContextProtocol
    
    var peerConnection: GroupCalls.RTCPeerConnectionProtocol
    
    var transceivers = [GroupCalls.RTCRtpTransceiverProtocol]()
}

extension MockPeerConnectionCtx {
    func addTransceivers(for: ParticipantID) {
//        let transceiver = MockRTCRtpTransceiver()
    }
}

final class MockRTCRtpTransceiver: NSObject, GroupCalls.RTCRtpTransceiverProtocol {
    var mid: String
    
    var mediaType: RTCRtpMediaType
    
    var direction: RTCRtpTransceiverDirection
    
    func setDirection(_ direction: RTCRtpTransceiverDirection, error: AutoreleasingUnsafeMutablePointer<NSError?>?) {
        self.direction = direction
    }
    
    var loggedActivation = 0
    
    init(mid: String, mediaType: RTCRtpMediaType, direction: RTCRtpTransceiverDirection) {
        self.mid = mid
        self.mediaType = mediaType
        self.direction = direction
    }
    
    func logActivation() {
        loggedActivation += 1
    }
    
    func setEnabled() {
        // Noop
    }
    
    func setDisabled() {
        // Noop
    }
}
