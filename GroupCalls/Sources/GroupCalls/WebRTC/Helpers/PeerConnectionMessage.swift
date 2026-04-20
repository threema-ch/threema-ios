import Foundation

/// Exists to avoid having to pass not sendable RTCDataBuffer between actor boundaries
struct PeerConnectionMessage: Sendable {
    let data: Data
}
