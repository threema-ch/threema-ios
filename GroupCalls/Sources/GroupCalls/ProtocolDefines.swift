import Foundation

enum ProtocolDefines {
    static let protocolVersion = 1
    static let callIDLength = 32
    static let personal = "3ma-call"
    static let pcckLength: Int32 = 16
    static let mediaKeyLength: Int32 = 32
    
    static let nanosecondsPerSecond: UInt64 = 1_000_000_000
    static let allowedBaseURLProtocol = "https"
}
