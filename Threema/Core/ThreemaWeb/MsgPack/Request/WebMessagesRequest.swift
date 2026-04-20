import Foundation

final class WebMessagesRequest: WebAbstractMessage {
    
    var type: String
    var id: String
    var refMsgID: Data?
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        self.id = message.args!["id"] as! String
        let messageIDBase64 = message.args!["refMsgId"] as? String
        if messageIDBase64 != nil {
            self.refMsgID = Data(base64Encoded: messageIDBase64!, options: .ignoreUnknownCharacters)
        }
        super.init(message: message)
    }
}
