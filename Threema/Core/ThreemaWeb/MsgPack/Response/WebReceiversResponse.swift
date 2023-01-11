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

import CocoaLumberjackSwift
import Foundation

class WebReceiversResponse: WebAbstractMessage {
    
    var contacts = [[AnyHashable: Any]]()
    var groups = [Any]()
    var distributionList = [Any]()
    
    init(requestID: String?, allContacts: [Contact], allGroupConversations: [Conversation]) {
        for c in allContacts {
            let webcontact = WebContact(c)
            contacts.append(webcontact.objectDict())
        }
        let groupManager = GroupManager()
        for conversation in allGroupConversations {
            if let group = groupManager.getGroup(conversation: conversation) {
                let webGroup = WebGroup(group: group)
                groups.append(webGroup.objectDict())
            }
        }
        
        let tmpData: [AnyHashable: Any?] = [
            "contact": contacts,
            "group": groups,
            "distributionList": distributionList,
        ] as [String: Any]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "receivers",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: tmpData
        )
    }
}

struct WebContact {
    var id: String
    var displayName: String
    var color: String? // not available in iOS
    var firstName: String?
    var lastName: String?
    var publicNickname: String?
    var verificationLevel: Int
    var state: String
    var featureMask: Int
    var isWork: Bool?
    var identityType = 0
    var publicKey: Data
    var locked: Bool
    var visible: Bool
    var hidden: Bool
    var isBlocked = false
    var access: Access
    
    init(_ contact: Contact) {
        self.id = contact.identity
        self.displayName = contact.displayName
        self.color = "#181818"
        self.firstName = contact.firstName
        self.lastName = contact.lastName
        self.publicNickname = contact.publicNickname
        self.verificationLevel = contact.verificationLevel.intValue + 1 // iOS begins with 0
        self.state = contact.isActive() ? "ACTIVE" : "INACTIVE"
        self.featureMask = contact.featureMask.intValue

        self.isWork = contact.workContact == NSNumber(value: true)
        self.identityType = UserSettings.shared().workIdentities.contains(contact.identity) ? 1 : 0
        
        if let conversation = EntityManager().entityFetcher.conversation(for: contact) {
            self.locked = conversation.conversationCategory == .private
            self
                .visible = !(UserSettings.shared().hidePrivateChats && conversation.conversationCategory == .private) &&
                conversation.conversationVisibility != .archived
        }
        else {
            self.locked = false
            self.visible = true
        }
        
        self.publicKey = contact.publicKey
        self.hidden = false // for contacts where are added by group chats
        
        self.isBlocked = UserSettings.shared().blacklist.contains(contact.identity)
        
        let entityManager = EntityManager()
        let groups = entityManager.entityFetcher.groupConversations(for: contact)
        let canDelete = groups?.count == 0 ? true : false
        var canChangeFirstName = true
        var canChangeLastName = true
        
        var canChangeAvatar = true
        if contact.contactImage != nil, UserSettings.shared().showProfilePictures {
            canChangeAvatar = false
        }
        else if contact.imageData != nil {
            canChangeAvatar = true
        }
        
        if contact.isGatewayID() {
            canChangeAvatar = false
            canChangeFirstName = false
            canChangeLastName = false
        }
        self.access = Access(
            canDelete: canDelete,
            canChangeAvatar: canChangeAvatar,
            canChangeFirstName: canChangeFirstName,
            canChangeLastName: canChangeLastName
        )
        
        // work fix --> set verificationLevel to 2 when verification level is 1 and contact is in same work package
        if isWork == true, verificationLevel == 1 {
            self.verificationLevel = 2
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "featureMask": featureMask,
            "verificationLevel": verificationLevel,
            "state": state,
            "identityType": identityType,
            "publicKey": publicKey,
            "locked": locked,
            "visible": visible,
            "hidden": hidden,
            "isBlocked": isBlocked,
            "access": access.objectDict(),
        ]
        
        if firstName != nil {
            objectDict.updateValue(firstName!, forKey: "firstName")
        }
        
        if lastName != nil {
            objectDict.updateValue(lastName!, forKey: "lastName")
        }
        
        if publicNickname != nil {
            objectDict.updateValue(publicNickname!, forKey: "publicNickname")
        }
        
        if isWork != nil {
            objectDict.updateValue(isWork!, forKey: "isWork")
        }
        
        if color != nil {
            objectDict.updateValue(color!, forKey: "color")
        }
        return objectDict
    }
}

struct Access {
    var canDelete: Bool
    var canChangeAvatar: Bool
    var canChangeFirstName: Bool
    var canChangeLastName: Bool
    
    func objectDict() -> [String: Any] {
        [
            "canDelete": canDelete,
            "canChangeAvatar": canChangeAvatar,
            "canChangeFirstName": canChangeFirstName,
            "canChangeLastName": canChangeLastName,
        ]
    }
}

struct WebGroup {
    var id: String
    var displayName: String
    var color: String? // not available in iOS
    var disabled: Bool?
    var members: [String]
    var administrator: String
    var createdAt: String?
    var locked: Bool // only for private chats
    var visible: Bool // for private and archived chats
    var access: GroupAccess
    
    init(group: Group) {
        self.id = group.groupID.hexEncodedString()
        self.displayName = group.name ?? ""
        self.color = "#181818"
        self.disabled = false
        self.members = group.members.filter { member -> Bool in
            member.state ?? NSNumber(value: kStateInvalid) != NSNumber(value: kStateInvalid)
        }.map(\.identity)
        // Add myself to members list if isSelfMember
        if group.isSelfMember {
            members.append(MyIdentityStore.shared().identity)
        }
        if group.isOwnGroup {
            self.administrator = MyIdentityStore.shared().identity
        }
        else {
            self.administrator = group.groupCreatorIdentity
        }
        self.locked = group.conversationCategory == .private
        self.visible = !(UserSettings.shared().hidePrivateChats && group.conversationCategory == .private) && group
            .conversationVisibility != .archived
        self.access = GroupAccess(
            canDelete: true,
            canChangeAvatar: group.isOwnGroup,
            canChangeName: group.isOwnGroup,
            canChangeMembers: group.isOwnGroup,
            canLeave: !group.isSelfCreator && !group.didLeave,
            canSync: group.isOwnGroup
        )
    }
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "members": members,
            "administrator": administrator,
            "locked": locked,
            "visible": visible,
            "access": access.objectDict(),
        ]
        
        if disabled != nil {
            objectDict.updateValue(disabled!, forKey: "disabled")
        }
        
        if createdAt != nil {
            objectDict.updateValue(createdAt!, forKey: "createdAt")
        }
        
        if color != nil {
            objectDict.updateValue(color!, forKey: "color")
        }
        
        return objectDict
    }
}

struct GroupAccess {
    var canDelete: Bool
    var canChangeAvatar: Bool
    var canChangeName: Bool
    var canChangeMembers: Bool?
    var canLeave: Bool?
    var canSync: Bool?
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = [
            "canDelete": canDelete,
            "canChangeAvatar": canChangeAvatar,
            "canChangeName": canChangeName,
        ]
        
        if canChangeMembers != nil {
            objectDict.updateValue(canChangeMembers!, forKey: "canChangeMembers")
        }
        
        if canLeave != nil {
            objectDict.updateValue(canLeave!, forKey: "canLeave")
        }
        
        if canSync != nil {
            objectDict.updateValue(canSync!, forKey: "canSync")
        }
        return objectDict
    }
}
