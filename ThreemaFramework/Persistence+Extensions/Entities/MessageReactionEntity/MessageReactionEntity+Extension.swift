import Foundation

extension MessageReactionEntity {
    var emoji: Emoji? {
        .init(rawValue: reaction)
    }
}
