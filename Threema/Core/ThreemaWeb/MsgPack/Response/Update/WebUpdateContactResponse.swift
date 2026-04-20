import Foundation

final class WebUpdateContactResponse: WebAbstractMessage {
    
    var id: String
    var receiver: [AnyHashable: Any?]?
    
    init(request: WebUpdateContactRequest) {
        if request.contact != nil {
            self.id = request.contact!.identity
            let contact = WebContact(request.contact!)
            self.receiver = contact.objectDict()
            
            let tmpArgs: [AnyHashable: Any?] = ["id": id]
            var tmpData = [AnyHashable: Any?]()
            
            if receiver != nil {
                tmpData.updateValue(receiver, forKey: "receiver")
            }
            
            super.init(
                messageType: "update",
                messageSubType: "contact",
                requestID: nil,
                ack: request.ack,
                args: tmpArgs,
                data: tmpData
            )
        }
        else {
            self.id = request.contact!.identity
            super.init(
                messageType: "update",
                messageSubType: "contact",
                requestID: nil,
                ack: request.ack,
                args: nil,
                data: nil
            )
        }
    }
}
