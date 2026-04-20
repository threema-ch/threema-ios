import CocoaLumberjackSwift
import CoreData
import Foundation

extension EntityFetcher {
    
    @available(swift, obsoleted: 1.0, renamed: "message(id:conversation:isOwn:)", message: "Only use from Objective-C")
    @objc public func ownMessage(with id: Data, in conversation: ConversationEntity) -> BaseMessageEntity? {
        message(with: id, in: conversation, isOwn: true)
    }

    @available(swift, obsoleted: 1.0, renamed: "message(id:conversation:isOwn:)", message: "Only use from Objective-C")
    @objc public func messageObjC(with id: Data, in conversation: ConversationEntity) -> BaseMessageEntity? {
        message(with: id, in: conversation, isOwn: nil)
    }
    
    /// Fetches a message that matches the passed parameters
    /// - Parameters:
    ///   - id: ID of the message
    ///   - conversation: The conversation the message was sent in
    ///   - isOwn: If message was sent by us or from a contact. If nil is passed, we look for both.
    /// - Returns: Optional `BaseMessageEntity`
    public func message(with id: Data, in conversation: ConversationEntity, isOwn: Bool? = nil) -> BaseMessageEntity? {
        var predicates = [messageIDPredicate(id: id), messageConversationPredicate(conversation: conversation)]
        
        if let isOwn {
            predicates.append(messageIsOwnPredicate(isOwn: isOwn))
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        var message: BaseMessageEntity?
        
        managedObjectContext.performAndWait {
            do {
                if let result = try fetchRequest.execute() as? [BaseMessageEntity], let first = result.first {
                    message = first
                }
            }
            catch {
                DDLogError("[EntityFetcher] Failed to fetch own message: \(error)")
            }
        }
        
        return message
    }
    
    // Unread messages
    
    public func unreadMessages(for conversation: ConversationEntity) -> [BaseMessageEntity]? {
        let predicate = messageUnreadPredicate(conversation: conversation)
        return fetchEntities(entityName: "Message", predicate: predicate)
    }
    
    public func unreadMessageCount(for conversation: ConversationEntity) -> Int {
        let predicate = messageUnreadPredicate(conversation: conversation)
        return countEntities(entityName: "Message", predicate: predicate)
    }
    
    // MARK: - Message types
    
    public func textMessageEntities(for conversationEntity: ConversationEntity) -> [TextMessageEntity]? {
        let predicate = messageConversationPredicate(conversation: conversationEntity)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        return fetchEntities(entityName: "TextMessage", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    public func fileMessageEntities(for conversationEntity: ConversationEntity) -> [FileMessageEntity]? {
        let predicate = messageConversationPredicate(conversation: conversationEntity)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        return fetchEntities(entityName: "FileMessage", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    /// If a specific message from the sender has already been delivered.
    /// - Parameters:
    /// - identity: Sender of the message
    /// - messageID: Message ID of the message looking for
    public func isMessageDelivered(from identity: String, with messageID: Data) -> Bool {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.fetchLimit = 1
        // Get delivered message in 1-1 or group conversation
        // Filtering delivered messages in memeory is encrypted DB
        let messagePredicate = NSPredicate(
            format: "(conversation.contact.identity == %@ OR sender.identity == %@) AND id == %@",
            identity,
            identity,
            messageID as CVarArg
        )

        fetchRequest.predicate =
            if !managedObjectContext.usesAdditionallyEncryptedModel {
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    messagePredicate,
                    NSPredicate(format: "delivered == true"),
                ])
            }
            else {
                messagePredicate
            }

        do {
            if !managedObjectContext.usesAdditionallyEncryptedModel {
                return try managedObjectContext.count(for: fetchRequest) > 0
            }
            else {
                guard let messages = try managedObjectContext.fetch(fetchRequest) as? [BaseMessageEntity] else {
                    return false
                }
                return messages.count(where: { $0.delivered == true }) > 0
            }
        }
        catch {
            return false
        }
    }

    /// Returns the date of the oldest message in the DB or `.distantPast`.
    public func dateOfOldestMessage() -> Date {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.fetchLimit = 1
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        var date: Date = .distantPast
        managedObjectContext.performAndWait {
            if let results = try? fetchRequest.execute() as? [BaseMessageEntity], let message = results.first,
               let messageDate = message.date {
                date = messageDate
            }
        }
        return date
    }
    
    // MARK: - Search
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    ///   - starred: Wether to only search in starred messages
    ///   - conversation: `ConversationEntity` to limit the scope to
    ///   - limit: The maximum number of items to fetch for each kind of item. This currently results in |{textMessages
    /// U ballotMessages U fileMessages}| items, i.e. no more than 3 times the fetchLimit
    /// - Returns: Ordered array of matching message object IDs
    public func matchingMessages(
        containing text: String,
        starred: Bool,
        in conversation: ConversationEntity,
        limit: Int
    ) -> [NSManagedObjectID] {
        
        var matchingObjects = [(objectID: NSManagedObjectID, date: Date)]()

        // Basic filtering predicates
        var generalPredicates = [messageConversationPredicate(conversation: conversation)]
        
        if starred {
            if !managedObjectContext.usesAdditionallyEncryptedModel {
                generalPredicates.append(messageMarkerStarredPredicate())
            }
            else {
                // Just return starred messages, searching over other encrypted fields are not supported
                guard let messages = fetchEntities(
                    entityName: "Message",
                    predicate: generalPredicates.first
                ) as? [BaseMessageEntity] else {
                    return []
                }
                return messages.filter { $0.messageMarkers?.star == true && $0.date != nil }
                    .sorted(by: { $0.date! > $1.date! })
                    .compactMap(\.objectID)
            }
        }
        
        // Text Messages
        matchingObjects.append(contentsOf: textMessages(
            containing: text,
            conformingTo: generalPredicates,
            limit: limit
        ))
        
        // Ballot Messages
        matchingObjects.append(contentsOf: ballotMessages(
            containing: text,
            conformingTo: generalPredicates,
            limit: limit
        ))
        
        // Location Messages
        matchingObjects.append(contentsOf: locationMessages(
            containing: text,
            conformingTo: generalPredicates,
            limit: limit
        ))

        // File Messages
        matchingObjects.append(contentsOf: fileMessages(
            containing: text,
            conformingTo: generalPredicates,
            limit: limit
        ))

        // Sorting the results
        let sorted = matchingObjects.sorted {
            $0.date > $1.date
        }
        
        // We only return the NSManagedObjectIDs
        return sorted.map(\.objectID)
    }
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    ///   - start: Start date of search interval, must be in the past of `end`
    ///   - end: End date of search interval
    ///   - scope: Scope limiting the search to some types of conversation
    ///   - types: Array of message tokens to limit search
    /// - Returns: Ordered array of matching message object IDs
    public func matchingMessages(
        containing text: String?,
        between start: Date,
        and end: Date,
        in scope: GlobalSearchConversationScope,
        types: [GlobalSearchMessageToken]
    ) -> [NSManagedObjectID] {
        var matchingObjects = [(objectID: NSManagedObjectID, date: Date)]()
        var filterTypes = types
        
        // Basic filtering predicates
        let noPrivatePredicate = messageNoPrivatePredicate()
        let dateRangePredicate = messageDateRangePredicate(from: start, to: end)
        
        var generalPredicates = [noPrivatePredicate, dateRangePredicate]
        
        // Conversation scope filtering predicate
        switch scope {
        case .all:
            break
        case .oneToOne:
            generalPredicates.append(messageConversationNonGroupPredicate())
        case .groups:
            generalPredicates.append(messageConversationGroupPredicate())
        case .archived:
            generalPredicates.append(messageConversationArchivedPredicate())
        }
        
        // Message markers
        // We remove the marker so we can filter more easily for the type below
        if let index = filterTypes.firstIndex(of: .star) {
            filterTypes.remove(at: index)
            generalPredicates.append(messageMarkerStarredPredicate())
        }
        
        // Text Messages
        if filterTypes.isEmpty || types.contains(.text) {
            matchingObjects.append(contentsOf: textMessages(containing: text, conformingTo: generalPredicates))
        }
        
        // Ballot Messages
        if filterTypes.isEmpty || types.contains(.poll) {
            matchingObjects.append(contentsOf: ballotMessages(containing: text, conformingTo: generalPredicates))
        }
        
        // Location Messages
        if filterTypes.isEmpty || types.contains(.location) {
            matchingObjects.append(contentsOf: locationMessages(containing: text, conformingTo: generalPredicates))
        }
        
        // File Messages
        if filterTypes.isEmpty || types.contains(.caption) {
            matchingObjects.append(contentsOf: fileMessages(containing: text, conformingTo: generalPredicates))
        }
        
        // Sorting the results
        let sorted = matchingObjects.sorted {
            $0.date > $1.date
        }
        
        // We only return the NSManagedObjectIDs
        return sorted.map(\.objectID)
    }
    
    /// Use this function just for migration!
    public func messagesWithUserAckDate() -> [BaseMessageEntity]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = NSPredicate(format: "userackDate != nil")
        
        let result = managedObjectContext.performAndWait {
            try? fetchRequest.execute() as? [BaseMessageEntity]
        }
        return result
    }
    
    /// Use this function just for migration!
    public func messagesWithUserGroupReactions() -> [BaseMessageEntity]? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = NSPredicate(format: "groupDeliveryReceipts != nil")
        
        let result = managedObjectContext.performAndWait {
            try? fetchRequest.execute() as? [BaseMessageEntity]
        }
        return result
    }
    
    public func messageCount(for contactEntity: ContactEntity) -> Int {
        let predicate = messageSenderPredicate(contactEntity: contactEntity)
        return countEntities(entityName: "Message", predicate: predicate)
    }
    
    public func messageCount(for contactEntity: ContactEntity, in conversationEntity: ConversationEntity) -> Int {
        let contactPredicate = messageSenderPredicate(contactEntity: contactEntity)
        let conversationsPredicate = messageConversationPredicate(conversation: conversationEntity)

        return countEntities(
            entityName: "Message",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [contactPredicate, conversationsPredicate])
        )
    }
    
    public func mediaMessageCount(for conversationEntity: ConversationEntity) -> Int {
        let predicate = messageConversationPredicate(conversation: conversationEntity)
        let imageCount = countEntities(entityName: "ImageMessage", predicate: predicate)
        let videoCount = countEntities(entityName: "VideoMessage", predicate: predicate)
        let fileCount = countEntities(entityName: "FileMessage", predicate: predicate)

        return imageCount + videoCount + fileCount
    }
    
    public func starredMessageCount(for conversationEntity: ConversationEntity) -> Int {
        if !managedObjectContext.usesAdditionallyEncryptedModel {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                messageMarkerStarredPredicate(),
                messageConversationPredicate(conversation: conversationEntity),
            ])
            return countEntities(entityName: "Message", predicate: predicate)
        }
        else {
            let predicate = messageConversationPredicate(conversation: conversationEntity)
            guard let messages = fetchEntities(entityName: "Message", predicate: predicate) as? [BaseMessageEntity]
            else {
                return 0
            }
            return messages.count(where: { $0.messageMarkers?.star == true })
        }
    }
    
    // MARK: - Global Search

    private func textMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate],
        limit: Int = 0
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Text
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "text contains[cd] %@", text))
        }
        
        return searchMessages(
            of: "TextMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates),
            limit: 0
        )
    }
    
    private func ballotMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate],
        limit: Int = 0
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Title
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "ballot.title contains[cd] %@", text))
        }
        
        return searchMessages(
            of: "BallotMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates),
            limit: 0
        )
    }
    
    private func locationMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate],
        limit: Int = 0
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Name or Address
        if let text, text != "" {
            allPredicates
                .append(NSPredicate(format: "poiName contains[cd] %@ || poiAddress contains[cd] %@", text, text))
        }
        
        return searchMessages(
            of: "LocationMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates),
            limit: limit
        )
    }
    
    private func fileMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate],
        limit: Int = 0
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Name or Caption
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "fileName contains[cd] %@ || caption contains[cd] %@", text, text))
        }
        
        return searchMessages(
            of: "FileMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates),
            limit: limit
        )
    }
    
    private func searchMessages(
        of entityName: String,
        with compoundPredicate: NSCompoundPredicate,
        limit: Int = 0
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        
        var matchingIDs = [(objectID: NSManagedObjectID, date: Date)]()
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)

        // We only fetch the managed object ID and date. The latter is only used for sorting the results.
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType

        var propertiesToFetch: [Any] = [objectIDExpression]
        propertiesToFetch.append("date")
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = compoundPredicate
        fetchRequest.fetchLimit = limit
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        
        do {
            managedObjectContext.performAndWait {
                if let results = try? fetchRequest.execute() as? [[String: Any]], !results.isEmpty {
                    for result in results {
                        guard let date = result["date"] as? Date,
                              let objectID = result["objectID"] as? NSManagedObjectID else {
                            continue
                        }
                        
                        matchingIDs.append((objectID, date))
                    }
                }
            }
        }
        return matchingIDs
    }
    
    // MARK: - Predicates
    
    func messageNoPrivatePredicate() -> NSPredicate {
        NSPredicate(format: "conversation.category != %d", ConversationEntity.Category.private.rawValue)
    }
    
    func messageConversationPredicate(conversation: ConversationEntity) -> NSPredicate {
        NSPredicate(format: "conversation == %@", conversation)
    }
    
    func messageIDPredicate(id: Data) -> NSPredicate {
        NSPredicate(format: "id == %@", id as CVarArg)
    }
    
    func messageIsOwnPredicate(isOwn: Bool) -> NSPredicate {
        NSPredicate(format: "isOwn == %@", isOwn as NSNumber)
    }
    
    func messageDateRangePredicate(from start: Date, to end: Date) -> NSPredicate {
        let startDate = start as NSDate
        let endDate = end as NSDate
        
        return NSPredicate(format: "date > %@ && date < %@", startDate, endDate)
    }
    
    func messageConversationGroupPredicate() -> NSPredicate {
        NSPredicate(format: "conversation.groupId != nil")
    }
    
    func messageConversationNonGroupPredicate() -> NSPredicate {
        NSPredicate(format: "conversation.groupId == nil")
    }
    
    func messageConversationArchivedPredicate() -> NSPredicate {
        NSPredicate(
            format: "conversation.visibility == %d",
            ConversationEntity.Visibility.archived.rawValue
        )
    }
    
    func messageMarkerStarredPredicate() -> NSPredicate {
        NSPredicate(format: "messageMarkers.star == 1")
    }
    
    func messageUnreadPredicate(conversation: ConversationEntity) -> NSPredicate {
        NSPredicate(format: "isOwn == NO AND read == NO AND conversation == %@", conversation)
    }
    
    func messageSenderPredicate(contactEntity: ContactEntity) -> NSPredicate {
        NSPredicate(format: "sender == %@", contactEntity)
    }
}
