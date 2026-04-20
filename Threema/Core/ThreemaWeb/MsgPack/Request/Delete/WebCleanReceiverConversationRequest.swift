import Foundation

final class WebCleanReceiverConversationRequest: WebAbstractMessage {
    
    var identity: String?
    var groupID: Data?
    let type: String
    
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
    
    func clean() {
        let entityManager = BusinessInjector.ui.entityManager

        entityManager.performAndWaitSave {
            if let identity = self.identity {
                if let conversation = entityManager.entityFetcher.conversationEntity(for: identity) {
                    entityManager.entityDestroyer.delete(conversation: conversation)
                }
            }
            else if self.groupID != nil {
                if let conversation = entityManager.entityFetcher.legacyConversationEntity(for: self.groupID) {
                    var imageData: Data?
                    var imageHeight: NSNumber?
                    var imageWidth: NSNumber?

                    if let groupImage = conversation.groupImage {
                        imageData = groupImage.data
                        imageHeight = (groupImage.height) as NSNumber
                        imageWidth = (groupImage.width) as NSNumber
                    }

                    entityManager.entityDestroyer.delete(conversation: conversation)

                    let tmpConversation = entityManager.entityCreator.conversationEntity()
                    tmpConversation.contact = conversation.contact
                    tmpConversation.members = conversation.members
                    tmpConversation.groupID = conversation.groupID
                    tmpConversation.groupName = conversation.groupName
                    tmpConversation.groupMyIdentity = conversation.groupMyIdentity

                    if let imageData {
                        let tmpImageData = entityManager.entityCreator.imageDataEntity(
                            data: imageData,
                            size: CGSize(
                                width: Double(truncating: imageWidth ?? 0.0),
                                height: Double(truncating: imageHeight ?? 0.0)
                            )
                        )
                        tmpConversation.groupImage = tmpImageData
                        tmpConversation.groupImageSetDate = conversation.groupImageSetDate
                    }
                }
            }
        }
    }
}
