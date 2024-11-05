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

import Foundation

class WebUpdateActiveConversationRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
            
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as? String
            self.groupID = idString?.hexadecimal
        }
                
        super.init(message: message)
    }
    
    func updateActiveConversation() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        
        DispatchQueue.main.sync {
            let entityManager = EntityManager()
            
            if groupID != nil {
                let conversation = entityManager.entityFetcher.legacyConversation(for: groupID)
                
                entityManager.performSyncBlockAndSafe {
                    if conversation?.unreadMessageCount == -1 {
                        conversation!.unreadMessageCount = 0
                    }
                }
            }
            else if identity != nil {
                let conversation = entityManager.entityFetcher.conversationEntity(forIdentity: identity!)
                entityManager.performAndWaitSave {
                    if conversation?.unreadMessageCount == -1 {
                        conversation!.unreadMessageCount = 0
                    }
                }
            }
            
            let notificationManager = NotificationManager()
            notificationManager.updateUnreadMessagesCount()
            
            self.ack!.success = true
        }
    }
}
