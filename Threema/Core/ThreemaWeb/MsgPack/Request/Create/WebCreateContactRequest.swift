import Foundation

final class WebCreateContactRequest: WebAbstractMessage {
    
    let identity: String
    
    override init(message: WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        self.identity = data["identity"] as! String
        super.init(message: message)
    }
}
