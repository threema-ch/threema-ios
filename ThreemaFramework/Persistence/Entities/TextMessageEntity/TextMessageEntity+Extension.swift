import Foundation

extension TextMessageEntity {
    override public func contentToCheckForMentions() -> String? {
        text
    }
}
