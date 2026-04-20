import Foundation

final class WebAckRequest: WebAbstractMessage {
    
    let type: String
    let id: String
    let messageID: Data
    let acknowledged: Bool
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        self.id = message.args!["id"] as! String
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        self.acknowledged = message.args!["acknowledged"] as! Bool
        super.init(message: message)
    }
}
