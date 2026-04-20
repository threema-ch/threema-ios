import Foundation

final class WebCreateGroupRequest: WebAbstractMessage {
    
    let members: [String]
    let name: String?
    let avatar: Data?
    
    override init(message: WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        self.members = data["members"] as! [String]
        self.name = data["name"] as? String
        self.avatar = data["avatar"] as? Data
        super.init(message: message)
    }
}
