//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class WebMessagesResponse: WebAbstractMessage {
    
    var type: String
    var identity: String
    var more: Bool = false
    
    var messageArray: Array<[AnyHashable:Any]>
    
    init(requestMessage: WebMessagesRequest, session: WCSession) {
        
        let entityManager = EntityManager()
        var conversation: Conversation? = nil
        
        let maxMessageCount = Int(kWebPageSize)
        messageArray = Array<[AnyHashable:Any]>()
        
        type = requestMessage.type
        identity = requestMessage.id
        if type == "contact" {
            conversation = entityManager.entityFetcher.conversation(forIdentity: requestMessage.id)
        } else {
            conversation = entityManager.entityFetcher.conversation(forGroupId: requestMessage.id.hexadecimal())
        }
        
        if conversation != nil {
            let messageFetcher = MessageFetcher.init(for: conversation, with: entityManager.entityFetcher)
            messageFetcher?.orderAscending = false
    
            var index: UInt = 0
            if requestMessage.refMsgId != nil {
                let tmpIndex = WebMessagesResponse.indexForMessageId(messageId: requestMessage.refMsgId!, messageFetcher: messageFetcher!, session: session)
                
                if tmpIndex != -1 {
                    index = UInt(tmpIndex)
                } else {
                    let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": identity, "more": false]
                    let tmpAck = requestMessage.requestId != nil ? WebAbstractMessageAcknowledgement.init(requestMessage.requestId, true, nil) : nil
                    super.init(messageType: "response", messageSubType: "messages", requestId: nil, ack: tmpAck, args: tmpArgs, data: nil)
                    return
                }
            }
            
            var toSaveBaseMessage: BaseMessage? = nil
            for message in (messageFetcher?.messages(atOffset: Int(index), count: maxMessageCount)!)!.reversed() {

                let baseMessage = message as! BaseMessage

                if toSaveBaseMessage == nil {
                    toSaveBaseMessage = baseMessage
                }

                let messageObject = WebMessageObject.init(message: message as! BaseMessage, conversation: conversation!, forConversationsRequest: false, session: session)
                let messageDict:[AnyHashable:Any] = messageObject.objectDict()
                messageArray.append(messageDict)
            }
            
            let actualLoadedCount = Int(index) + messageArray.count + 1
            let actualLoadedIndex = Int(index) + messageArray.count
            if actualLoadedCount < messageFetcher!.count() {
                more = true
            }
            
            if toSaveBaseMessage != nil {
                session.addLastLoadedMessageIndex(messageId: toSaveBaseMessage!.id, index: actualLoadedIndex)
            }
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": identity, "more": more]
        let tmpAck = requestMessage.requestId != nil ? WebAbstractMessageAcknowledgement.init(requestMessage.requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "messages", requestId: nil, ack: tmpAck, args: tmpArgs, data: messageArray)
    }
    
    static internal func indexForMessageId(messageId: Data, messageFetcher: MessageFetcher, session: WCSession) -> Int {
        var index: Int = 0
        var indexCorrect: Bool = false
        let lastLoadedMessageIndex = session.lastLoadedMessageIndexes(contains: messageId)

        if lastLoadedMessageIndex != nil {
            for message in (messageFetcher.messages(atOffset: lastLoadedMessageIndex!, count: 1))! {
                let baseMessage = message as! BaseMessage
                if baseMessage.id == messageId {
                    index = index + 1
                    indexCorrect = true
                }
            }
        }
        
        var searchResultCount = Int(kWebPageSize)
        var tmpIndex = index
        while !indexCorrect {
            if tmpIndex > searchResultCount / 2 {
                tmpIndex = tmpIndex - searchResultCount / 2
            } else {
                tmpIndex = 0
            }
            var counter = 0
            for message in (messageFetcher.messages(atOffset: tmpIndex, count: searchResultCount))! {
                let baseMessage = message as! BaseMessage
                if baseMessage.id == messageId {
                    index = tmpIndex + counter + 1
                    indexCorrect = true
                    break
                }
                counter = counter + 1
            }
            
            if searchResultCount - tmpIndex >= messageFetcher.count() && !indexCorrect {
                index = -1
                indexCorrect = true
            }
            
            searchResultCount = searchResultCount * 2
        }
        return index
    }
}
