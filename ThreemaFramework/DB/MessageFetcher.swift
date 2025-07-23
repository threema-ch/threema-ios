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
import PromiseKit
import UIKit

/// Access messages of a conversation
public class MessageFetcher: NSObject {
    
    /// Set order of returned messages (this only affects calls to `messages(at:count:)`). Default is `true`.
    public var orderAscending = true {
        didSet {
            guard orderAscending != oldValue else {
                return
            }
            
            oldMessagesFetchRequest = newOldMessagesFetchRequest()
        }
    }
    
    /// Get a fresh fetched request for the messages of the conversation
    var messagesFetchRequest: NSFetchRequest<BaseMessageEntity> {
        let fetchRequest = NSFetchRequest<BaseMessageEntity>(entityName: entityName)
        
        fetchRequest.predicate = conversationPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: orderAscending)
        
        return fetchRequest
    }
    
    // MARK: - Private properties
    
    private let entityName = "Message"
    private let fileEntityName = "FileMessage"
    private let imageEntityName = "ImageMessage"
    private let videoEntityName = "VideoMessage"
    private let audioEntityName = "AudioMessage"
    private let systemEntityName = "SystemMessage"
    
    private let conversation: ConversationEntity
    private let entityManager: EntityManager
    
    // MARK: Predicates
    
    private var conversationPredicate: NSPredicate {
        NSPredicate(format: "conversation == %@", conversation)
    }
    
    private var conversationFilePredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ && %K != nil", conversation, "data")
    }
    
    private var conversationImagePredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ && %K != nil", conversation, "image")
    }
    
    private var conversationVideoPredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ && %K != nil", conversation, "video")
    }
    
    private var conversationAudioPredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ && %K != nil", conversation, "audio")
    }
    
    private var conversationUnreadPredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ AND read == false AND isOwn == false", conversation)
    }
    
    private var conversationRejectedPredicate: NSPredicate {
        NSPredicate(format: "conversation == %@ AND (rejectedBy.@count > 0)", conversation)
    }
    
    private var conversationWithFilteredNoMIMETypeFileMessages: NSPredicate {
        let fileMessagePredicate = NSPredicate(format: "%K == nil", "mimeType")

        return NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, fileMessagePredicate])
    }
    
    private var conversationWithFilteredDeletedMessages: NSPredicate {
        let deletedMessagePredicate = NSPredicate(format: "%K != nil", "deletedAt")

        return NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, deletedMessagePredicate])
    }

    // MARK: Fetch requests
    
    private lazy var countFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var dateFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        // Predicate depends on input of `numberOfMessages(after:)`
        fetchRequest.sortDescriptors = sortDescriptors(ascending: true)
        
        return fetchRequest
    }()
    
    private lazy var oldMessagesFetchRequest = newOldMessagesFetchRequest()
    
    private lazy var unreadMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationUnreadPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequest
    }()
    
    private lazy var rejectedMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationRejectedPredicate
        // Sorting doesn't matter because we just need them to filter later
        return fetchRequest
    }()
    
    private lazy var limitedUnreadMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationUnreadPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequest
    }()

    private lazy var lastMessageExcludesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let excludePredicateExcludes = NSPredicate(
            format: "type IN %@",
            SystemMessageEntity.excludeSystemMessageTypes
        )
        let fetchRequestExcludes = NSFetchRequest<NSFetchRequestResult>(entityName: systemEntityName)
        fetchRequestExcludes.predicate =
            NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, excludePredicateExcludes])
        fetchRequestExcludes.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequestExcludes
    }()

    private func lastMessagesFetchRequest(exclude: [Any]?) -> NSFetchRequest<NSFetchRequestResult> {
        var predicate: NSPredicate
        if let exclude {
            let excludePredicate = NSPredicate(format: "NOT (SELF IN %@)", NSArray(array: exclude))
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, excludePredicate])
        }
        else {
            predicate = conversationPredicate
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequest
    }
    
    private lazy var countFileMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: fileEntityName)
        fetchRequest.predicate = conversationFilePredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countImageMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: imageEntityName)
        fetchRequest.predicate = conversationImagePredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countVideoMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: videoEntityName)
        fetchRequest.predicate = conversationVideoPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countAudioMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: audioEntityName)
        fetchRequest.predicate = conversationAudioPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var fileMessagesWithNoMIMETypeFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: fileEntityName)
        fetchRequest.predicate = conversationWithFilteredNoMIMETypeFileMessages
        // Sorting doesn't matter because we just need them to filter later
        return fetchRequest
    }()
    
    private lazy var messagesWithDeletedMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationWithFilteredDeletedMessages
        // Sorting doesn't matter because we just need them to filter later
        return fetchRequest
    }()

    // MARK: - Lifecycle
    
    /// Initialize for a fixed conversation
    /// - Parameters:
    ///   - conversation: ConversationEntity's messages you want to access
    ///   - entityManager: Manager used for fetch requests
    @objc public init(for conversation: ConversationEntity, with entityManager: EntityManager) {
        self.conversation = conversation
        self.entityManager = entityManager
                
        super.init()
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("Not supported")
    }
    
    // MARK: - Public methods
    
    /// Number of messages in the conversation
    public func count() -> Int {
        // This might be 0 before the first save after the migration to V35
        entityManager.entityFetcher.executeCount(countFetchRequest)
    }
    
    /// Number of messages in conversation after the passed date
    /// - Parameter date: All messages with a `date` or `remoteSentDate` newer than this are counted
    /// - Returns: Number of messages in this conversation after the passed date
    public func numberOfMessages(after date: Date) -> Int {
        let fetchRequest = dateFetchRequest
        
        let datePredicates = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "%K > %@", #keyPath(BaseMessageEntity.date), date as NSDate),
            NSPredicate(format: "%K > %@", #keyPath(BaseMessageEntity.remoteSentDate), date as NSDate),
        ])
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            conversationPredicate,
            datePredicates,
        ])
        
        return entityManager.entityFetcher.executeCount(dateFetchRequest)
    }
    
    /// Number of messages in conversation after the passed date
    /// - Parameter date: All messages with a `date` or `remoteSentDate` newer than this are counted
    /// - Returns: Number of messages in this conversation after the passed date or zero if an error occurred during
    /// execution
    /// This is consistent with the behavior of the standard `numberOfMessages` where `executeCount` returns 0 if the
    /// fetch request failed
    public func numberOfMessages(after date: Date) -> Guarantee<Int> {
        Guarantee { seal in
            let fetchRequest = dateFetchRequest
            
            let datePredicates = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K > %@", #keyPath(BaseMessageEntity.date), date as NSDate),
                NSPredicate(format: "%K > %@", #keyPath(BaseMessageEntity.remoteSentDate), date as NSDate),
            ])
            
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                conversationPredicate,
                datePredicates,
            ])
            
            entityManager.entityFetcher.executeCount(fetchRequest) { count in
                seal(count)
            } onError: { error in
                DDLogError("An error occurred: \(error)")
                seal(0)
            }
        }
    }
    
    /// Load messages starting at `offset`. Up to `count` messages are returned.
    /// - Parameters:
    ///   - offset: Offset of first message to load
    ///   - count: Maximum number of messages to load
    /// - Returns: Up to `count` messages. This is empty if there are no messages.
    public func messages(at offset: Int, count: Int) -> [BaseMessageEntity] {
        oldMessagesFetchRequest.fetchOffset = offset
        oldMessagesFetchRequest.fetchLimit = count
        
        guard let result = entityManager.entityFetcher.execute(oldMessagesFetchRequest) as? [BaseMessageEntity] else {
            return []
        }
        
        return result
    }
    
    /// All unread messages in this conversation. This might be an empty array.
    public func unreadMessages() -> [BaseMessageEntity] {
        guard let result = entityManager.entityFetcher.execute(unreadMessagesFetchRequest) as? [BaseMessageEntity]
        else {
            return []
        }
        
        return result
    }
    
    public func unreadMessages(limit: Int = 0) -> [BaseMessageEntity] {
        let fetchRequest = limitedUnreadMessagesFetchRequest
        fetchRequest.fetchLimit = limit
        guard let result = entityManager.entityFetcher.execute(fetchRequest) as? [BaseMessageEntity] else {
            return []
        }
        
        return result
    }
    
    /// Rejected group messages
    ///
    /// This only works for group messages, because `rejectedBy` is not set on for rejected 1:1 messages.
    ///
    /// To make this work for 1:1 messages you would have to also set `rejectedBy` in 1:1 rejections or also filter for
    /// the `sendFailed` flag. However, `sendFailed` could also be set if sending failed for other reasons than
    /// rejections.
    ///
    /// - Returns: Messages with at least one `rejectedBy` contact
    public func rejectedGroupMessages() -> [BaseMessageEntity] {
        guard let result = entityManager.entityFetcher.execute(rejectedMessagesFetchRequest) as? [BaseMessageEntity]
        else {
            return []
        }
        
        return result
    }

    /// Most recent display message
    ///
    /// This is the message that should show up in Chats. Some messages are filtered. Thus this might not be the actual
    /// last message in the conversation (use `lastMessage()` for that).
    /// - Returns: Last display message if there is any
    @objc public func lastDisplayMessage() -> BaseMessageEntity? {
        lastMessageExcludesFetchRequest.fetchLimit = 10
        let excludedMessages = entityManager.entityFetcher.execute(lastMessageExcludesFetchRequest)

        let fetchRequest = lastMessagesFetchRequest(exclude: excludedMessages)
        fetchRequest.fetchLimit = 1

        return entityManager.entityFetcher.execute(fetchRequest)?.first as? BaseMessageEntity
    }
    
    /// Last message of the conversation
    /// - Returns: Last message of the conversation if there is any
    func lastMessage() -> BaseMessageEntity? {
        let fetchRequest = lastMessagesFetchRequest(exclude: nil)
        fetchRequest.fetchLimit = 1

        return entityManager.entityFetcher.execute(fetchRequest)?.first as? BaseMessageEntity
    }

    /// Number of media messages in the conversation
    public func mediaCount() -> Int {
        var mediaCount = 0
        mediaCount += entityManager.entityFetcher.executeCount(countFileMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countImageMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countVideoMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countAudioMessagesFetchRequest)
        
        return mediaCount
    }
    
    /// Object IDs of file messages with a `nil` MIME typ. They have no particular order.
    /// - Parameter managedObjectContext: Context to execute fetch request on. If you use the main context you might
    /// deadlock
    /// - Returns: Object IDs of file messages with a `nil` MIME typ
    func fileMessagesWithNoMIMEType(using managedObjectContext: NSManagedObjectContext) -> [NSManagedObjectID] {
        fileMessagesWithNoMIMETypeFetchRequest.resultType = .managedObjectIDResultType
        
        var result = [NSManagedObjectID]()
        
        managedObjectContext.performAndWait {
            do {
                let fetchResult = try managedObjectContext.fetch(fileMessagesWithNoMIMETypeFetchRequest)
                if let fetchResult = fetchResult as? [NSManagedObjectID] {
                    result = fetchResult
                }
            }
            catch {
                DDLogError("Unable to fetch file messages with no MIME type")
            }
        }
        
        return result
    }

    /// Object IDs of messages are deleted.
    /// - Parameter managedObjectContext: Context to execute fetch request on. If you use the main context you might
    /// deadlock
    /// - Returns: Object IDs of messages are deleted
    func messagesWithDeletedMessages(using managedObjectContext: NSManagedObjectContext) -> [NSManagedObjectID] {
        messagesWithDeletedMessagesFetchRequest.resultType = .managedObjectIDResultType

        var result = [NSManagedObjectID]()

        managedObjectContext.performAndWait {
            do {
                let fetchResult = try managedObjectContext.fetch(messagesWithDeletedMessagesFetchRequest)
                if let fetchResult = fetchResult as? [NSManagedObjectID] {
                    result = fetchResult
                }
            }
            catch {
                DDLogError("Unable to fetch deleted messages")
            }
        }

        return result
    }

    // MARK: - Private helper methods
 
    // We prefer `date` to sort messages according to the date they appear on the device and not
    // in the order they are send out. `remoteSentDate` is a fallback in case `date` is not around.
    private func sortDescriptors(ascending: Bool) -> [NSSortDescriptor] {
        [
            NSSortDescriptor(keyPath: \BaseMessageEntity.date, ascending: ascending),
            NSSortDescriptor(keyPath: \BaseMessageEntity.remoteSentDate, ascending: ascending),
        ]
    }
        
    private func newOldMessagesFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: orderAscending)
        return fetchRequest
    }
}
