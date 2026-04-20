import Foundation

@objc protocol SocketProtocol {
    @objc var isIPv6: Bool { get }
    @objc var isProxyConnection: Bool { get }
    
    @objc init(
        server: String,
        ports: [Int],
        preferIPv6: Bool,
        delegate: SocketProtocolDelegate,
        queue: DispatchQueue
    ) throws

    @objc func connect() -> Bool
    @objc func disconnect()
    @objc func read(length: UInt32, timeout: Int16, tag: Int16)
    @objc func write(data: Data, tag: Int16)
    @objc func write(data: Data)
}
