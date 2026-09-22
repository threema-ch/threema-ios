import Foundation

enum ProtocolDefines {
    static let protocolVersion = 1
    static let callIDLength = 32
    static let personal = "3ma-call"
    static let pcckLength: Int32 = 16
    static let mediaKeyLength: Int32 = 32
    
    static let nanosecondsPerSecond: UInt64 = 1_000_000_000
    static let allowedBaseURLProtocol = "https"

    /// **Protocol Step: Group Call Peek Steps** 4.: Timeout for a single peek request
    static let peekTimeout: TimeInterval = 15

    /// **Protocol Step: Group Call Refresh Steps** 3.: Timeout for an SFU token refresh
    static let tokenRefreshTimeout: TimeInterval = 15
}
