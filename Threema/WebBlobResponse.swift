//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class WebBlobResponse: WebAbstractMessage {
    
    var id: String
    var messageId: String
    var type: String
    
    var baseMessage: BaseMessage
    
    init(request: WebBlobRequest, imageMessage: ImageMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        baseMessage = imageMessage
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, false, nil)
        
        super.init(messageType: "response", messageSubType: "blob", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
    }
    
    init(request: WebBlobRequest, videoMessage: VideoMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        baseMessage = videoMessage
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, false, nil)
        
        super.init(messageType: "response", messageSubType: "blob", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
    }
    
    init(request: WebBlobRequest, audioMessage: AudioMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        baseMessage = audioMessage
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, false, nil)
        
        super.init(messageType: "response", messageSubType: "blob", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
    }
    
    init(request: WebBlobRequest, fileMessage: FileMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        baseMessage = fileMessage
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, false, nil)
        
        super.init(messageType: "response", messageSubType: "blob", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
    }
    
    func addImage(completion: (()->())?) {
        let imageMessage = baseMessage as! ImageMessage
        if imageMessage.image == nil {
            let loader = ImageMessageLoader.init()
            DispatchQueue.main.sync {
                loader.start(with: imageMessage, onCompletion: { (loadedMessage) in
                    let webBlob = WebBlob.init(imageMessage: loadedMessage as! ImageMessage)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    } else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { (theError) in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        } else {
            let webBlob = WebBlob.init(imageMessage: imageMessage)
            if webBlob.blob != nil {
                self.data = webBlob.objectDict()
                self.ack?.success = true
            } else {
                self.ack?.success = false
                self.ack?.error = "internalError"
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            self.args?.updateValue(self.ack?.success, forKey: "success")
            completion!()
        }
    }
    
    func addVideo(completion: (()->())?) {
        DispatchQueue.main.sync {
            let videoMessage = self.baseMessage as! VideoMessage
            if videoMessage.video == nil {
                let loader = VideoMessageLoader.init()
                
                loader.start(with: videoMessage, onCompletion: { (loadedMessage) in
                    let webBlob = WebBlob.init(videoMessage: loadedMessage as! VideoMessage)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    } else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                    
                }, onError: { (theError) in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            } else {
                let webBlob = WebBlob.init(videoMessage: videoMessage)
                if webBlob.blob != nil {
                    self.data = webBlob.objectDict()
                    self.ack?.success = true
                } else {
                    self.ack?.success = false
                    self.ack?.error = "internalError"
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                }
                self.args?.updateValue(self.ack?.success, forKey: "success")
                completion!()
            }
        }
    }
    
    func addAudio(completion: (()->())?) {
        let audioMessage = baseMessage as! AudioMessage
        if audioMessage.audio == nil {
            DispatchQueue.main.sync {
                let loader = BlobMessageLoader.init()
                loader.start(with: audioMessage, onCompletion: { (loadedMessage) in
                    let webBlob = WebBlob.init(audioMessage: loadedMessage as! AudioMessage)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    } else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { (theError) in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        } else {
            let webBlob = WebBlob.init(audioMessage: audioMessage)
            if webBlob.blob != nil {
                self.data = webBlob.objectDict()
                self.ack?.success = true
            } else {
                self.ack?.success = false
                self.ack?.error = "internalError"
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            self.args?.updateValue(self.ack?.success, forKey: "success")
            completion!()
        }
    }
    
    func addFile(completion: (()->())?) {
        let fileMessage = baseMessage as! FileMessage
        if fileMessage.data == nil {
            DispatchQueue.main.sync {
                let loader = BlobMessageLoader.init()
                loader.start(with: fileMessage, onCompletion: { (loadedMessage) in
                    let webBlob = WebBlob.init(fileMessage: loadedMessage as! FileMessage)
                    if webBlob.blob != nil {
                        self.data = webBlob.objectDict()
                        self.ack?.success = true
                    } else {
                        self.ack?.success = false
                        self.ack?.error = "internalError"
                        self.args?.updateValue(self.ack?.error, forKey: "error")
                    }
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    completion!()
                }, onError: { (theError) in
                    self.ack?.success = false
                    self.ack?.error = "blobDownloadFailed"
                    self.args?.updateValue(self.ack?.success, forKey: "success")
                    self.args?.updateValue(self.ack?.error, forKey: "error")
                    completion!()
                })
            }
        } else {
            let webBlob = WebBlob.init(fileMessage: fileMessage)
            if webBlob.blob != nil {
                self.data = webBlob.objectDict()
                self.ack?.success = true
            } else {
                self.ack?.success = false
                self.ack?.error = "internalError"
                self.args?.updateValue(self.ack?.error, forKey: "error")
            }
            self.args?.updateValue(self.ack?.success, forKey: "success")
            completion!()
        }
    }
}

