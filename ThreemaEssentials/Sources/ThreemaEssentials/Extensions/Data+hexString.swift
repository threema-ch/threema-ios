import Foundation

extension Data {
    public var hexString: String {
        map { String(format: "%02hhx", $0) }
            .joined()
    }
}
