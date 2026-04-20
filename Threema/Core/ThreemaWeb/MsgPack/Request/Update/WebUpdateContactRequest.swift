import Foundation

final class WebUpdateContactRequest: WebAbstractMessage {
    
    let identity: String
    
    var firstName: String?
    var lastName: String?
    var avatar: Data?
    var deleteAvatar = false
    
    var contact: ContactEntity?
    
    override init(message: WebAbstractMessage) {
        
        self.identity = message.args!["identity"] as! String
        
        if let data = message.data as? [AnyHashable: Any?] {
            self.firstName = data["firstName"] as? String
            self.lastName = data["lastName"] as? String
            self.avatar = data["avatar"] as? Data
            
            if data["avatar"] != nil {
                if avatar == nil {
                    self.deleteAvatar = true
                }
                else {
                    let image = UIImage(data: avatar!)
                    if image!.size.width >= CGFloat(kContactImageSize) || image!.size
                        .height >= CGFloat(kContactImageSize) {
                        self.avatar = MediaConverter.scaleImageData(
                            to: avatar!,
                            toMaxSize: CGFloat(kContactImageSize),
                            useJPEG: false
                        )
                    }
                }
            }
        }
        super.init(message: message)
    }
    
    func updateContact() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let entityManager = BusinessInjector.ui.entityManager

        if firstName != nil {
            if firstName!.lengthOfBytes(using: .utf8) > 256 {
                ack!.success = false
                ack!.error = "valueTooLong"
                
                let identity = identity
                contact = entityManager.performAndWait {
                    entityManager.entityFetcher.contactEntity(for: identity)
                }
                return
            }
        }
        if lastName != nil {
            if lastName!.lengthOfBytes(using: .utf8) > 256 {
                ack!.success = false
                ack!.error = "valueTooLong"
                
                let identity = identity
                contact = entityManager.performAndWait {
                    entityManager.entityFetcher.contactEntity(for: identity)
                }
                return
            }
        }

        contact = entityManager.performAndWaitSave {
            let updatedContact = entityManager.entityFetcher.contactEntity(for: self.identity)

            updatedContact?.setFirstName(
                to: self.firstName,
                sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName
            )
            updatedContact?.setLastName(
                to: self.lastName,
                sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName
            )

            if self.avatar != nil || self.deleteAvatar == true {
                updatedContact?.imageData = self.avatar
            }

            return updatedContact
        }
        ack!.success = true
    }
}
