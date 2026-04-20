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
