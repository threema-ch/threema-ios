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

class WebConversationsResponse: WebAbstractMessage {
    
    init(requestId: String?, conversationRequest: WebConversationsRequest?, session: WCSession) {
        
        var conversationArray = Array<[AnyHashable:Any]>();

        let entityManager = EntityManager()
        let allConversations = entityManager.entityFetcher.allConversationsSorted() as? [Conversation]

        var index:Int = 1
        for conver in allConversations! {
            if !conver.isGroup() && conver.contact == nil {
                // empty contact in a single conversation, do not send to web
            } else {
                let webConversation = WebConversation(conversation: conver, index: index, request: conversationRequest, addAvatar: index < 16 ? true : false, entityManager: entityManager, session: session)
                conversationArray.append(webConversation.objectDict())
                index = index + 1
            }
        }
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "conversations", requestId: nil, ack: tmpAck, args: nil, data: conversationArray)
    }
}

struct WebConversation {
    var type: String
    var id: String
    var position: Int
    var messageCount: Int
    var unreadCount: Int
    var latestMessage: [AnyHashable: Any?]?
    var receiver: [AnyHashable: Any?]?
    var avatar: Data?
    var notifications: WebNotificationSettings?
    var isStarred: Bool?
    var isUnread: Bool
    
    init(conversation: Conversation, index: Int, request: WebConversationsRequest?, addAvatar: Bool, entityManager: EntityManager, session: WCSession) {
        if conversation.isGroup() {
            type = "group"
            id = conversation.groupId.hexEncodedString()
            if let groupProxy = GroupProxy.init(for: conversation, entityManager: entityManager) {
                let group = WebGroup.init(group: groupProxy)
                receiver = group.objectDict()
            }
        } else {
            type = "contact"
            id = conversation.contact.identity
            let contact = WebContact.init(conversation.contact)
            receiver = contact.objectDict()
        }

        position = index
        messageCount = conversation.messages.count
        unreadCount = conversation.unreadMessageCount as! Int

        if conversation.lastMessage != nil && conversation.lastMessage.conversation != nil {
            let latestMessageObject = WebMessageObject.init(message: conversation.lastMessage, conversation: conversation, forConversationsRequest: true, session: session)
            latestMessage = latestMessageObject.objectDict()
        }

        let maxSize = request != nil ? request!.maxSize : 48
        let quality = request != nil ? 0.75 : 0.6
        if let avatarImage = AvatarMaker.shared().avatar(for: conversation, size: CGFloat(maxSize), masked: false, scaled: false) {
            avatar = avatarImage.jpegData(compressionQuality:CGFloat(quality))
        }

        if let pushSetting = PushSetting.find(for: conversation) {
            notifications = WebNotificationSettings.init(pushSetting: pushSetting)
        }
        isStarred = conversation.marked.boolValue
        isUnread = conversation.unreadMessageCount == -1
    }

    init(deletedConversation: Conversation, contact: Contact?) {
        if deletedConversation.isGroup() {
            type = "group"
            id = deletedConversation.groupId.hexEncodedString()
        } else {
            type = "contact"
            if deletedConversation.contact != nil {
                id = deletedConversation.contact.identity
            }
            else if contact != nil {
                id = contact!.identity
            }
            else {
                id = ""
            }
        }

        position = 0
        messageCount = 0
        unreadCount = 0
        isUnread = false
    }

    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["type": type, "id": id, "position": position, "messageCount": messageCount, "unreadCount": unreadCount, "isUnread": isUnread]

        if latestMessage != nil {
            objectDict.updateValue(latestMessage!, forKey: "latestMessage")
        }

        if receiver != nil {
            objectDict.updateValue(receiver!, forKey: "receiver")
        }

        if avatar != nil {
            objectDict.updateValue(avatar!, forKey: "avatar")
        }

        if notifications != nil {
            objectDict.updateValue(notifications!.objectDict(), forKey: "notifications")
        }

        if isStarred != nil {
            objectDict.updateValue(isStarred!, forKey: "isStarred")
        }
        
        return objectDict
    }
}

struct WebNotificationSettings {
    var sound: WebNotificationSoundSetting
    var dnd: WebNotificationDndSetting

    init(pushSetting: PushSetting) {
        sound = WebNotificationSoundSetting.init(pushSetting: pushSetting)
        dnd = WebNotificationDndSetting.init(pushSetting: pushSetting)
    }

    func objectDict() -> [String: Any] {
        return ["sound": sound.objectDict(), "dnd": dnd.objectDict()]
    }
}

struct WebNotificationSoundSetting {
    var mode: String

    init(pushSetting: PushSetting) {
        mode = pushSetting.silent ? "muted" : "default"
    }

    func objectDict() -> [String: Any] {
        return ["mode": mode]
    }
}

struct WebNotificationDndSetting {
    var mode: String
    var until: Int
    var mention: Bool

    init(pushSetting: PushSetting) {
        until = 0
        mode = "off"

        if pushSetting.type == .off {
            mode = "on"
        }
        else if pushSetting.type == .offPeriod {
            mode = "until"
            until = Int(pushSetting.periodOffTillDate.timeIntervalSince1970)
        }
        mention = pushSetting.mentions
    }

    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["mode": mode]

        if mode == "until" {
            objectDict.updateValue(until, forKey: "until")
        }

        if mention == true {
            objectDict.updateValue(mention, forKey: "mentionOnly")
        }

        return objectDict
    }
}

extension Data
{
    func toString() -> String
    {
        return String(data: self, encoding: .utf8)!
    }
}
