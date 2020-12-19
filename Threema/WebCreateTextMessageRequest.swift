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

public class WebCreateTextMessageRequest: WebAbstractMessage {
    var type: String
    var id: String?
    var groupId: Data?
    
    var text: String
    var quote: WebTextMessageQuote?
    
    var baseMessage: BaseMessage? = nil
    
    var tmpError: String? = nil
    
    override init(message:WebAbstractMessage) {

        type = message.args!["type"] as! String
        if type == "contact" {
            id = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as! String
            groupId = idString.hexadecimal()
        }
        
        let data = message.data! as! [AnyHashable:Any?]
        text = data["text"] as! String

        super.init(message: message)
        
        let tmpQuote = data["quote"] as? [AnyHashable:Any]
        if tmpQuote != nil {
            quote = WebTextMessageQuote.init(identity: tmpQuote!["identity"]! as! String, text: tmpQuote!["text"]! as! String)
            let quoteText = makeQuoteWithReply()
            text = quoteText + text
        }
    }
    
    func sendMessage(completion: @escaping () -> ()) {
        var conversation: Conversation? = nil
        if self.type == "contact" {
//            DispatchQueue.main.sync {
                let entityManager = EntityManager()
                let contact = entityManager.entityFetcher.contact(forId: self.id)
                if contact == nil {
                    self.baseMessage = nil
                    tmpError = "internalError"
                    completion()
                    return
                }
                
                conversation = entityManager.entityFetcher.conversation(for: contact)
                if conversation == nil {
                    entityManager.performSyncBlockAndSafe({
                        conversation = entityManager.entityCreator.conversation()
                        conversation?.contact = contact
                    })
                }
                
                if conversation != nil {
                    if !PermissionChecker.init().canSend(in: conversation, entityManager: entityManager) {
                        self.baseMessage = nil
                        tmpError = "blocked"
                        completion()
                        return
                    }
                    
                    MessageSender.sendMessage(self.text, in: conversation, async: true, quickReply: false, requestId:self.requestId, onCompletion: { (message, conv)  in
                        self.baseMessage = message
                        completion()
                        return
                    })
                } else {
                    self.baseMessage = nil
                    tmpError = "internalError"
                    completion()
                    return
                }
//            }
        } else {
//            DispatchQueue.main.sync {
                let entityManager = EntityManager()
                conversation = entityManager.entityFetcher.conversation(forGroupId: self.groupId)
                
                if conversation != nil {
                    if !PermissionChecker.init().canSend(in: conversation, entityManager: entityManager) {
                        self.baseMessage = nil
                        
                        tmpError = "blocked"
                        completion()
                        return
                    }
                    MessageSender.sendMessage(self.text, in: conversation, async: true, quickReply: false, requestId:self.requestId, onCompletion: { (message, conv) in
                        self.baseMessage = message
                        completion()
                        return
                    })
                } else {
                    self.baseMessage = nil
                    tmpError = "internalError"
                    completion()
                    return
                }
            }
//        }
    }
    
    func makeQuoteWithReply() -> String {
        var quoteString: String = "> "
        quoteString.append(quote!.identity)
        quoteString.append(": ")
        
        let lines = quote!.text.components(separatedBy: "\n")
        var i = 0
        for line in lines {
            if i > 0 {
                quoteString.append("\n> ")
            }
            quoteString.append(line)
            i = i+1
        }
        quoteString.append("\n")
        return quoteString
    }
}

struct WebTextMessageQuote {
    var identity:String
    var text:String
}
