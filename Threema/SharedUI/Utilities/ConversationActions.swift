//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

class ConversationActions: NSObject {
    private let businessInjector: BusinessInjectorProtocol
    private let notificationManagerResolve: (BusinessInjectorProtocol) -> NotificationManagerProtocol

    /// Conversation actions set messages in conversation to (un)read or (un)archive.
    ///
    /// - Parameters:
    ///   - businessInjector: BusinessInjector working on
    ///   - notificationManagerResolve: Resolve `NotificationManager` for running in background or in unit tests
    init(
        businessInjector: BusinessInjectorProtocol,
        notificationManagerResolve: @escaping (BusinessInjectorProtocol) -> NotificationManagerProtocol
    ) {
        self.businessInjector = businessInjector
        self.notificationManagerResolve = notificationManagerResolve
    }

    convenience init(businessInjector: BusinessInjectorProtocol) {
        self.init(
            businessInjector: businessInjector,
            notificationManagerResolve: { businessInjector in
                NotificationManager(businessInjector: businessInjector)
            }
        )
    }
    
    @objc override convenience init() {
        self.init(businessInjector: BusinessInjector.ui)
    }
    
    // MARK: - Reading
    
    /// Reads all unread messages of a conversation if read receipts are enabled, also updates the unread messages count
    /// - Parameters:
    ///   - conversation: ConversationEntity to read messages for
    ///   - isAppInBackground: If app is in background, default gets current status from AppDelegate
    func read(
        _ conversation: ConversationEntity,
        isAppInBackground: Bool
    ) async {
        await businessInjector.runInBackground { backgroundBusinessInjector in
            await backgroundBusinessInjector.entityManager.perform {
                if let conv = backgroundBusinessInjector.entityManager.entityFetcher
                    .getManagedObject(by: conversation.objectID) as? ConversationEntity {
                    _ = backgroundBusinessInjector.unreadMessages.read(
                        for: conv,
                        isAppInBackground: isAppInBackground
                    )

                    if conv.unreadMessageCount == -1 {
                        backgroundBusinessInjector.entityManager.performAndWaitSave {
                            conv.unreadMessageCount = 0
                        }
                    }
                }

                self.notificationManagerResolve(backgroundBusinessInjector).updateUnreadMessagesCount()
            }
        }
    }

    /// Marks the messages passed in from the argument as read
    /// This is a workaround implemented specifically for `ChatViewController`.
    /// - Parameters:
    ///   - conversationObjectID: The conversation to which the messages below
    ///   - messageObjectIDs: Messages which will be marked as read
    /// - Returns: The number of messages that were marked as read
    func read(
        _ conversationObjectID: NSManagedObjectID,
        messageObjectIDs: [NSManagedObjectID]
    ) -> Int {
        let isAppInBackground = AppDelegate.shared().isAppInBackground()

        return businessInjector.runInBackgroundAndWait { backgroundBusinessInjector in
            backgroundBusinessInjector.entityManager.performAndWait {
                let conversation = backgroundBusinessInjector.entityManager.entityFetcher
                    .getManagedObject(by: conversationObjectID) as! ConversationEntity

                var messages = [BaseMessageEntity]()
                for messageObjectID in messageObjectIDs {
                    if let message = backgroundBusinessInjector.entityManager.entityFetcher
                        .getManagedObject(by: messageObjectID) as? BaseMessageEntity {
                        messages.append(message)
                    }
                }

                let markedAsRead = backgroundBusinessInjector.unreadMessages.read(
                    for: messages,
                    in: conversation,
                    isAppInBackground: isAppInBackground
                )

                if conversation.unreadMessageCount == -1 {
                    backgroundBusinessInjector.entityManager.performAndWaitSave {
                        conversation.unreadMessageCount = 0
                    }
                }

                self.notificationManagerResolve(backgroundBusinessInjector).updateUnreadMessagesCount()

                return markedAsRead
            }
        }
    }

    func unread(_ conversation: ConversationEntity) {

        let unreadMessagesCount = businessInjector.unreadMessages.count(for: conversation)
        guard unreadMessagesCount == 0 else {
            return
        }
        
        businessInjector.entityManager.performAndWaitSave {
            conversation.unreadMessageCount = -1
        }

        notificationManagerResolve(businessInjector).updateUnreadMessagesCount()
    }
    
    // MARK: - Archiving
    
    func archive(_ conversation: ConversationEntity) {
        businessInjector.conversationStore.archive(conversation)
        notificationManagerResolve(businessInjector).updateUnreadMessagesCount()
    }
    
    func unarchive(_ conversation: ConversationEntity) {
        var doUpdateUnreadMessagesCount = false

        businessInjector.entityManager.performAndWait {
            if conversation.conversationVisibility != .default {
                doUpdateUnreadMessagesCount = true
            }
        }

        businessInjector.conversationStore.unarchive(conversation)

        if doUpdateUnreadMessagesCount {
            notificationManagerResolve(businessInjector).updateUnreadMessagesCount()
        }
    }
}
