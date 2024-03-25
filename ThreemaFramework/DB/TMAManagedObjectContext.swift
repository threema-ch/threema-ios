//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

/// This class helps ensuring database integrity when objects are deleted.
/// If an integrity violation is detected, the app ends with a fatal error.
/// In some less severe cases, a warning is logged.
@objc public class TMAManagedObjectContext: NSManagedObjectContext {
    // MARK: - Overrides

    override public func delete(_ object: NSManagedObject) {
        if let conversation = object as? Conversation {
            delete(conversation)
        }
        else if let contact = object as? ContactEntity {
            delete(contact)
        }
        else if let message = object as? BaseMessage {
            delete(message)
        }
        else {
            super.delete(object)
        }
    }

    // MARK: - Private Helper Function

    private func delete(_ conversation: Conversation) {
        guard verifyNoLeftOverMessages(in: Set([conversation])) else {
            fatalError()
        }

        super.delete(conversation)
    }

    private func delete(_ contact: ContactEntity) {
        if let conversationsObjects = contact.conversations {
            if let conversations = conversationsObjects as? Set<Conversation> {
                guard verifyNoLeftOverMessages(in: conversations) else {
                    fatalError()
                }
            }
        }

        if let conversationsObjects = contact.groupConversations {
            if let conversations = conversationsObjects as? Set<Conversation> {
                guard verifyNoLeftOverMessages(in: conversations, from: contact) else {
                    fatalError()
                }
            }
        }

        // We allow `contact.conversations` and `contact.groupConversations` to be not empty as this will be properly
        // handled by CoreData (nullify on delete of contact)

        super.delete(contact)
    }

    private func delete(_ message: BaseMessage) {
        let fetchConversations = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchConversations.predicate = NSPredicate(format: "lastMessage = %@", message)

        guard let prevConversations = try? count(for: fetchConversations), prevConversations == 0 else {
            DDLogWarn("Delete message failed, it has still a reference to Conversation.lastMessage")
            return
        }

        return super.delete(message)
    }

    /// Verifies that no messages exist with a relation to the conversation
    ///  Will crash if the fetch request for messages fails
    /// - Parameter conversation: the conversation to verify
    /// - Returns: true if no messages were found, false if messages were found
    private func verifyNoLeftOverMessages(
        in conversations: Set<Conversation>,
        from contact: ContactEntity? = nil
    ) -> Bool {
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        if let contact {
            fetchMessages.predicate = NSPredicate(format: "conversation IN %@ && sender = %@", conversations, contact)
        }
        else {
            fetchMessages.predicate = NSPredicate(format: "conversation IN %@", conversations)
        }

        guard let prevMessages = try? count(for: fetchMessages) else {
            fatalError()
        }

        return prevMessages == 0
    }
}
