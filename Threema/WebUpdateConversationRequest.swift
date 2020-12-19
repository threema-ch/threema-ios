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

class WebUpdateConversationRequest: WebAbstractMessage {
    
    let type: String
    var identity: String? = nil
    var groupId: Data? = nil
    
    var isStarred: Bool? = nil
        
    override init(message:WebAbstractMessage) {
        type = message.args!["type"] as! String
        
        if type == "contact" {
            identity = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as? String
            groupId = idString?.hexadecimal()
        }
        
        if let data = message.data as? [AnyHashable: Any] {
            isStarred = data["isStarred"] as? Bool
        }
        
        super.init(message: message)
    }
    
    func updateConversation() {
        ack = WebAbstractMessageAcknowledgement.init(requestId, false, nil)
        DispatchQueue.main.sync {
            let entityManager = EntityManager()
            
            if groupId != nil {
                let conversation = entityManager.entityFetcher.conversation(forGroupId: groupId)
                
                if conversation == nil {
                    ack!.success = false
                    ack!.error = "invalidConversation"
                    return
                }
                
                if isStarred == nil {
                    ack!.success = false
                    ack!.error = "badRequest"
                    return
                }
                
                entityManager.performSyncBlockAndSafe({
                    conversation!.marked = NSNumber.init(value: self.isStarred!)
                })
                
                self.ack!.success = true
            }
            else if identity != nil {
                let conversation = entityManager.entityFetcher.conversation(forIdentity: identity!)
                if conversation == nil {
                    ack!.success = false
                    ack!.error = "invalidConversation"
                    return
                }
                
                if isStarred == nil {
                    ack!.success = false
                    ack!.error = "badRequest"
                    return
                }
                
                entityManager.performSyncBlockAndSafe({
                    conversation!.marked = NSNumber.init(value: self.isStarred!)
                })
                
                self.ack!.success = true
            } else {
                ack!.success = false
                ack!.error = "badRequest"
                return
            }
        }
    }
}
