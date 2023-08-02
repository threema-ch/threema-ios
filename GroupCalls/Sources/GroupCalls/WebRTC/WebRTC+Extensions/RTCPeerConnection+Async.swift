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

// MARK: - Async Versions of some functions

extension RTCPeerConnection {
    func setRemoteDescription(sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.setRemoteDescription(sdp) { error in
                guard let error else {
                    continuation.resume()
                    return
                }
                
                continuation.resume(throwing: error)
            }
        }
    }
    
    func answer(for constraints: RTCMediaConstraints) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            self.answer(for: constraints) { description, err in
                if let err {
                    continuation.resume(throwing: err)
                }
                else if let description {
                    continuation.resume(returning: description)
                }
                else {
                    fatalError()
                }
            }
        }
    }
    
    func set(_ localDescription: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.setLocalDescription(localDescription) { error in
                guard let error else {
                    continuation.resume()
                    return
                }
                
                continuation.resume(throwing: error)
            }
        }
    }
    
    func add(_ iceCandidate: RTCIceCandidate) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.add(iceCandidate) { error in
                guard let error else {
                    continuation.resume()
                    return
                }
                continuation.resume(throwing: error)
            }
        }
    }
}
