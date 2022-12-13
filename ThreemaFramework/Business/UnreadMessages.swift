//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import PromiseKit

public protocol UnreadMessagesProtocol: UnreadMessagesProtocolObjc {
    func read(for conversation: Conversation, isAppInBackground: Bool)
}

@objc public protocol UnreadMessagesProtocolObjc {
    func count(for conversation: Conversation) -> Int
    func totalCount() -> Int
    func totalCount(doCalcUnreadMessagesCountOf conversation: [Conversation]) -> Int
}

@objc public class UnreadMessages: NSObject, UnreadMessagesProtocol {
    
    private let entityManager: EntityManager
    
    @objc public init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }

    /// Unread messages count of conversation and recalculate `Conversation.unreadMessageCount`.
    /// - Parameter conversation: Conversation to counting und recalculating unread messages count
    /// - Returns: Unread messages count for this conversation
    public func count(for conversation: Conversation) -> Int {
        var unreadMessagesCount = 0

        entityManager.performSyncBlockAndSafe {
            unreadMessagesCount = self.count(conversations: [conversation], doCalcUnreadMessagesCountOf: [conversation])
        }

        return unreadMessagesCount
    }

    /// Unread messages count of all conversations (count only cached `Conversation.unreadMessageCount`).
    /// - Returns: Unread messages count of all conversations
    @objc @discardableResult public func totalCount() -> Int {
        totalCount(doCalcUnreadMessagesCountOf: [Conversation]())
    }

    /// Unread messages count of all conversations, and recalculate `Conversation.unreadMessageCount` for given conversations.
    /// - Parameter doCalcUnreadMessagesCountOf: Recalculate unread messages count for this conversations
    /// - Returns: Unread messages count of all conversations
    @objc @discardableResult public func totalCount(doCalcUnreadMessagesCountOf: [Conversation]) -> Int {
        var unreadMessagesCount = 0

        entityManager.performSyncBlockAndSafe {
            var conversations = [Conversation]()
            for conversation in self.entityManager.entityFetcher.notArchivedConversations() {
                if let conversation = conversation as? Conversation {
                    conversations.append(conversation)
                }
            }

            if !conversations.isEmpty {
                unreadMessagesCount = self.count(
                    conversations: conversations,
                    doCalcUnreadMessagesCountOf: doCalcUnreadMessagesCountOf
                )
            }
        }

        return unreadMessagesCount
    }

    private func count(conversations: [Conversation], doCalcUnreadMessagesCountOf: [Conversation]) -> Int {
        var unreadMessagesCount = 0

        for conversation in conversations {
            var count = 0
            if doCalcUnreadMessagesCountOf.contains(where: { item in
                item.objectID == conversation.objectID
            }) {
                count = entityManager.entityFetcher.countUnreadMessages(for: conversation)
            }
            else {
                count = conversation.unreadMessageCount.intValue
            }
            
            // Check is conversation marked as unread
            if count == 0,
               conversation.unreadMessageCount == -1 {
                count = -1
            }

            if count != -1 {
                unreadMessagesCount += count
            }
            else {
                unreadMessagesCount += 1
            }

            guard conversation.unreadMessageCount.intValue != count else {
                continue
            }
            conversation.unreadMessageCount = NSNumber(integerLiteral: count)
        }

        return unreadMessagesCount
    }
    
    /// Sends read receipts for all unread messages in conversation, for group conversation just update message read.
    /// - Warning: Use this function within db context perform block
    /// - Parameters:
    ///   - conversation: Conversation to send receipts
    ///   - isAppInBackground: If App is in background
    public func read(for conversation: Conversation, isAppInBackground: Bool) {

        // Only send receipt if not Group and App is in foreground
        guard !isAppInBackground,
              let messages = entityManager.entityFetcher.unreadMessages(for: conversation) else {
            return
        }

        // Unread messages are only incoming messages
        var unreadMessages = [BaseMessage]()

        messages.forEach { message in
            guard let baseMessage = message as? BaseMessage,
                  !baseMessage.isOwnMessage else {
                return
            }

            unreadMessages.append(baseMessage)
        }

        guard !unreadMessages.isEmpty else {
            return
        }

        // Update message read
        updateMessageRead(messages: unreadMessages)
        totalCount(doCalcUnreadMessagesCountOf: [conversation])

        if let contact = conversation.contact {
            // Send read receipt
            MessageSender.sendReadReceipt(
                forMessages: unreadMessages,
                toIdentity: contact.identity,
                onCompletion: nil
            )
        }
    }

    private func updateMessageRead(messages: [BaseMessage]) {
        entityManager.performSyncBlockAndSafe {
            for message in messages {
                message.read = NSNumber(booleanLiteral: true)
                message.readDate = Date()
            }
        }
    }
}
