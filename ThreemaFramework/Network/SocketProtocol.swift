import Foundation

@objc protocol SocketProtocol {
    var isIPv6: Bool { get }
    var isProxyConnection: Bool { get }
    
    init(
        server: String,
        ports: [Int],
        preferIPv6: Bool,
        delegate: SocketProtocolDelegate,
        queue: DispatchQueue
    ) throws

    func connect() -> Bool
    func disconnect()
    func read(length: UInt32, timeout: Int16, tag: Int16)
    func write(data: Data, tag: Int16)
    func write(data: Data)
}
