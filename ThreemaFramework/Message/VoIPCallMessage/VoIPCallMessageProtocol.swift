import Foundation

public protocol VoIPCallMessageProtocol: VoIPCallIDProtocol {
    var completion: (() -> Void)? { get }
    
    static func decodeAsObject<T: VoIPCallMessageProtocol>(_ dictionary: [AnyHashable: Any]) -> T
    func encodeAsJson() throws -> Data
}
