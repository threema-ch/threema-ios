//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
    var more = false
    
    var messageArray: [[AnyHashable: Any]]
    
    init(requestMessage: WebMessagesRequest, session: WCSession) {
        
        let entityManager = EntityManager()
        var conversation: Conversation?
        
        let maxMessageCount = Int(kWebPageSize)
        self.messageArray = [[AnyHashable: Any]]()
        
        self.type = requestMessage.type
        self.identity = requestMessage.id
        if type == "contact" {
            conversation = entityManager.entityFetcher.conversation(forIdentity: requestMessage.id)
        }
        else {
            conversation = entityManager.entityFetcher.legacyConversation(for: requestMessage.id.hexadecimal)
        }
        
        if let conversation {
            let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
            messageFetcher.orderAscending = false
    
            var index: UInt = 0
            if requestMessage.refMsgID != nil {
                let tmpIndex = WebMessagesResponse.indexForMessageID(
                    messageID: requestMessage.refMsgID!,
                    messageFetcher: messageFetcher,
                    session: session
                )
                
                if tmpIndex != -1 {
                    index = UInt(tmpIndex)
                }
                else {
                    let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": identity, "more": false]
                    let tmpAck = requestMessage.requestID != nil ? WebAbstractMessageAcknowledgement(
                        requestMessage.requestID,
                        true,
                        nil
                    ) : nil
                    super.init(
                        messageType: "response",
                        messageSubType: "messages",
                        requestID: nil,
                        ack: tmpAck,
                        args: tmpArgs,
                        data: nil
                    )
                    return
                }
            }
            
            var toSaveBaseMessage: BaseMessage?
            for message in messageFetcher.messages(at: Int(index), count: maxMessageCount).reversed() {

                if toSaveBaseMessage == nil {
                    toSaveBaseMessage = message
                }

                let messageObject = WebMessageObject(
                    message: message,
                    conversation: conversation,
                    forConversationsRequest: false,
                    session: session
                )
                let messageDict: [AnyHashable: Any] = messageObject.objectDict()
                messageArray.append(messageDict)
            }
            
            let actualLoadedCount = Int(index) + messageArray.count + 1
            let actualLoadedIndex = Int(index) + messageArray.count
            if actualLoadedCount < messageFetcher.count() {
                self.more = true
            }
            
            if toSaveBaseMessage != nil {
                session.addLastLoadedMessageIndex(messageID: toSaveBaseMessage!.id, index: actualLoadedIndex)
            }
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": identity, "more": more]
        let tmpAck = requestMessage.requestID != nil ? WebAbstractMessageAcknowledgement(
            requestMessage.requestID,
            true,
            nil
        ) : nil
        super.init(
            messageType: "response",
            messageSubType: "messages",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: messageArray
        )
    }
    
    internal static func indexForMessageID(messageID: Data, messageFetcher: MessageFetcher, session: WCSession) -> Int {
        var index = 0
        var indexCorrect = false
        let lastLoadedMessageIndex = session.lastLoadedMessageIndexes(contains: messageID)

        if lastLoadedMessageIndex != nil {
            for message in messageFetcher.messages(at: lastLoadedMessageIndex!, count: 1) {
                if message.id == messageID {
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
            }
            else {
                tmpIndex = 0
            }
            var counter = 0
            for message in messageFetcher.messages(at: tmpIndex, count: searchResultCount) {
                if message.id == messageID {
                    index = tmpIndex + counter + 1
                    indexCorrect = true
                    break
                }
                counter = counter + 1
            }
            
            if searchResultCount - tmpIndex >= messageFetcher.count(), !indexCorrect {
                index = -1
                indexCorrect = true
            }
            
            searchResultCount = searchResultCount * 2
        }
        return index
    }
}
