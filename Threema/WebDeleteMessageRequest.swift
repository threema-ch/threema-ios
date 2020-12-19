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

class WebDeleteMessageRequest: WebAbstractMessage {
    
    let type: String
    var identity: String? = nil
    var groupId: Data? = nil
    
    let messageId: Data
    
    override init(message:WebAbstractMessage) {
        type = message.args!["type"] as! String
        
        if type == "contact" {
            identity = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as! String
            groupId = idString.hexadecimal()
        }
        
        let messageIdBase64 = message.args!["messageId"] as! String
        messageId = Data(base64Encoded: messageIdBase64, options: .ignoreUnknownCharacters)!
        super.init(message: message)
    }
    
    func delete() {
        ack = WebAbstractMessageAcknowledgement.init(requestId, false, nil)
        let entityManager = EntityManager()
        let message = entityManager.entityFetcher.message(withId: messageId)
        var chatViewController: ChatViewController? = nil
        if message != nil {
            let groupId = message!.conversation.groupId
            var identity: String? = nil
            if message!.conversation.contact != nil {
                identity = message!.conversation.contact.identity
            }
            
            if message != nil {
                entityManager.performSyncBlockAndSafe({
                    if message!.isKind(of: BaseMessage.self) {
                        message?.conversation = nil
                        entityManager.entityDestroyer.deleteObject(object: message!)
                        
                    }
                    if message!.isKind(of: SystemMessage.self) {
                        entityManager.entityDestroyer.deleteObject(object: message!)
                    }
                    
                    var conversation: Conversation? = nil
                    if groupId != nil {
                        conversation = entityManager.entityFetcher.conversation(forGroupId: groupId)
                    }
                    else if identity != nil {
                        conversation = entityManager.entityFetcher.conversation(forIdentity: identity)
                    }
                    
                    if conversation != nil {
                        let messageFetcher = MessageFetcher.init(for: conversation, with: entityManager.entityFetcher)
                        conversation?.lastMessage = messageFetcher?.lastMessage()
                        chatViewController = ChatViewControllerCache.controller(for: conversation)
                        chatViewController?.updateConversationLastMessage()
                    }
                })
                DispatchQueue.main.async {
                    chatViewController?.updateConversation()
                }
                ack!.success = true
            } else {
                ack!.success = false
                ack!.error = "invalidMessage"
            }
        }
    }
}
