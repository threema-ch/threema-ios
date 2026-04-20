import Foundation

final class WebConversationUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new
        case modified
        case removed
    }
    
    var mode: String
    
    init(conversation: ConversationEntity, objectMode: ObjectMode, session: WCSession) {
        self.mode = objectMode.rawValue
        
        let businessInjector = BusinessInjector.ui
        var index = 0
        
        if let allConversations = businessInjector.entityManager.entityFetcher
            .conversationEntitiesSorted() {
            let unarchivedConversations = allConversations
                .filter { $0.conversationVisibility == .default || $0.conversationVisibility == .pinned }

            let unarchivedResult = WebConversationUpdate.indexForConversation(
                conversation: conversation,
                in: unarchivedConversations
            )
            if unarchivedResult.found {
                index = unarchivedResult.index
            }
            else {
                let archivedConversations = allConversations.filter { $0.conversationVisibility == .archived }
                let archivedResult = WebConversationUpdate.indexForConversation(
                    conversation: conversation,
                    in: archivedConversations
                )
                if archivedResult.found {
                    if !unarchivedConversations.isEmpty {
                        index = unarchivedConversations.count + archivedResult.index
                    }
                    else {
                        index = archivedResult.index
                    }
                }
            }
        }
                
        let webConversation = WebConversation(
            conversation: conversation,
            index: index,
            request: nil,
            addAvatar: true,
            businessInjector: businessInjector,
            session: session
        )
        let tmpArgs: [AnyHashable: Any?] = ["mode": mode]
        let tmpData: [AnyHashable: Any?] = [
            "type": webConversation.type,
            "id": webConversation.id,
            "position": webConversation.position,
            "messageCount": webConversation.messageCount,
            "unreadCount": max(0, webConversation.unreadCount),
            "latestMessage": webConversation.latestMessage,
            "notifications": webConversation.notifications?.objectDict(),
            "isStarred": webConversation.isStarred,
            "isUnread": webConversation.isUnread,
        ]
        
        super.init(
            messageType: "update",
            messageSubType: "conversation",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    init(conversation: ConversationEntity, contact: ContactEntity?, objectMode: ObjectMode) {
        self.mode = objectMode.rawValue
        
        let webConversation = WebConversation(deletedConversation: conversation, contact: contact)
        let tmpArgs: [AnyHashable: Any?] = ["mode": mode]
        let tmpData: [AnyHashable: Any?] = [
            "type": webConversation.type,
            "id": webConversation.id,
            "position": webConversation.position,
            "messageCount": webConversation.messageCount,
            "unreadCount": webConversation.unreadCount,
        ]
        
        super.init(
            messageType: "update",
            messageSubType: "conversation",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }

    private static func indexForConversation(
        conversation: ConversationEntity,
        in conversations: [ConversationEntity]
    ) -> (found: Bool, index: Int) {
        var index = 0
        var found = false

        for conver in conversations {
            if conver.groupID != nil || conversation.groupID != nil {
                if conver.groupID == conversation.groupID {
                    found = true
                }
            }
            else if let converContact = conver.contact, let conversationContact = conversation.contact {
                if converContact.identity == conversationContact.identity {
                    found = true
                }
            }
            
            if found == false {
                index = index + 1
            }
        }
        return (found, index)
    }
}
