import Foundation
import ThreemaFramework

final class WebBlobResponse: WebAbstractMessage {
    
    private let blobManager = BlobManager.shared
    
    var id: String
    var messageID: String
    var type: String
        
    var baseMessage: BaseMessageEntity
    
    init(request: WebBlobRequest, imageMessage: ImageMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.baseMessage = imageMessage
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, false, nil)
        
        super.init(
            messageType: "response",
            messageSubType: "blob",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
    
    init(request: WebBlobRequest, videoMessageEntity: VideoMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.baseMessage = videoMessageEntity
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, false, nil)
        
        super.init(
            messageType: "response",
            messageSubType: "blob",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
    
    init(request: WebBlobRequest, audioMessageEntity: AudioMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.baseMessage = audioMessageEntity
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, false, nil)
        
        super.init(
            messageType: "response",
            messageSubType: "blob",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
    
    init(request: WebBlobRequest, fileMessageEntity: FileMessageEntity) {
        self.id = request.id
        self.type = request.type
        self.messageID = request.messageID.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.baseMessage = fileMessageEntity
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "messageId": messageID, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, false, nil)
        
        super.init(
            messageType: "response",
            messageSubType: "blob",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: nil
        )
    }
    
    func addImage(completion: @escaping () -> Void) {
        Task {
            let result = try await blobManager.syncBlobsThrows(for: baseMessage.objectID)
            switch result {
            case .uploaded, .downloaded:
                let webBlob = WebBlob(imageMessageEntity: baseMessage as! ImageMessageEntity)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                }
                else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                
            case .failed, .inProgress:
                self.ack?.success = false
                self.ack?.error = "blobDownloadFailed"
                self.args?.updateValue(self.ack?.success, forKey: "success")
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            completion()
        }
    }
    
    func addVideo(completion: @escaping () -> Void) {
        Task {
            let result = try await blobManager.syncBlobsThrows(for: baseMessage.objectID)
            switch result {
            case .uploaded, .downloaded:
                let webBlob = WebBlob(videoMessageEntity: baseMessage as! VideoMessageEntity)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                }
                else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                
            case .failed, .inProgress:
                self.ack?.success = false
                self.ack?.error = "blobDownloadFailed"
                self.args?.updateValue(self.ack?.success, forKey: "success")
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            completion()
        }
    }
    
    func addAudio(completion: @escaping () -> Void) {
        Task {
            let result = try await blobManager.syncBlobsThrows(for: baseMessage.objectID)
            switch result {
            case .uploaded, .downloaded:
                let webBlob = WebBlob(audioMessageEntity: baseMessage as! AudioMessageEntity)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                }
                else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                
            case .failed, .inProgress:
                self.ack?.success = false
                self.ack?.error = "blobDownloadFailed"
                self.args?.updateValue(self.ack?.success, forKey: "success")
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            completion()
        }
    }
    
    func addFile(completion: @escaping () -> Void) {
        Task {
            let result = try await blobManager.syncBlobsThrows(for: baseMessage.objectID)
            switch result {
            case .uploaded, .downloaded:
                let webBlob = WebBlob(fileMessageEntity: baseMessage as! FileMessageEntity)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                }
                else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                
            case .failed, .inProgress:
                self.ack?.success = false
                self.ack?.error = "blobDownloadFailed"
                self.args?.updateValue(self.ack?.success, forKey: "success")
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            completion()
        }
    }
}
