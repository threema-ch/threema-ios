import Foundation

final class WebAvatarRequest: WebAbstractMessage {
    
    let type: String
    let id: String
    let highResolution: Bool
    let maxSize: Int?
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        self.id = message.args!["id"] as! String
        self.highResolution = message.args!["highResolution"] as! Bool
        self.maxSize = message.args!["maxSize"] as? Int
        super.init(message: message)
    }
}
