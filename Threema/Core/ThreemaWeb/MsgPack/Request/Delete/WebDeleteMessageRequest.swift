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

class WebDeleteMessageRequest: WebAbstractMessage {
    
    let type: String
    var identity: String?
    var groupID: Data?
    
    let messageID: Data
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal()
        }
        
        let messageIDBase64 = message.args!["messageId"] as! String
        self.messageID = Data(base64Encoded: messageIDBase64, options: .ignoreUnknownCharacters)!
        super.init(message: message)
    }
    
    func delete() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let entityManager = EntityManager()
        let message = entityManager.entityFetcher.message(with: messageID)
        var chatViewController: Old_ChatViewController?
        if message != nil {
            let groupID = message!.conversation.groupID
            var identity: String?
            if let contact = message?.conversation?.contact {
                identity = contact.identity
            }
            
            if message != nil {
                entityManager.performSyncBlockAndSafe {
                    if message!.isKind(of: BaseMessage.self) {
                        message?.conversation = nil
                        entityManager.entityDestroyer.deleteObject(object: message!)
                    }
                    if message!.isKind(of: SystemMessage.self) {
                        entityManager.entityDestroyer.deleteObject(object: message!)
                    }
                    
                    var conversation: Conversation?
                    if groupID != nil {
                        conversation = entityManager.entityFetcher.conversation(for: groupID)
                    }
                    else if identity != nil {
                        conversation = entityManager.entityFetcher.conversation(forIdentity: identity)
                    }
                    
                    if let conversation = conversation {
                        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
                        conversation.lastMessage = messageFetcher.lastMessage()
                        chatViewController = Old_ChatViewControllerCache.controller(for: conversation)
                        chatViewController?.updateConversationLastMessage()
                    }
                }
                DispatchQueue.main.async {
                    chatViewController?.updateConversation()
                }
                ack!.success = true
            }
            else {
                ack!.success = false
                ack!.error = "invalidMessage"
            }
        }
    }
}
