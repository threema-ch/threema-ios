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

class WebReceiversResponse: WebAbstractMessage {
    
    var contacts: [[AnyHashable: Any]] = [[AnyHashable: Any]]()
    var groups: [Any] = [Any]()
    var distributionList: [Any] = [Any]()
    
    init(requestId: String?, allContacts: [Contact], allGroupConversations: [Conversation]) {
        for c in allContacts {
            let webcontact = WebContact.init(c)
            contacts.append(webcontact.objectDict())
        }
        let entityManager = EntityManager()
        for conversation in allGroupConversations {
            if conversation.isGroup() {
                if let groupProxy = GroupProxy.init(for: conversation, entityManager: entityManager) {
                    let group = WebGroup.init(group: groupProxy)
                    groups.append(group.objectDict())
                }
            }
        }
        
        let tmpData:[AnyHashable:Any?] = ["contact": contacts, "group": groups, "distributionList": distributionList] as [String : Any]
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "receivers", requestId: nil, ack: tmpAck, args: nil, data: tmpData)
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
    var identityType: Int = 0
    var publicKey: Data
    var locked: Bool
    var visible: Bool
    var hidden: Bool
    var isBlocked: Bool = false
    var access: Access
    
    init(_ contact: Contact) {
        id = contact.identity
        displayName = contact.displayName
        color = "#181818"
        firstName = contact.firstName
        lastName = contact.lastName
        publicNickname = contact.publicNickname
        verificationLevel = contact.verificationLevel.intValue + 1 // iOS begins with 0
        state = contact.isActive() ? "ACTIVE" : "INACTIVE"
        if let fM = contact.featureMask() {
            featureMask = Int(truncating: fM)
        } else {
            featureMask = 0
        }

        isWork = contact.workContact == NSNumber.init(value: true)
        if let identity = contact.identity {
            identityType = UserSettings.shared().workIdentities.contains(identity) ? 1 : 0
        }
        
        publicKey = contact.publicKey
        locked = false // only for private chats
        visible = true // only for private chats
        hidden = false // for contacts where are added by group chats
        if let identity = contact.identity {
            isBlocked = UserSettings.shared().blacklist.contains(identity)
        }
        
        let entityManager = EntityManager()
        let groups = entityManager.entityFetcher.groupConversations(for: contact)
        let canDelete = groups?.count == 0 ? true : false
        var canChangeFirstName = true
        var canChangeLastName = true
        
        var canChangeAvatar: Bool = true
        if contact.contactImage != nil && UserSettings.shared().showProfilePictures {
            canChangeAvatar = false
        } else if contact.imageData != nil {
            canChangeAvatar = true
        }
        
        if contact.isGatewayId() {
            canChangeAvatar = false
            canChangeFirstName = false
            canChangeLastName = false
        }
        access = Access.init(canDelete: canDelete, canChangeAvatar: canChangeAvatar, canChangeFirstName: canChangeFirstName, canChangeLastName: canChangeLastName)
        
        // work fix --> set verificationLevel to 2 when verification level is 1 and contact is in same work package
        if isWork == true && verificationLevel == 1 {
            verificationLevel = 2
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["id": id, "displayName": displayName, "featureMask": featureMask, "verificationLevel": verificationLevel, "state": state, "identityType": identityType, "publicKey": publicKey, "locked": locked, "visible": visible, "hidden": hidden, "isBlocked": isBlocked, "access": access.objectDict()]
        
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
        return ["canDelete": canDelete, "canChangeAvatar": canChangeAvatar, "canChangeFirstName": canChangeFirstName, "canChangeLastName": canChangeLastName]
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
    var visible: Bool // only for private chats
    var access: GroupAccess
    
    init(group: GroupProxy) {
        if group.groupId != nil {
            id = group.groupId.hexEncodedString()
        } else {
            id = group.name.replacingOccurrences(of: " ", with: "")
        }
        displayName = group.name
        color = "#181818"
        disabled = false
        if group.activeMemberIds.count > 0 {
            members = group.activeMemberIds.map({ String(describing: $0) })
        } else {
            members = []
        }
        if group.isOwnGroup() {
            administrator = MyIdentityStore.shared().identity
        }
        else if group.creator != nil {
            administrator = group.creator.identity
        }
        else {
            administrator = group.conversation().groupMyIdentity ?? "Unknown"
        }
        locked = false
        visible = true
        access = GroupAccess.init(canDelete: true, canChangeAvatar: group.isOwnGroup(), canChangeName: group.isOwnGroup(), canChangeMembers: group.isOwnGroup(), canLeave: !group.didLeaveGroup(), canSync: group.isOwnGroup())
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["id": id, "displayName": displayName, "members": members, "administrator": administrator, "locked": locked, "visible": visible, "access": access.objectDict()]
        
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
        var objectDict:[String: Any] =  ["canDelete": canDelete, "canChangeAvatar": canChangeAvatar, "canChangeName": canChangeName]
        
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
