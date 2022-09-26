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

class WebConversationUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new
        case modified
        case removed
    }
    
    var mode: String
    
    init(conversation: Conversation, objectMode: ObjectMode, session: WCSession) {
        self.mode = objectMode.rawValue
        
        let entityManager = EntityManager()
        let allConversations = entityManager.entityFetcher.allConversationsSorted() as? [Conversation]
        
        var index = 0
        var found = false
        for conver in allConversations! {
            if conver.groupID != nil || conversation.groupID != nil {
                if conver.groupID == conversation.groupID {
                    found = true
                }
            }
            else if let converContact = conver.contact, let conversationContact = conversation.contact {
                if converContact.identity == conversationContact.identity {
                    found = true
                }
            }
            
            if found == false {
                index = index + 1
            }
        }
        let webConversation = WebConversation(
            conversation: conversation,
            index: index,
            request: nil,
            addAvatar: true,
            groupManager: GroupManager(entityManager: entityManager),
            session: session
        )
        let tmpArgs: [AnyHashable: Any?] = ["mode": mode]
        let tmpData: [AnyHashable: Any?] = [
            "type": webConversation.type,
            "id": webConversation.id,
            "position": webConversation.position,
            "messageCount": webConversation.messageCount,
            "unreadCount": max(0, webConversation.unreadCount),
            "latestMessage": webConversation.latestMessage,
            "notifications": webConversation.notifications?.objectDict(),
            "isStarred": webConversation.isStarred,
            "isUnread": webConversation.isUnread,
        ]
        
        super.init(
            messageType: "update",
            messageSubType: "conversation",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    init(conversation: Conversation, contact: Contact?, objectMode: ObjectMode) {
        self.mode = objectMode.rawValue
        
        let webConversation = WebConversation(deletedConversation: conversation, contact: contact)
        let tmpArgs: [AnyHashable: Any?] = ["mode": mode]
        let tmpData: [AnyHashable: Any?] = [
            "type": webConversation.type,
            "id": webConversation.id,
            "position": webConversation.position,
            "messageCount": webConversation.messageCount,
            "unreadCount": webConversation.unreadCount,
        ]
        
        super.init(
            messageType: "update",
            messageSubType: "conversation",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
}
