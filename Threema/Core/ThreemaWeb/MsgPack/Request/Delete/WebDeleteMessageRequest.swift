import CocoaLumberjackSwift
import Foundation

final class WebDeleteMessageRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
    var conversation: ConversationEntity?
    
    let messageID: Data
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal
        }
        
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        super.init(message: message)
        
        let entityManager = BusinessInjector.ui.entityManager
        if let identity {
            entityManager.performAndWait {
                self.conversation = entityManager.entityFetcher.conversationEntity(for: identity)
            }
        }
        else if let groupID {
            entityManager.performAndWait {
                self.conversation = entityManager.entityFetcher.legacyConversationEntity(for: groupID)
            }
        }
        else {
            DDLogError("Neither identity nor groupID were set.")
        }
    }
    
    func delete() {
        var acknowledgement = WebAbstractMessageAcknowledgement(requestID, false, nil)
        
        guard let conversation else {
            DDLogError("Conversation was nil when it must not be.")
            return
        }
        
        let businessInjector = BusinessInjector(forBackgroundProcess: true)
        
        businessInjector.entityManager.performAndWaitSave {
            guard let conv = businessInjector.entityManager.entityFetcher
                .managedObject(with: conversation.objectID) as? ConversationEntity else {
                acknowledgement.success = false
                acknowledgement.error = "invalidMessage"
                DDLogError("Could not fetch conversation")
                self.ack = acknowledgement
                  
                return
            }
              
            guard let message = businessInjector.entityManager.entityFetcher.message(
                with: self.messageID,
                in: conv
            ) else {
                DDLogError("Could not fetch message")
                acknowledgement.success = false
                acknowledgement.error = "invalidMessage"
                self.ack = acknowledgement
                  
                return
            }
              
            if message.isKind(of: BaseMessageEntity.self) || message.isKind(of: SystemMessageEntity.self) {
                businessInjector.entityManager.entityDestroyer.delete(baseMessage: message)

                conv.lastMessage = MessageFetcher(for: conv, with: businessInjector.entityManager)
                    .lastDisplayMessage()
            }
        }
        
        acknowledgement.success = true
        ack = acknowledgement
    }
}
