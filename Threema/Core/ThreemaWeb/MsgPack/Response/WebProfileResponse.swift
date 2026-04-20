import Foundation

final class WebProfileResponse: WebAbstractMessage {
    
    var identity: String
    var publicKey: Data
    var publicNickname: String?
    var avatar: Data?
    
    init(requestID: String?) {
        self.identity = MyIdentityStore.shared().identity
        self.publicKey = MyIdentityStore.shared().publicKey
        
        if MyIdentityStore.shared().pushFromName != nil {
            self.publicNickname = MyIdentityStore.shared().pushFromName
        }
        else {
            self.publicNickname = MyIdentityStore.shared().identity
        }
        
        if let profilePicture = MyIdentityStore.shared().profilePicture,
           profilePicture["ProfilePicture"] != nil {
            
            self.avatar = profilePicture["ProfilePicture"] as? Data
        }
        
        var tmpData: [AnyHashable: Any?] = [
            "identity": identity,
            "publicKey": publicKey,
            "publicNickname": publicNickname,
        ]
        
        if avatar != nil {
            tmpData.updateValue(avatar!, forKey: "avatar")
        }
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "profile",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: tmpData
        )
    }
}
