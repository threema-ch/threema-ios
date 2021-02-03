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

class WebThumbnailResponse: WebAbstractMessage {
    
    var id: String
    var messageId: String
    var type: String
    var message: BaseMessage?
    
    init(request: WebThumbnailRequest, imageMessage: BaseMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail.init(imageMessage: imageMessage as! ImageMessage, onlyThumbnail: false)
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = request.requestId != nil ? WebAbstractMessageAcknowledgement.init(request.requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "thumbnail", requestId: nil, ack: tmpAck, args: tmpArgs, data: webThumbnail.image)
    }
    
    init(request: WebThumbnailRequest, videoMessage: BaseMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail.init(videoMessage as! VideoMessage, onlyThumbnail: false)
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = request.requestId != nil ? WebAbstractMessageAcknowledgement.init(request.requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "thumbnail", requestId: nil, ack: tmpAck, args: tmpArgs, data: webThumbnail.image)
    }
    
    init(request: WebThumbnailRequest, fileMessage: BaseMessage) {
        id = request.id
        type = request.type
        messageId = request.messageId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let webThumbnail = WebThumbnail.init(fileMessage as! FileMessage, onlyThumbnail: false)
        
        let tmpArgs:[AnyHashable:Any?] = ["id": id, "messageId": messageId, "type": type]
        let tmpAck = request.requestId != nil ? WebAbstractMessageAcknowledgement.init(request.requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "thumbnail", requestId: nil, ack: tmpAck, args: tmpArgs, data: webThumbnail.image)
    }
}

