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
import ThreemaFramework

class WebDeleteGroupRequest: WebAbstractMessage {
    
    var id: Data? = nil
    let deleteType: String
    
    override init(message:WebAbstractMessage) {

        let idString = message.args!["id"] as! String
        id = idString.hexadecimal()
        deleteType = message.args!["deleteType"] as! String
        super.init(message: message)
    }
    
    func deleteOrLeave() {
        ack = WebAbstractMessageAcknowledgement.init(requestId, false, nil)
        let entityManager = EntityManager()
        let conversation = entityManager.entityFetcher.conversation(forGroupId: id)
        
        if conversation == nil {
            ack!.success = false
            ack!.error = "invalidGroup"
            return;
        }
        
        if conversation!.isGroup() {
            let groupProxy = GroupProxy.init(for: conversation, entityManager: entityManager)
            if groupProxy == nil {
                ack!.success = false
                ack!.error = "invalidGroup"
                return;
            }
            
            if groupProxy!.didLeaveGroup() {
                ack!.success = false
                ack!.error = "alreadyLeft"
                return;
            }
            
            if groupProxy!.isOwnGroup() && deleteType == "delete" {
                groupProxy?.adminDeleteGroup()
            }
            
            MessageDraftStore.deleteDraft(for: conversation)
            
            ack!.success = true
            
            if deleteType == "delete" {
                entityManager.performSyncBlockAndSafe({
                    entityManager.entityDestroyer.deleteObject(object: conversation!)
                })
                
                DispatchQueue.main.async {
                    NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                    
                    let info = [kKeyConversation: conversation!]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationDeletedConversation), object: nil, userInfo: info)
                }
            }
            else if deleteType == "leave" {
                groupProxy?.leaveGroup()
            }
            else {
                ack!.success = false
                ack!.error = "badRequest"
                return;
            }
        } else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return;
        }
    }
    
    
}
