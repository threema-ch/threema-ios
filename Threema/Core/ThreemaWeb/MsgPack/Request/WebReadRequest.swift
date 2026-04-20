import Foundation

final class WebReadRequest: WebAbstractMessage {
    
    let type: String
    let id: String
    var messageID: Data?
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        self.id = message.args!["id"] as! String
        let messageIDBase64 = message.args!["messageId"] as! String
        if messageIDBase64 != "unreadMessage" {
            self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        }
        super.init(message: message)
    }
}
