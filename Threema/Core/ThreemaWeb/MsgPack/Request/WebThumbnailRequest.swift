import Foundation

final class WebThumbnailRequest: WebAbstractMessage {
    
    let id: String
    let messageID: Data
    let type: String
    
    override init(message: WebAbstractMessage) {
        self.id = message.args!["id"] as! String
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        self.type = message.args!["type"] as! String
        super.init(message: message)
    }
}
