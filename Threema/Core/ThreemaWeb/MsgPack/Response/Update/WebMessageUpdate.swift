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

class WebMessagesUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new
        case modified
        case removed
    }
    
    var type: String
    var id: String
    var mode: String
    
    var message: [AnyHashable: Any]
    
    init(
        _ requestID: String? = nil,
        baseMessage: BaseMessageEntity,
        conversation: ConversationEntity,
        objectMode: ObjectMode,
        session: WCSession
    ) {
        
        if conversation.isGroup, let groupID = conversation.groupID {
            self.type = "group"
            self.id = groupID.hexEncodedString()
        }
        else {
            self.type = "contact"
            if let sender = baseMessage.sender {
                self.id = sender.identity
            }
            else {
                if let contact = conversation.contact {
                    self.id = contact.identity
                }
                else {
                    self.id = MyIdentityStore.shared().identity
                }
            }
        }
        
        self.mode = objectMode.rawValue
        
        if objectMode == .removed || baseMessage.deletedAt != nil {
            let messageObject = WebMessageObject(message: baseMessage, conversation: conversation)
            self.message = messageObject.removedObjectDict()
        }
        else {
            let messageObject = WebMessageObject(
                message: baseMessage,
                conversation: conversation,
                forConversationsRequest: false,
                session: session
            )
            self.message = messageObject.objectDict()
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id, "mode": mode]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "update",
            messageSubType: "messages",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: [message]
        )
    }
}
