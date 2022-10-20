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

class ConversationActions: NSObject {
    
    let unreadMessages: UnreadMessagesProtocol
    let entityManager: EntityManager
    let notificationManager: NotificationManagerProtocol
    
    init(
        unreadMessages: UnreadMessagesProtocol,
        entityManager: EntityManager,
        notificationManager: NotificationManagerProtocol
    ) {
        self.unreadMessages = unreadMessages
        self.entityManager = entityManager
        self.notificationManager = notificationManager
    }
    
    @objc convenience init(entityManager: EntityManager) {
        self.init(
            unreadMessages: UnreadMessages(entityManager: entityManager),
            entityManager: entityManager,
            notificationManager: NotificationManager(
                businessInjector: BusinessInjector()
            )
        )
    }
    
    // MARK: - Reading
    
    /// Reads all unread messages of a conversation if read receipts are enabled, also updates the unread messages count
    /// - Parameters:
    ///   - conversation: Conversation to read messages
    ///   - isAppInBackground: If app is in background, default gets current status from AppDelegate
    func read(
        _ conversation: Conversation,
        isAppInBackground: Bool = AppDelegate.shared().isAppInBackground()
    ) -> Promise<Void> {
        Promise { seal in
            entityManager.performBlock {
                self.unreadMessages.read(for: conversation, isAppInBackground: isAppInBackground)
                    .then { () -> Promise<Void> in
                        self.entityManager.performBlockAndWait {
                            if conversation.unreadMessageCount == -1 {
                                self.entityManager.performSyncBlockAndSafe {
                                    conversation.unreadMessageCount = 0
                                }
                            }
                        }
                        return Promise()
                    }
                    .done {
                        self.notificationManager.updateUnreadMessagesCount()
                        seal.fulfill_()
                    }
                    .catch { error in
                        DDLogError("Failed to mark all messages as read: \(error)")
                        seal.reject(error)
                    }
            }
        }
    }
    
    @objc func readObjc(
        _ conversation: Conversation,
        isAppInBackground: Bool = AppDelegate.shared().isAppInBackground()
    ) -> AnyPromise {
        AnyPromise(read(conversation, isAppInBackground: isAppInBackground))
    }

    func unread(_ conversation: Conversation) {

        let unreadMessagesCount = unreadMessages.count(for: conversation)
        guard unreadMessagesCount == 0 else {
            return
        }
        
        entityManager.performSyncBlockAndSafe {
            conversation.unreadMessageCount = -1
        }

        notificationManager.updateUnreadMessagesCount()
    }
    
    // MARK: - Pinning
    
    func pin(_ conversation: Conversation) {
        
        entityManager.performSyncBlockAndSafe {
            conversation.marked = NSNumber(booleanLiteral: true)
        }
    }
    
    func unpin(_ conversation: Conversation) {
        
        entityManager.performSyncBlockAndSafe {
            conversation.marked = NSNumber(booleanLiteral: false)
        }
    }
    
    // MARK: - Archiving
    
    func archive(_ conversation: Conversation, isAppInBackground: Bool = AppDelegate.shared().isAppInBackground()) {
        
        entityManager.performSyncBlockAndSafe {
            conversation.conversationVisibility = .archived
            conversation.marked = NSNumber(booleanLiteral: false)
        }
        notificationManager.updateUnreadMessagesCount()
    }
    
    @objc func unarchive(_ conversation: Conversation) {
        var doUpdateUnreadMessagesCount = false

        entityManager.performSyncBlockAndSafe {
            if conversation.conversationVisibility != .default {
                conversation.conversationVisibility = .default
                doUpdateUnreadMessagesCount = true
            }
        }

        if doUpdateUnreadMessagesCount {
            notificationManager.updateUnreadMessagesCount()
        }
    }
    
    // MARK: - Private
    
    func makePrivate(_ conversation: Conversation) {
        entityManager.performSyncBlockAndSafe {
            conversation.conversationCategory = .private
        }
    }
    
    func makeNotPrivate(_ conversation: Conversation) {
        entityManager.performSyncBlockAndSafe {
            conversation.conversationCategory = .default
        }
    }
}