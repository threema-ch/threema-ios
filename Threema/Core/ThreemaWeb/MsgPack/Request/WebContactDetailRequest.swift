import Foundation

final class WebContactDetailRequest: WebAbstractMessage {
    
    let identity: String
    
    override init(message: WebAbstractMessage) {
        
        self.identity = message.args!["identity"] as! String
        super.init(message: message)
    }
}
