//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaFramework

class WebBlobResponse: WebAbstractMessage {
    
    var id: String
    var messageID: String
    var type: String
    
    var baseMessage: BaseMessage
    
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
    
    func addImage(completion: (() -> Void)?) {
        let imageMessageEntity = baseMessage as! ImageMessageEntity
        if imageMessageEntity.image == nil {
            let loader = ImageMessageLoader()
            DispatchQueue.main.sync {
                loader.start(with: imageMessageEntity, onCompletion: { loadedMessage in
                    let webBlob = WebBlob(imageMessageEntity: loadedMessage as! ImageMessageEntity)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    }
                    else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { _ in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        }
        else {
            let webBlob = WebBlob(imageMessageEntity: imageMessageEntity)
            if webBlob.blob != nil {
                data = webBlob.objectDict()
                ack?.success = true
            }
            else {
                ack?.success = false
                ack?.error = "internalError"
                args?.updateValue(ack?.error, forKey: "error")
            }
            args?.updateValue(ack?.success, forKey: "success")
            completion!()
        }
    }
    
    func addVideo(completion: (() -> Void)?) {
        DispatchQueue.main.sync {
            let videoMessageEntity = self.baseMessage as! VideoMessageEntity
            if videoMessageEntity.video == nil {
                let loader = VideoMessageLoader()
                
                loader.start(with: videoMessageEntity, onCompletion: { loadedMessage in
                    let webBlob = WebBlob(videoMessageEntity: loadedMessage as! VideoMessageEntity)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    }
                    else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                    
                }, onError: { _ in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
            else {
                let webBlob = WebBlob(videoMessageEntity: videoMessageEntity)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                }
                else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                self.args?.updateValue(self.ack?.success, forKey: "success")
                completion!()
            }
        }
    }
    
    func addAudio(completion: (() -> Void)?) {
        let audioMessageEntity = baseMessage as! AudioMessageEntity
        if audioMessageEntity.audio == nil {
            DispatchQueue.main.sync {
                let loader = BlobMessageLoader()
                loader.start(with: audioMessageEntity, onCompletion: { loadedMessage in
                    let webBlob = WebBlob(audioMessageEntity: loadedMessage as! AudioMessageEntity)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    }
                    else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { _ in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        }
        else {
            let webBlob = WebBlob(audioMessageEntity: audioMessageEntity)
            if webBlob.blob != nil {
                data = webBlob.objectDict()
                ack?.success = true
            }
            else {
                ack?.success = false
                ack?.error = "internalError"
                args?.updateValue(ack?.error, forKey: "error")
            }
            args?.updateValue(ack?.success, forKey: "success")
            completion!()
        }
    }
    
    func addFile(completion: (() -> Void)?) {
        let fileMessageEntity = baseMessage as! FileMessageEntity
        if fileMessageEntity.data == nil {
            DispatchQueue.main.sync {
                let loader = BlobMessageLoader()
                loader.start(with: fileMessageEntity, onCompletion: { loadedMessage in
                    let webBlob = WebBlob(fileMessageEntity: loadedMessage as! FileMessageEntity)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    }
                    else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { _ in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        }
        else {
            let webBlob = WebBlob(fileMessageEntity: fileMessageEntity)
            if webBlob.blob != nil {
                data = webBlob.objectDict()
                ack?.success = true
            }
            else {
                ack?.success = false
                ack?.error = "internalError"
                args?.updateValue(ack?.error, forKey: "error")
            }
            args?.updateValue(ack?.success, forKey: "success")
            completion!()
        }
    }
}
