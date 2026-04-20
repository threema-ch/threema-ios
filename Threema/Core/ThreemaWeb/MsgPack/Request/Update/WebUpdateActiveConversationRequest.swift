import Foundation

final class WebUpdateActiveConversationRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
            
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as? String
            self.groupID = idString?.hexadecimal
        }
                
        super.init(message: message)
    }
    
    func updateActiveConversation() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)

        let entityManager = BusinessInjector.ui.entityManager

        entityManager.performAndWaitSave {
            if self.groupID != nil {
                let conversation = entityManager.entityFetcher.legacyConversationEntity(for: self.groupID)
                if conversation?.unreadMessageCount == -1 {
                    conversation!.unreadMessageCount = 0
                }
            }
            else if let identity = self.identity {
                let conversation = entityManager.entityFetcher.conversationEntity(for: identity)
                if conversation?.unreadMessageCount == -1 {
                    conversation!.unreadMessageCount = 0
                }
            }
        }

        DispatchQueue.main.async {
            let notificationManager = NotificationManager()
            notificationManager.updateUnreadMessagesCount()
        }

        ack!.success = true
    }
}
