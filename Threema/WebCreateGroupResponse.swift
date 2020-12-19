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
import ThreemaFramework

class WebCreateGroupResponse: WebAbstractMessage {
    
    var groupRequest: WebCreateGroupRequest
    
    init(request: WebCreateGroupRequest) {
        groupRequest = request
        let tmpAck = WebAbstractMessageAcknowledgement.init(request.requestId, true, nil)
        
        super.init(messageType: "create", messageSubType: "group", requestId: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addGroup(completion: @escaping () -> ()) {
        let mdmSetup = MDMSetup(setup: false)!
        if mdmSetup.disableCreateGroup() {
            self.ack!.success = false
            self.ack!.error = "disabledByPolicy"
            self.args = nil
            self.data = nil
            completion()
            return
        }
        var conversation: Conversation?
        var entityManager: EntityManager?
        DispatchQueue.main.sync {
            entityManager = EntityManager()
            entityManager?.performSyncBlockAndSafe({
                conversation = entityManager?.entityCreator.conversation()
                conversation?.groupId = NaClCrypto.shared().randomBytes(kGroupIdLen)
                conversation?.groupMyIdentity = MyIdentityStore.shared().identity
                conversation?.groupName = self.groupRequest.name
                
                for identity in self.groupRequest.members {
                    let contact = ContactStore.shared().contact(forIdentity: identity)
                    conversation?.addMembersObject(contact)
                }
                
                if self.groupRequest.avatar != nil {
                    let dbImage = entityManager?.entityCreator.imageData()
                    dbImage?.data = self.groupRequest.avatar
                    conversation?.groupImage = dbImage
                }
            })
        }
        
        var groupProxy: GroupProxy? = nil
        /* send group create messages to all members */
        if (conversation?.isGroup())! {
            DispatchQueue.main.sync {
                groupProxy = GroupProxy.init(for: conversation!, entityManager: entityManager)
            }
            groupProxy?.syncGroupInfoToAll()
        }
        
        if groupRequest.name != nil {
            MessageSender.sendGroupRenameMessage(for: conversation, addSystemMessage: true)
        }
        
        if groupRequest.avatar != nil {
            sendGroupPhotoMessage(conversation: conversation!)
        }
        
        self.ack!.success = true
        self.args = nil
        let webGroup = WebGroup.init(group: groupProxy!)
        self.data = ["receiver": webGroup.objectDict()]
        completion()
        return
    }
    
    func sendGroupPhotoMessage(conversation: Conversation) {
        let sender = GroupPhotoSender.init()
        sender.start(withImageData: groupRequest.avatar, in: conversation, toMember: nil, onCompletion: {
            // do nothing
        }) { (theError) in
            // do nothing
        }
    }
}
