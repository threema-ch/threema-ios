import Foundation

final class WebAvatarUpdate: WebAbstractMessage {
    
    var type: String
    var id: String
        
    init(contact: ContactEntity) {
        self.type = "contact"
        self.id = contact.identity
    
        let avatarObject = WebAvatarResponse(requestID: nil, contact: contact)
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: avatarObject.avatar != nil ? avatarObject.avatar! : nil
        )
    }
    
    init(group: Group) {
        self.type = "group"
        self.id = group.groupID.hexEncodedString()
        let avatarObject = WebAvatarResponse(requestID: nil, group: group)
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: avatarObject.avatar != nil ? avatarObject.avatar! : nil
        )
    }
}
