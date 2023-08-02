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

protocol RTCPeerConnectionProtocol: AnyObject {
    var delegate: RTCPeerConnectionDelegate? { get set }
    var transceivers: [RTCRtpTransceiver] { get }
    
    func setRemoteDescription(sdp: RTCSessionDescription) async throws
    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription
    func set(_ localDescription: RTCSessionDescription) async throws
    func add(_ iceCandidate: RTCIceCandidate) async throws
    
    func close()
}

// MARK: - RTCPeerConnection + RTCPeerConnectionProtocol

extension RTCPeerConnection: RTCPeerConnectionProtocol { }
