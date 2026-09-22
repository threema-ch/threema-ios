import Foundation

public protocol VoIPCallMessageProtocol: VoIPCallIDProtocol {
    var completion: (() -> Void)? { get }
    
    var receivedAsReflected: Bool? { get }
    var isOutgoing: Bool { get }

    static func decodeAsObject<T: VoIPCallMessageProtocol>(
        _ dictionary: [AnyHashable: Any],
        receivedAsReflected: Bool,
        isOutgoing: Bool
    ) -> T
    
    func encodeAsJson() throws -> Data
}
