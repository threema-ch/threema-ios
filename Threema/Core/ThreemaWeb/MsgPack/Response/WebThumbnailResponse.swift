//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

class WebThumbnailResponse: WebAbstractMessage {
    
    var id: String
    var messageID: String
    var type: String
    var message: BaseMessage?
    
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
