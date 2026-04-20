import Foundation

final class WebCreateFileMessageResponse: WebAbstractMessage {
    
    var message: BaseMessageEntity?
    var type: String
    var id: String
    var messageID: String?
    
    init(message: BaseMessageEntity, request: WebCreateFileMessageRequest) {
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
        
        super.init(
            messageType: "create",
            messageSubType: "fileMessage",
            requestID: nil,
            ack: request.ack,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    init(request: WebCreateFileMessageRequest) {
        self.type = request.type
        if request.groupID != nil {
            self.id = request.groupID!.hexEncodedString()
        }
        else {
            self.id = request.id!
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, false, nil)
        
        super.init(
            messageType: "create",
            messageSubType: "fileMessage",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
}
