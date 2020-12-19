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

class WebUpdateGroupRequest: WebAbstractMessage {
    
    let id: Data
    
    var members: [String]
    var name: String?
    var avatar: Data?
    
    var deleteName: Bool = false
    var deleteAvatar: Bool = false
    
    var groupProxy: GroupProxy?
    
    override init(message:WebAbstractMessage) {
        let idString = message.args!["id"] as! String
        id = idString.hexadecimal()!
        
        let data = message.data as! [AnyHashable: Any?]
        members = data["members"] as! [String]
        name = data["name"] as? String
        avatar = data["avatar"] as? Data
        
        if data["name"] != nil {
            if name == nil {
                deleteName = true
            }
        }
        
        if data["avatar"] != nil {
            if avatar == nil {
                deleteAvatar = true
            } else {
                let image = UIImage.init(data: avatar!)
                if image!.size.width >= CGFloat(kContactImageSize) || image!.size.height >= CGFloat(kContactImageSize) {
                    avatar = MediaConverter.scaleImageData(to: avatar!, toMaxSize: CGFloat(kContactImageSize), useJPEG: false)
                }
            }
        }
        super.init(message: message)
    }
    
    func updateGroup(completion: @escaping () -> ()) {
        ack = WebAbstractMessageAcknowledgement.init(requestId, false, nil)
        DispatchQueue.main.sync {
            let entityManager = EntityManager()
            let conversation = entityManager.entityFetcher.conversation(forGroupId: id)
            
            if conversation == nil {
                ack!.success = false
                ack!.error = "invalidGroup"
                completion()
                return
            }
            
            let groupProxy = GroupProxy.init(for: conversation, entityManager: entityManager)
            
            if groupProxy == nil {
                ack!.success = false
                ack!.error = "invalidGroup"
                completion()
                return
            }
            
            self.groupProxy = groupProxy
            
            if members.count == 0 {
                ack!.success = false
                ack!.error = "noMembers"
                completion()
                return
            }
            
            if !groupProxy!.isOwnGroup() {
                ack!.success = false
                ack!.error = "notAllowed"
                completion()
                return
            }
            
            if self.name != nil {
                if self.name!.lengthOfBytes(using: .utf8) > 256 {
                    self.ack!.success = false
                    self.ack!.error = "valueTooLong"
                    completion()
                    return
                }
            }
            
            var newMembers = Set<Contact>()
            for identity in members {
                if let contact = ContactStore.shared().contact(forIdentity: identity) {
                    newMembers.insert(contact)
                }
            }
            
            let existingMembers = groupProxy!.members as! Set<Contact>
            for member:Contact in existingMembers {
                if !newMembers.contains(member) {
                    groupProxy!.adminRemoveMember(member)
                }
            }
            
            for member:Contact in newMembers {
                if !groupProxy!.members.contains(member) {
                    groupProxy!.adminAddMember(member)
                }
            }
            
            
            if ( self.deleteName || self.name != nil ) && ( !deleteAvatar && avatar == nil ) {
                entityManager.performSyncBlockAndSafe({
                    if self.deleteName || self.name != nil {
                        conversation?.groupName = self.name
                    }
                })
                
                if self.deleteName || self.name != nil {
                    DispatchQueue.main.async {
                        MessageSender.sendGroupRenameMessage(for: conversation, addSystemMessage: true)
                    }
                }
                self.ack!.success = true
                completion()
                return
            } else {
                let sender = GroupPhotoSender.init()
                sender.start(withImageData: self.avatar, in: conversation, toMember: nil, onCompletion: {
                    entityManager.performSyncBlockAndSafe({
                        if self.deleteName || self.name != nil {
                            conversation?.groupName = self.name
                        }
                        
                        if conversation?.groupImage != nil {
                            entityManager.entityDestroyer.deleteObject(object: conversation!.groupImage!)
                            conversation?.groupImage = nil
                        }
                        
                        let dbImage = entityManager.entityCreator.imageData()
                        dbImage?.data = self.avatar
                        conversation?.groupImage = dbImage
                    })
                    if self.deleteName || self.name != nil {
                        DispatchQueue.main.async {
                            MessageSender.sendGroupRenameMessage(for: conversation, addSystemMessage: true)
                        }
                    }
                    self.ack!.success = true
                    completion()
                    return
                }, onError: { (theError) in
                    self.ack!.success = false
                    self.ack!.error = "internalError"
                    completion()
                    return
                })
            }
        }
    }
}
