import Foundation
import ThreemaFramework

final class WebThumbnailResponse: WebAbstractMessage {
    
    var id: String
    var messageID: String
    var type: String
    var message: BaseMessageEntity?
    
    init(request: WebThumbnailRequest, imageMessageEntity: ImageMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail(imageMessageEntity: imageMessageEntity, onlyThumbnail: false)
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = request.requestID != nil ? WebAbstractMessageAcknowledgement(request.requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "thumbnail",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: webThumbnail.image
        )
    }
    
    init(request: WebThumbnailRequest, videoMessageEntity: VideoMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail(videoMessageEntity, onlyThumbnail: false)
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = request.requestID != nil ? WebAbstractMessageAcknowledgement(request.requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "thumbnail",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: webThumbnail.image
        )
    }
    
    init(request: WebThumbnailRequest, fileMessageEntity: FileMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail(fileMessageEntity, onlyThumbnail: false)
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = request.requestID != nil ? WebAbstractMessageAcknowledgement(request.requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "thumbnail",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: webThumbnail.image
        )
    }
}
