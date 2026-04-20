import Foundation

final class WebUpdateConversationRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
    
    var isStarred: Bool?
        
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as? String
            self.groupID = idString?.hexadecimal
        }
        
        if let data = message.data as? [AnyHashable: Any] {
            self.isStarred = data["isStarred"] as? Bool
        }
        
        super.init(message: message)
    }
    
    func updateConversation() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let entityManager = BusinessInjector.ui.entityManager

        guard isStarred != nil else {
            ack!.success = false
            ack!.error = "badRequest"
            return
        }

        entityManager.performAndWaitSave {
            var conversation: ConversationEntity?

            if self.groupID != nil {
                conversation = entityManager.entityFetcher.legacyConversationEntity(for: self.groupID)
            }
            else if let identity = self.identity {
                conversation = entityManager.entityFetcher.conversationEntity(for: identity)
            }

            guard let conversation else {
                self.ack!.success = false
                self.ack!.error = "invalidConversation"
                return
            }

            conversation.changeVisibility(to: self.isStarred! ? .pinned : .default)
            self.ack!.success = true
        }
    }
}
