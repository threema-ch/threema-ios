import Foundation

public protocol KeyWrapperProtocol {
    func wrap(key: Data?) throws -> Data?
    func unwrap(key: Data?) throws -> Data?
}
