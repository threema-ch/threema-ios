import Foundation

final class WebConversationsRequest: WebAbstractMessage {
    
    let maxSize: Int
    
    override init(message: WebAbstractMessage) {
        self.maxSize = Int(message.args!["maxSize"] as! Int8)
        super.init(message: message)
    }
}
