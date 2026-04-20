import Foundation

extension BaseMessageEntity: LoggingDescriptionProtocol {
    public var loggingDescription: String {
        "(type: \(type(of: self)); id: \(id.hexString))"
    }
}
