//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

class WebDeleteMessageRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
    var conversation: ConversationEntity?
    
    let messageID: Data
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal
        }
        
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        super.init(message: message)
        
        let entityManager = EntityManager()
        if let identity {
            entityManager.performAndWait {
                self.conversation = entityManager.entityFetcher.conversationEntity(forIdentity: identity)
            }
        }
        else if let groupID {
            entityManager.performAndWait {
                self.conversation = entityManager.entityFetcher.legacyConversation(for: groupID)
            }
        }
        else {
            DDLogError("Neither identity nor groupID were set.")
        }
    }
    
    func delete() {
        var acknowledgement = WebAbstractMessageAcknowledgement(requestID, false, nil)
        
        guard let conversation else {
            DDLogError("Conversation was nil when it must not be.")
            return
        }
        
        let businessInjector = BusinessInjector(forBackgroundProcess: true)
        
        businessInjector.entityManager.performAndWaitSave {
            guard let conv = businessInjector.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? ConversationEntity else {
                acknowledgement.success = false
                acknowledgement.error = "invalidMessage"
                DDLogError("Could not fetch conversation")
                self.ack = acknowledgement
                
                return
            }
            
            guard let message = businessInjector.entityManager.entityFetcher.message(
                with: self.messageID,
                conversation: conv
            ) else {
                DDLogError("Could not fetch message")
                acknowledgement.success = false
                acknowledgement.error = "invalidMessage"
                self.ack = acknowledgement
                
                return
            }
            
            if message.isKind(of: BaseMessage.self) || message.isKind(of: SystemMessageEntity.self) {
                businessInjector.entityManager.entityDestroyer.delete(baseMessage: message)

                conv.lastMessage = MessageFetcher(for: conv, with: businessInjector.entityManager).lastDisplayMessage()
            }
        }
        
        acknowledgement.success = true
        ack = acknowledgement
    }
}
