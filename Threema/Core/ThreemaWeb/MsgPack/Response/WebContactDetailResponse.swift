import Foundation

final class WebContactDetailResponse: WebAbstractMessage {
    
    var contact: ContactEntity?
    var identity: String
    var systemContact: [AnyHashable: Any?]?
    
    init(contact: ContactEntity?, contactDetailRequest: WebContactDetailRequest) {
        self.identity = contactDetailRequest.identity
        var tmpAck = WebAbstractMessageAcknowledgement(contactDetailRequest.requestID, true, nil)
        
        let tmpArgs: [AnyHashable: Any?] = ["identity": identity]
        
        var tmpData: [AnyHashable: Any?]? = ["receiver": []]
        
        if let contact {
            self.contact = contact
            
            let emails: [Any]? = ContactStore.shared().cnContactEmails(for: contact)
            let phoneNumbers: [Any]? = ContactStore.shared().cnContactPhoneNumbers(for: contact)
            
            if emails != nil || phoneNumbers != nil {
                self.systemContact = ["emails": emails, "phoneNumbers": phoneNumbers]
                tmpData = ["receiver": ["systemContact": systemContact]]
            }
            tmpAck.success = true
        }
        else {
            tmpAck.success = false
            tmpAck.error = "invalid_contact"
            tmpData = nil
        }
        
        super.init(
            messageType: "response",
            messageSubType: "contactDetail",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: tmpData
        )
    }
}
