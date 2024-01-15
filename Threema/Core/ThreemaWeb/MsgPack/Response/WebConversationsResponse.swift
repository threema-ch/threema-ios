//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

class WebConversationsResponse: WebAbstractMessage {
    
    init(requestID: String?, conversationRequest: WebConversationsRequest?, session: WCSession) {
        
        var conversationArray = [[AnyHashable: Any]]()

        let businessInjector = BusinessInjector()
        let allConversations = businessInjector.entityManager.entityFetcher.allConversationsSorted() as? [Conversation]

        let unarchivedConversations = allConversations?
            .filter { $0.conversationVisibility == .default || $0.conversationVisibility == .pinned }
        let archivedConversations = allConversations?.filter { $0.conversationVisibility == .archived }
        
        var index = 1
        for conver in unarchivedConversations! {
            if !conver.isGroup(), conver.contact == nil {
                // empty contact in a single conversation, do not send to web
            }
            else {
                let webConversation = WebConversation(
                    conversation: conver,
                    index: index,
                    request: conversationRequest,
                    addAvatar: index < 16 ? true : false,
                    businessInjector: businessInjector,
                    session: session
                )
                conversationArray.append(webConversation.objectDict())
                index = index + 1
            }
        }
        for conver in archivedConversations! {
            if !conver.isGroup(), conver.contact == nil {
                // empty contact in a single conversation, do not send to web
            }
            else {
                let webConversation = WebConversation(
                    conversation: conver,
                    index: index,
                    request: conversationRequest,
                    addAvatar: index < 16 ? true : false,
                    businessInjector: businessInjector,
                    session: session
                )
                conversationArray.append(webConversation.objectDict())
                index = index + 1
            }
        }
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "conversations",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: conversationArray
        )
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
    
    init(
        conversation: Conversation,
        index: Int,
        request: WebConversationsRequest?,
        addAvatar: Bool,
        businessInjector: BusinessInjectorProtocol,
        session: WCSession
    ) {
        if conversation.isGroup() {
            self.type = "group"
            self.id = conversation.groupID!.hexEncodedString()
            if let group = businessInjector.groupManager.getGroup(conversation: conversation) {
                let webGroup = WebGroup(group: group)
                self.receiver = webGroup.objectDict()
            }
        }
        else {
            self.type = "contact"
            self.id = conversation.contact!.identity
            let contact = WebContact(conversation.contact!)
            self.receiver = contact.objectDict()
        }

        self.position = index
        
        let messageFetcher = MessageFetcher(for: conversation, with: businessInjector.entityManager)
        self.messageCount = messageFetcher.count()
        
        self.unreadCount = max(0, conversation.unreadMessageCount as! Int)

        if let lastMessage = conversation.lastMessage, lastMessage.conversation != nil {
            // This is a workaround for an issue that was introduced with IOS-3233 / IOS-3212
            // We would previously only ever set lastMessage on conversation for file messages after fileName was set.
            // With the new changes we first create the base message, set lastMessage on conversation and then decode
            // the file message (setting fileName).
            // These changes caused a crash when using web client because we force unwrap `fileName`, `fileSize` and
            // `mimeType` when creating a `WebFile` struct.
            // As we're sunsetting the web client we just avoid the crash (the message will be updated later anyways so
            // the user impact is low) instead of fixing it properly.
            if !lastMessage.isKind(of: FileMessageEntity.self) || (
                (lastMessage as? FileMessageEntity)?.fileName != nil
                    && (lastMessage as? FileMessageEntity)?
                    .fileSize != nil
                    && (lastMessage as? FileMessageEntity)?
                    .mimeType != nil
            ) {
                let latestMessageObject = WebMessageObject(
                    message: lastMessage,
                    conversation: conversation,
                    forConversationsRequest: true,
                    session: session
                )
                self.latestMessage = latestMessageObject.objectDict()
            }
        }
        
        if addAvatar {
            let maxSize = request != nil ? request!.maxSize : 48
            let quality = request != nil ? 0.75 : 0.6
            if let avatarImage = AvatarMaker.shared()
                .avatar(for: conversation, size: CGFloat(maxSize), masked: false, scaled: false) {
                self.avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
            }
        }

        var pushSetting: PushSetting
        if let group = businessInjector.groupManager.getGroup(conversation: conversation) {
            pushSetting = businessInjector.pushSettingManager.find(forGroup: group.groupIdentity)
        }
        else if let contactEntity = conversation.contact {
            pushSetting = businessInjector.pushSettingManager.find(forContact: contactEntity.threemaIdentity)
        }
        else {
            fatalError("No push settings for conversation found")
        }

        self.notifications = WebNotificationSettings(pushSetting: pushSetting)
        
        self.isStarred = conversation.conversationVisibility == .pinned
        self.isUnread = conversation.unreadMessageCount == -1
    }

    init(deletedConversation: Conversation, contact: ContactEntity?) {
        if deletedConversation.isGroup(),
           let groupID = deletedConversation.groupID {
            self.type = "group"
            self.id = groupID.hexEncodedString()
        }
        else {
            self.type = "contact"
            if let deletedConversationContact = deletedConversation.contact {
                self.id = deletedConversationContact.identity
            }
            else if contact != nil {
                self.id = contact!.identity
            }
            else {
                self.id = ""
            }
        }

        self.position = 0
        self.messageCount = 0
        self.unreadCount = 0
        self.isUnread = false
    }

    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = [
            "type": type,
            "id": id,
            "position": position,
            "messageCount": messageCount,
            "unreadCount": unreadCount,
            "isUnread": isUnread,
        ]

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
        self.sound = WebNotificationSoundSetting(pushSetting: pushSetting)
        self.dnd = WebNotificationDndSetting(pushSetting: pushSetting)
    }

    func objectDict() -> [String: Any] {
        ["sound": sound.objectDict(), "dnd": dnd.objectDict()]
    }
}

struct WebNotificationSoundSetting {
    var mode: String

    init(pushSetting: PushSetting) {
        self.mode = pushSetting.muted ? "muted" : "default"
    }

    func objectDict() -> [String: Any] {
        ["mode": mode]
    }
}

struct WebNotificationDndSetting {
    var mode: String
    var until: Int
    var mention: Bool

    init(pushSetting: PushSetting) {
        self.until = 0
        self.mode = "off"

        var setting = pushSetting
        if setting.type == .off {
            self.mode = "on"
        }
        else if setting.type == .offPeriod {
            self.mode = "until"
            self.until = Int(pushSetting.periodOffTillDate?.timeIntervalSince1970 ?? 0)
        }
        self.mention = pushSetting.mentioned
    }

    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = ["mode": mode]

        if mode == "until" {
            objectDict.updateValue(until, forKey: "until")
        }

        if mention == true {
            objectDict.updateValue(mention, forKey: "mentionOnly")
        }

        return objectDict
    }
}

extension Data {
    func toString() -> String {
        String(data: self, encoding: .utf8)!
    }
}
