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

class WebMessagesUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new = "new"
        case modified = "modified"
        case removed = "removed"
    }
    
    var type: String
    var id: String
    var mode: String
    
    var message: [AnyHashable:Any]
    
    init(_ requestId: String? = nil, baseMessage: BaseMessage, conversation: Conversation, objectMode: ObjectMode, session: WCSession) {
        
        if conversation.isGroup() {
            type = "group"
            id = conversation.groupId.hexEncodedString()
        } else {
            type = "contact"
            if baseMessage.sender != nil {
                id = baseMessage.sender.identity
            } else {
                if conversation.contact != nil {
                    id = conversation.contact.identity
                }
                else {
                    id = MyIdentityStore.shared().identity
                }
            }
        }
            
        mode = objectMode.rawValue
        
        if objectMode == .removed {
            let messageObject = WebMessageObject.init(message: baseMessage, conversation:conversation)
            message = messageObject.removedObjectDict()
        } else {
            let messageObject = WebMessageObject.init(message: baseMessage, conversation: conversation, forConversationsRequest: false, session: session)
            message = messageObject.objectDict()
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id, "mode": mode]
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "update", messageSubType: "messages", requestId: nil, ack: tmpAck, args: tmpArgs, data: [message])
    }
}
