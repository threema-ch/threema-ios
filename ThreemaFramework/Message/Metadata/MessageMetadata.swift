import Foundation

@objc public final class MessageMetadata: NSObject {
    @objc public let nickname: String?
    @objc public let messageID: Data?
    @objc public let createdAt: Date?
    
    @objc public init(nickname: String?, messageID: Data?, createdAt: Date?) {
        self.nickname = nickname
        self.messageID = messageID
        self.createdAt = createdAt
    }
}
