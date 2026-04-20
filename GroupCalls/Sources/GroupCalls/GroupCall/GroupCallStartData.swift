import Foundation

/// The initial group call start data received within a Threema message
struct GroupCallStartData: Sendable {
    let protocolVersion: UInt32
    let gck: Data
    let sfuBaseURL: URL
}
