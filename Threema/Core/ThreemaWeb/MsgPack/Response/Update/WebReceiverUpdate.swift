import Foundation

final class WebReceiverUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new
        case modified
        case refresh
        case removed
    }

    var id: String
    var mode: String
    var type: String
    
    init(updatedContact: ContactEntity, objectMode: ObjectMode) {
        
        self.id = updatedContact.identity
        self.mode = objectMode.rawValue
        self.type = "contact"
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "mode": mode, "type": type]
        let webContact = WebContact(updatedContact)
        super.init(
            messageType: "update",
            messageSubType: "receiver",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: webContact.objectDict()
        )
    }
    
    init(updatedGroup: Group, objectMode: ObjectMode) {
        
        self.id = updatedGroup.groupID.hexEncodedString()
        self.mode = objectMode.rawValue
        self.type = "group"
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "mode": mode, "type": type]
        let webGroup = WebGroup(group: updatedGroup)
        super.init(
            messageType: "update",
            messageSubType: "receiver",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: webGroup.objectDict()
        )
    }
}
