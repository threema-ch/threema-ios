import Foundation

final class WebCreateTextMessageResponse: WebAbstractMessage {
    
    var message: BaseMessageEntity?
    var type: String
    var id: String
    var messageID: String?
    
    init(message: BaseMessageEntity, request: WebCreateTextMessageRequest) {
        self.message = message
        self.type = request.type
        if request.groupID != nil {
            self.id = request.groupID!.hexEncodedString()
        }
        else {
            self.id = request.id!
        }
        
        self.messageID = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpData: [AnyHashable: Any?] = ["messageId": messageID!] as [String: Any]
        let success: Bool = request.tmpError == nil
        let error: String? = request.tmpError
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, success, error)
        
        super.init(
            messageType: "create",
            messageSubType: "textMessage",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    init(request: WebCreateTextMessageRequest) {
        self.type = request.type
        if request.groupID != nil {
            self.id = request.groupID!.hexEncodedString()
        }
        else {
            self.id = request.id!
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let success: Bool = request.tmpError == nil
        let error: String? = request.tmpError
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, success, error)
        
        super.init(
            messageType: "create",
            messageSubType: "textMessage",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
}
