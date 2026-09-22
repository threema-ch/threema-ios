import Foundation
import libthreemaSwift
import ThreemaEssentials

extension LibthreemaConversationID {
    init(conversationEntity: ConversationEntity, entityManager: EntityManager, userIdentity: ThreemaIdentity) throws {
        if conversationEntity.isGroup {
            guard let groupEntity = entityManager.entityFetcher.groupEntity(for: conversationEntity) else {
                throw MappingError.ballotConversation
            }

            let groupIdentity = ThreemaEssentials.GroupIdentity(
                id: groupEntity.groupID,
                creatorID: groupEntity.groupCreator ?? userIdentity.rawValue
            )

            self = try .group(LibthreemaGroupIdentity(groupIdentity: groupIdentity))
        }
        else if let contact = conversationEntity.contact {
            self = .contact(contact.identity)
        }
        else {
            throw MappingError.ballotConversation
        }
    }
}
