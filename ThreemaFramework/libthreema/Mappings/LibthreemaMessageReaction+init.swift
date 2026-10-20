import libthreemaSwift
import ThreemaEssentials

extension LibthreemaMessageReaction {
    init(messageReactionEntity: MessageReactionEntity, userIdentity: ThreemaIdentity) throws {
        guard let emoji = messageReactionEntity.emoji else {
            throw MappingError.emoji
        }

        self.init(
            createdAt: messageReactionEntity.date.millisecondsSince1970,
            creatorIdentity: messageReactionEntity.creator?.identity ?? userIdentity.rawValue,
            emoji: LibthreemaEmojiReaction(codepoint: emoji.rawValue)
        )
    }
}
