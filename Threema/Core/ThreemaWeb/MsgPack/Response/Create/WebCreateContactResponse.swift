import Foundation
import ThreemaFramework

final class WebCreateContactResponse: WebAbstractMessage {

    var identity: String
    var contact: ContactEntity?
    
    init(request: WebCreateContactRequest) {

        self.identity = request.identity.uppercased()
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, true, nil)
        
        super.init(messageType: "create", messageSubType: "contact", requestID: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addContact(completion: @escaping () -> Void) {
        let mdmSetup = MDMSetup()!
        if mdmSetup.disableAddContact() {
            ack!.success = false
            ack!.error = "disabledByPolicy"
            args = ["identity": identity]
            data = nil
            completion()
            return
        }
        
        if identity.count != kIdentityLen {
            ack!.success = false
            ack!.error = "invalidIdentity"
            args = ["identity": identity]
            data = nil
            completion()
            return
        }
        
        ContactStore.shared()
            .addContact(
                with: identity,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue),
                onCompletion: { theContact, _ in
                    if MyIdentityStore.shared().isValidIdentity, self.identity == MyIdentityStore.shared().identity {
                        self.ack!.success = false
                        self.ack!.error = "invalidIdentity"
                        self.args = ["identity": self.identity]
                        self.data = nil
                        completion()
                        return
                    }
            
                    if theContact == nil {
                        self.ack!.success = false
                        self.ack!.error = "internalError"
                        self.args = ["identity": self.identity]
                        self.data = nil
                        completion()
                        return
                    }
            
                    self.contact = theContact as? ContactEntity

                    self.ack!.success = true
                    self.args = ["identity": self.identity]
                    let webContact = WebContact(self.contact!)
                    self.data = ["receiver": webContact.objectDict()]
                    completion()
                }
            ) { _ in
                self.ack!.success = false
                self.ack!.error = "invalidIdentity"
                self.args = ["identity": self.identity]
                self.data = nil
                completion()
            }
    }
}
