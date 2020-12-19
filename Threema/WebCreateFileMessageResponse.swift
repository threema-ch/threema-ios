//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class WebCreateFileMessageResponse: WebAbstractMessage {
    
    var message: BaseMessage?
    var type: String
    var id: String
    var messageId: String?
    
    init(message:BaseMessage, request: WebCreateFileMessageRequest) {
        self.message = message
        type = request.type
        if request.groupId != nil {
            id = request.groupId!.hexEncodedString()
        } else {
            id = request.id!
        }
        
        messageId = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id]
        let tmpData:[AnyHashable:Any?] = ["messageId": messageId!] as [String : Any]
        
        super.init(messageType: "create", messageSubType: "fileMessage", requestId: nil, ack: request.ack, args: tmpArgs, data: tmpData)
    }
    
    init(request: WebCreateFileMessageRequest) {
        type = request.type
        if request.groupId != nil {
            id = request.groupId!.hexEncodedString()
        } else {
            id = request.id!
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id]
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, false, nil)
        
        super.init(messageType: "create", messageSubType: "fileMessage", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
    }
}
