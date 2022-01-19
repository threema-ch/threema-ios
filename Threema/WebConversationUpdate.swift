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
        case new = "new"
        case modified = "modified"
        case removed = "removed"
    }
    
    var mode: String
    
    init(conversation: Conversation, objectMode: ObjectMode, session: WCSession) {        
        mode = objectMode.rawValue
        
        let entityManager = EntityManager()
        let allConversations = entityManager.entityFetcher.allConversationsSorted() as? [Conversation]
        
        var index:Int = 0
        var found: Bool = false
        for conver in allConversations! {
            if conver.groupId != nil || conversation.groupId != nil {
                if conver.groupId == conversation.groupId {
                    found = true
                }
            } else {
                if conver.contact != nil && conversation.contact != nil {
                    if conver.contact.identity == conversation.contact.identity {
                        found = true
                    }
                }
            }
            
            if found == false {
                index = index + 1
            }
        }
        let webConversation = WebConversation(conversation: conversation, index: index, request: nil, addAvatar: true, entityManager: entityManager, session: session)
        let tmpArgs:[AnyHashable:Any?] = ["mode": mode]
        let tmpData:[AnyHashable:Any?] = ["type": webConversation.type, "id": webConversation.id, "position": webConversation.position, "messageCount": webConversation.messageCount, "unreadCount": webConversation.unreadCount, "latestMessage": webConversation.latestMessage, "notifications": webConversation.notifications?.objectDict(), "isStarred": webConversation.isStarred, "isUnread": webConversation.isUnread]
        
        super.init(messageType: "update", messageSubType: "conversation", requestId: nil, ack: nil, args: tmpArgs, data: tmpData)
    }
    
    init(conversation: Conversation, contact: Contact?, objectMode: ObjectMode) {
        mode = objectMode.rawValue
        
        let webConversation = WebConversation.init(deletedConversation: conversation, contact: contact)
        let tmpArgs:[AnyHashable:Any?] = ["mode": mode]
        let tmpData:[AnyHashable:Any?] = ["type": webConversation.type, "id": webConversation.id, "position": webConversation.position, "messageCount": webConversation.messageCount, "unreadCount": webConversation.unreadCount]
        
        super.init(messageType: "update", messageSubType: "conversation", requestId: nil, ack: nil, args: tmpArgs, data: tmpData)
    }
}
