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

public class WebCreateTextMessageRequest: WebAbstractMessage {
    var type: String
    var id: String?
    var groupID: Data?
    
    var text: String
    var quote: WebTextMessageQuote?
    
    var baseMessage: BaseMessage?
    
    var tmpError: String?
    
    override init(message: WebAbstractMessage) {

        self.type = message.args!["type"] as! String
        if type == "contact" {
            self.id = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal
        }
        
        let data = message.data! as! [AnyHashable: Any?]
        self.text = data["text"] as! String

        super.init(message: message)
        
        let tmpQuote = data["quote"] as? [AnyHashable: Any]
        if tmpQuote != nil {
            self.quote = WebTextMessageQuote(
                identity: tmpQuote!["identity"]! as! String,
                text: tmpQuote!["text"]! as! String,
                messageID: tmpQuote!["messageId"] as? String
            )
            let messageID = Data(base64Encoded: quote!.messageID!, options: .ignoreUnknownCharacters)!
            self.text = QuoteUtil.generateText(text, with: messageID)
        }
    }
    
    func sendMessage(completion: @escaping () -> Void) {
        let businessInjector = BusinessInjector()
        let entityManager = businessInjector.entityManager
        let groupManager = businessInjector.groupManager
        let messagePermission = MessagePermission(
            myIdentityStore: MyIdentityStore.shared(),
            userSettings: UserSettings.shared(),
            groupManager: groupManager,
            entityManager: entityManager
        )

        var conversation: ConversationEntity!
        if type == "contact" {
            guard let contact = entityManager.entityFetcher.contact(for: id) else {
                baseMessage = nil
                tmpError = "internalError"
                completion()
                return
            }

            conversation = entityManager.entityFetcher.conversation(for: contact)
            if conversation == nil {
                entityManager.performAndWaitSave {
                    conversation = entityManager.entityCreator.conversationEntity()
                    conversation?.contact = contact
                }
            }

            guard conversation != nil else {
                baseMessage = nil
                tmpError = "internalError"
                completion()
                return
            }

            if !messagePermission.canSend(to: contact.identity).isAllowed {
                baseMessage = nil
                tmpError = "blocked"
                completion()
                return
            }
        }
        else {
            conversation = entityManager.entityFetcher.legacyConversation(for: groupID)

            guard conversation != nil,
                  let group = groupManager.getGroup(conversation: conversation)
            else {
                baseMessage = nil
                tmpError = "internalError"
                completion()
                return
            }

            if !messagePermission.canSend(groudID: group.groupID, groupCreatorIdentity: group.groupCreatorIdentity)
                .isAllowed {
                baseMessage = nil
                tmpError = "blocked"
                completion()
                return
            }
        }

        sendMessage(conversation: conversation, completion: completion)
    }

    private func sendMessage(conversation: ConversationEntity, completion: @escaping () -> Void) {
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
            Task {
                let businessInjector = BusinessInjector()
                let textMessages = await businessInjector.messageSender.sendTextMessage(
                    containing: self.text,
                    in: conversation,
                    requestID: self.requestID
                )
                if let message = textMessages.first, textMessages.count == 1 {
                    self.baseMessage = message
                }
                else {
                    assertionFailure("This must not happen.")
                }
                
                completion()
                if conversation.conversationVisibility == .archived {
                    conversation.changeVisibility(to: .default)
                }
            }
        } onTimeout: {
            DDLogError("Sending text message via web client time out")
        }
    }
}

struct WebTextMessageQuote {
    var identity: String
    var text: String
    var messageID: String?
}
