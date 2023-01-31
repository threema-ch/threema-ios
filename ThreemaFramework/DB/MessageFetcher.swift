//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
    internal var messagesFetchRequest: NSFetchRequest<BaseMessage> {
        let fetchRequest = NSFetchRequest<BaseMessage>(entityName: entityName)
        
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
    
    private let conversation: Conversation
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
    
    private lazy var limitedUnreadMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationUnreadPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequest
    }()
    
    private lazy var newestUnreadMessageFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationUnreadPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }()
    
    private lazy var oldestUnreadMessageFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationUnreadPredicate
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = sortDescriptors(ascending: true)
        return fetchRequest
    }()
    
    private lazy var lastMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: false)
        return fetchRequest
    }()
    
    private lazy var countFileMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: fileEntityName)
        fetchRequest.predicate = conversationFilePredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countImageMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: imageEntityName)
        fetchRequest.predicate = conversationPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countVideoMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: videoEntityName)
        fetchRequest.predicate = conversationPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    private lazy var countAudioMessagesFetchRequest: NSFetchRequest<NSFetchRequestResult> = {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: audioEntityName)
        fetchRequest.predicate = conversationPredicate
        // Sorting doesn't matter for counting
        return fetchRequest
    }()
    
    // MARK: - Lifecycle
    
    /// Initialize for a fixed conversation
    /// - Parameters:
    ///   - conversation: Conversation's messages you want to access
    ///   - entityManager: Manager used for fetch requests
    @objc public init(for conversation: Conversation, with entityManager: EntityManager) {
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
    @objc public func count() -> Int {
        // This might be 0 before the first save after the migration to V35
        entityManager.entityFetcher.executeCount(countFetchRequest)
    }
    
    /// Number of messages in conversation after the passed date
    /// - Parameter date: All messages with a `date` or `remoteSentDate` newer than this are counted
    /// - Returns: Number of messages in this conversation after the passed date
    public func numberOfMessages(after date: Date) -> Int {
        let fetchRequest = dateFetchRequest
        
        let datePredicates = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "%K > %@", #keyPath(BaseMessage.date), date as NSDate),
            NSPredicate(format: "%K > %@", #keyPath(BaseMessage.remoteSentDate), date as NSDate),
        ])
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            conversationPredicate,
            datePredicates,
        ])
        
        return entityManager.entityFetcher.executeCount(dateFetchRequest)
    }
    
    /// Load messages starting at `offset`. Up to `count` messages are returned.
    /// - Parameters:
    ///   - offset: Offset of first message to load
    ///   - count: Maximum number of messages to load
    /// - Returns: Up to `count` messages. This is empty if there are no messages.
    @objc public func messages(at offset: Int, count: Int) -> [BaseMessage] {
        oldMessagesFetchRequest.fetchOffset = offset
        oldMessagesFetchRequest.fetchLimit = count
        
        guard let result = entityManager.entityFetcher.execute(oldMessagesFetchRequest) as? [BaseMessage] else {
            return []
        }
        
        return result
    }
    
    /// All unread messages in this conversation. This might be an empty array.
    public func unreadMessages() -> [BaseMessage] {
        guard let result = entityManager.entityFetcher.execute(unreadMessagesFetchRequest) as? [BaseMessage] else {
            return []
        }
        
        return result
    }
    
    public func unreadMessages(limit: Int = 0) -> [BaseMessage] {
        let fetchRequest = limitedUnreadMessagesFetchRequest
        fetchRequest.fetchLimit = limit
        guard let result = entityManager.entityFetcher.execute(fetchRequest) as? [BaseMessage] else {
            return []
        }
        
        return result
    }
    
    /// Newest Unread Message
    public func newestUnreadMessage() -> BaseMessage? {
        guard let result = entityManager.entityFetcher.execute(newestUnreadMessageFetchRequest) as? [BaseMessage] else {
            return nil
        }
        
        return result.first
    }
    
    /// Oldest Unread Message
    public func oldestUnreadMessage() -> BaseMessage? {
        guard let result = entityManager.entityFetcher.execute(oldestUnreadMessageFetchRequest) as? [BaseMessage] else {
            return nil
        }
        
        return result.first
    }
    
    /// Most recent message
    @objc public func lastMessage() -> BaseMessage? {
        lastMessagesFetchRequest.fetchLimit = 1
        
        guard let result = entityManager.entityFetcher.execute(lastMessagesFetchRequest).first else {
            return nil
        }
        
        return result as? BaseMessage
    }
    
    /// Number of media messages in the conversation
    @objc public func mediaCount() -> Int {
        var mediaCount = 0
        mediaCount += entityManager.entityFetcher.executeCount(countFileMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countImageMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countVideoMessagesFetchRequest)
        mediaCount += entityManager.entityFetcher.executeCount(countAudioMessagesFetchRequest)
        
        return mediaCount
    }
    
    /// Most recent 20 messages
    @available(*, deprecated, message: "This will be removed with Old_ChatViewController")
    @objc public func old_last20Messages() -> [BaseMessage] {
        lastMessagesFetchRequest.fetchLimit = 20
        
        guard let result = entityManager.entityFetcher.execute(lastMessagesFetchRequest) as? [BaseMessage] else {
            return []
        }
        
        return result
    }
    
    // MARK: - Private helper methods
 
    // We prefer `date` to sort messages according to the date they appear on the device and not
    // in the order they are send out. `remoteSentDate` is a fallback in case `date` is not around.
    private func sortDescriptors(ascending: Bool) -> [NSSortDescriptor] {
        [
            NSSortDescriptor(keyPath: \BaseMessage.date, ascending: ascending),
            NSSortDescriptor(keyPath: \BaseMessage.remoteSentDate, ascending: ascending),
        ]
    }
        
    private func newOldMessagesFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = conversationPredicate
        fetchRequest.sortDescriptors = sortDescriptors(ascending: orderAscending)
        return fetchRequest
    }
}
