import CocoaLumberjackSwift
import Foundation
import PromiseKit

class ConversationActions {
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
                    .managedObject(with: conversation.objectID) as? ConversationEntity {
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
    
    /// Reads all unread messages of all conversation if read receipts are enabled, also updates the unread messages
    /// count
    /// - Parameters:
    ///   - isAppInBackground: If app is in background, default gets current status from AppDelegate
    func readAll(isAppInBackground: Bool) async {
        await businessInjector.runInBackground { backgroundBusinessInjector in
            await backgroundBusinessInjector.entityManager.perform {
                if let conversations = backgroundBusinessInjector.entityManager.entityFetcher
                    .conversationEntities() {
                    Task {
                        for conversation in conversations {
                            await self.read(conversation, isAppInBackground: isAppInBackground)
                        }
                    }
                }
            }
            
            self.notificationManagerResolve(backgroundBusinessInjector).updateUnreadMessagesCount()
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
                guard let conversation = backgroundBusinessInjector.entityManager.entityFetcher
                    .managedObject(with: conversationObjectID) as? ConversationEntity else {
                    return 0
                }

                var messages = [BaseMessageEntity]()
                for messageObjectID in messageObjectIDs {
                    if let message = backgroundBusinessInjector.entityManager.entityFetcher
                        .managedObject(with: messageObjectID) as? BaseMessageEntity {
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
