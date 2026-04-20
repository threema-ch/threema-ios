import Foundation

extension ImageMessageEntity {
    override public func contentToCheckForMentions() -> String? {
        image?.caption()
    }

    #if !DEBUG
        override public var debugDescription: String {
            "<\(type(of: self))>:\(AudioDataEntity.self), image = \(image?.description ?? "nil"),  thumbnail = \(thumbnail?.description ?? "nil"), imageBlobId = \("***"), imageNonce = \("***"), imageSize = \(imageSize?.description ?? "nil"), progress = \(progress?.description ?? "nil"), encryptionKey = \("***")"
        }
    #endif
}
