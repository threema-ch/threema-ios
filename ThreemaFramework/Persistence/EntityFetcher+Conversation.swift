import CocoaLumberjackSwift
import CoreData
import Foundation
import OrderedCollections
import ThreemaEssentials

extension EntityFetcher {
    
    /// Fetches all persisted `ConversationEntity`
    /// - Returns: Optional array of `ConversationEntity`
    @objc public func conversationEntities() -> [ConversationEntity]? {
        fetchEntities(entityName: "Conversation")
    }

    /// Fetches the IDs of conversation entities that are associated with groups or distribution lists or
    /// conversation contact IDs if the conversations are associated with contacts, that match the specified filtering
    /// criteria.
    ///
    /// The results are ordered by visibility (descending), lastUpdate (descending), and last message date
    /// (descending). The fetch runs synchronously on the Core Data context and returns an empty list on failure.
    ///
    /// - Parameters:
    ///   - excludeArchived: Exclude archived conversations. Default is `false`.
    ///   - excludePrivate: Exclude private conversations. Default is `false`.
    ///   - excludeWithoutLastUpdate: Exclude conversations without last update. Default is `false`.
    ///
    /// - Returns: An `Array` of `NSManagedObjectID` for the matching conversation / contact entities.
    public func conversationOrContactIDs(
        excludeArchived: Bool = false,
        excludePrivate: Bool = false,
        excludeWithoutLastUpdate: Bool = false
    ) -> [NSManagedObjectID] {
        managedObjectContext.performAndWait {
            do {
                let excludeDistributionLists = !ThreemaEnvironment.distributionListsActive
                let request = NSFetchRequest<ConversationEntity>(entityName: "Conversation")

                request.predicate = .and(
                    excludeArchived ? .not(.conversationIsArchived) : nil,
                    excludePrivate ? .not(.conversationIsPrivate) : nil,
                    excludeWithoutLastUpdate ? .not(.conversationHasLastUpdate) : nil,
                    excludeDistributionLists ? .not(.conversationIsDistributionList) : nil
                )

                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \ConversationEntity.visibility, ascending: false),
                    NSSortDescriptor(keyPath: \ConversationEntity.lastUpdate, ascending: false),
                    NSSortDescriptor(keyPath: \ConversationEntity.lastMessage?.date, ascending: false),
                ]

                request.includesPropertyValues = false // We fetch only the IDs
                request.returnsObjectsAsFaults = true
                request.relationshipKeyPathsForPrefetching = nil

                let conversations = try managedObjectContext.fetch(request)

                // Use ordered set to prevent duplicate entries (e.g. when (unexpected) two 1:1 conversations with the
                // same contact exist)
                var result = OrderedSet<NSManagedObjectID>(minimumCapacity: conversations.count)

                for conversation in conversations {
                    if !conversation.isGroup, let objectID = conversation.contact?.objectID {
                        result.append(objectID)
                    }
                    else {
                        result.append(conversation.objectID)
                    }
                }

                return result.elements
            }
            catch {
                DDLogError("[EntityFetcher] Failed to fetch items IDs. Error: \(error)")
                return []
            }
        }
    }

    /// Fetches a `ConversationEntity` with an `NSManagedObjectID`
    /// - Returns: Optional `ConversationEntity`
    public func conversationEntity(with objectID: NSManagedObjectID) -> ConversationEntity? {
        var result: ConversationEntity?
        do {
            result = try managedObjectContext.existingObject(with: objectID) as? ConversationEntity
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch ConversationEntity with id: \(objectID). Error: \(error)")
        }
        return result
    }

    /// Fetches all `ConversationEntity` that are not archived
    /// - Returns: Optional array of `ConversationEntity`
    public func notArchivedConversationEntities() -> [ConversationEntity]? {
        fetchEntities(entityName: "Conversation", predicate: .not(.conversationIsArchived))
    }
    
    /// Fetches all `ConversationEntity` that belong to groups
    /// - Returns: Optional array of `ConversationEntity`
    public func groupConversationEntities() -> [ConversationEntity]? {
        fetchEntities(entityName: "Conversation", predicate: .conversationIsGroup)
    }
    
    /// Fetches all `ConversationEntity` that are in the `typing` state and the indicator state has timeout.
    /// - Returns: Array of `ConversationEntity`
    ///
    /// - Note: Both `typing` and `lastTypingStart` are transient properties and therefore cannot be filtered
    ///   by the SQLite store. We fetch all conversations and filter in-memory to guarantee correct results.
    @objc public func typingConversationEntities(timeoutDate: Date) -> [ConversationEntity] {
        let all: [ConversationEntity] = fetchEntities(entityName: "Conversation") ?? []
        return all.filter {
            $0.typing.boolValue && ($0.lastTypingStart.map { $0 < timeoutDate } ?? false)
        }
    }

    /// Fetches all persisted `ConversationEntity` that are private
    /// - Returns: Optional array of `ConversationEntity`
    public func privateConversationEntities() -> [ConversationEntity]? {
        fetchEntities(entityName: "Conversation", predicate: .conversationIsPrivate)
    }
    
    /// Fetches all persisted `ConversationEntity` and sorts them
    /// - Returns: Optional array of `ConversationEntity`
    public func conversationEntitiesSorted() -> [ConversationEntity]? {
        let visibilityDescriptor = NSSortDescriptor(key: "visibility", ascending: false)
        let lastUpdateDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        let lastMessageDateDescriptor = NSSortDescriptor(key: "lastMessage.date", ascending: false)
                
        return fetchEntities(
            entityName: "Conversation",
            sortDescriptors: [visibilityDescriptor, lastUpdateDescriptor, lastMessageDateDescriptor]
        )
    }
    
    /// Fetches all `ConversationEntity` that belong to groups that are active. Should be executed in a `perform()`
    /// block.
    /// - Returns: Optional array of `ConversationEntity`
    func activeGroupConversationEntities() -> [ConversationEntity]? {
        // Fetch all group entities
        let activeGroupEntities = activeGroupEntities()
        guard let activeGroupEntities, !activeGroupEntities.isEmpty else {
            return nil
        }
        
        // Fetch all group conversations
        let groupConversations = groupConversationEntities()
        guard let groupConversations, !groupConversations.isEmpty else {
            return nil
        }
        
        var activeGroupConversationEntities: [ConversationEntity] = []
        
        // If we have a groupID and creator identity match, we add it
        for conversationEntity in groupConversations {
            let matchingEntity = activeGroupEntities.first { groupEntity in
                let idMatch = conversationEntity.groupID == groupEntity.groupID
                let creatorMatch = conversationEntity.contact?.identity == groupEntity.groupCreator
                
                return idMatch && creatorMatch
            }
            if matchingEntity != nil {
                activeGroupConversationEntities.append(conversationEntity)
            }
        }
        
        return !activeGroupConversationEntities.isEmpty ? activeGroupConversationEntities : nil
    }
    
    /// Fetches a `ConversationEntity` for a given ID of a contact
    /// - Parameter identity: Identity of the contact
    /// - Returns: `ConversationEntity` if it exists
    @objc public func conversationEntity(for identity: String) -> ConversationEntity? {
        fetchEntity(
            entityName: "Conversation",
            predicate: .conversationWithContactIdentity(identity)
        )
    }
    
    @available(*, deprecated, renamed: "conversationEntity(for:)")
    @objc public func groupConversationEntity(
        for groupID: Data,
        creatorID: String?,
        myIdentity: String?
    ) -> ConversationEntity? {
        guard let myIdentity else {
            return nil
        }
        
        let groupIdentity = GroupIdentity(id: groupID, creatorID: creatorID ?? myIdentity)
        return conversationEntity(for: groupIdentity, myIdentity: myIdentity)
    }
    
    /// Fetches a group `ConversationEntity` for a given `GroupIdentity`
    /// - Parameter groupIdentity: The identity of the group
    /// - Returns: Group-`ConversationEntity` if it exists
    public func conversationEntity(for groupIdentity: GroupIdentity, myIdentity: String?) -> ConversationEntity? {
        fetchEntity(
            entityName: "Conversation",
            predicate: .conversationGroup(
                identity: groupIdentity.creator.rawValue,
                id: groupIdentity.id,
                myIdentity: myIdentity
            )
        )
    }
    
    @available(*, deprecated, message: "This is deprecated and will be removed together with the web client code.")
    public func legacyConversationEntity(for groupID: Data?) -> ConversationEntity? {
        guard let groupID else {
            return nil
        }
        return fetchEntity(
            entityName: "Conversation",
            predicate: .legacyConversationWithGroupID(groupID)
        )
    }
    
    public func conversationEntity(for distributionListID: Int) -> ConversationEntity? {
        fetchEntity(
            entityName: "Conversation",
            predicate: .conversationWithDistributionListID(distributionListID)
        )
    }
    
    public func conversationEntities(for member: ContactEntity) -> [ConversationEntity]? {
        fetchEntities(
            entityName: "Conversation",
            predicate: .conversationHasMember(member)
        )
    }
    
    @objc public func filteredGroupConversationEntities(
        by words: [String],
        excludeArchived: Bool = false,
        excludePrivate: Bool = false,
        excludeWithoutLastUpdate: Bool = false
    ) -> [ConversationEntity] {
        do {
            var groupNamePredicates = [NSPredicate]()
            for word in words where !word.isEmpty {
                let predicate = NSPredicate(format: "groupName contains[cd] %@", word)
                groupNamePredicates.append(predicate)
            }
            let request = NSFetchRequest<ConversationEntity>(entityName: "Conversation")
            request.fetchBatchSize = 100
            request.predicate = .and(
                .and(
                    .conversationIsGroup,
                    excludeArchived ? .not(.conversationIsArchived) : nil,
                    excludePrivate ? .not(.conversationIsPrivate) : nil,
                    excludeWithoutLastUpdate ? .not(.conversationHasLastUpdate) : nil
                ),
                .and(groupNamePredicates)
            )
            let conversationEntities = try managedObjectContext.performAndWait {
                try managedObjectContext.fetch(request)
            }
            return conversationEntities
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch ConversationEntities. Error: \(error)")
            return []
        }
    }

    public func archivedConversationEntitiesCount() -> Int {
        countEntities(entityName: "Conversation", predicate: .conversationIsArchived)
    }
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates such as group or contact name and ThreemaID
    ///   - scope: Scope limiting the search to some types of conversation
    /// - Returns: Ordered array of matching conversations object IDs
    public func matchingConversationsForGlobalSearch(
        containing text: String,
        scope: GlobalSearchConversationScope,
        hidePrivateChats: Bool
    ) -> [NSManagedObjectID] {
        
        var intermediaryPredicate: NSPredicate
        
        switch scope {
        case .all:
            intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                .conversationWithGroupName(text),
                .conversationWithFirstName(text),
                .conversationWithLastName(text),
                .conversationWithNickName(text),
                .conversationContainsContactIdentity(identity: text),
            ])
        case .oneToOne:
            intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                .conversationWithFirstName(text),
                .conversationWithLastName(text),
                .conversationWithNickName(text),
                .conversationContainsContactIdentity(identity: text),
            ])
        case .groups:
            intermediaryPredicate = .conversationWithGroupName(text)
        case .archived:
            let allPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                .conversationWithGroupName(text),
                .conversationWithFirstName(text),
                .conversationWithLastName(text),
                .conversationWithNickName(text),
                .conversationContainsContactIdentity(identity: text),
            ])
            intermediaryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                allPredicate,
                .conversationIsArchived,
            ])
        }
        
        let finalPredicate: NSPredicate =
            if hidePrivateChats {
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    intermediaryPredicate,
                    .not(.conversationIsPrivate),
                ])
            }
            else {
                intermediaryPredicate
            }
        
        var matchingIDs = [(
            objectID: NSManagedObjectID,
            date: Date,
            visibility: ConversationEntity.Visibility
        )]()
        let sortDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        
        // We only fetch the managed object ID, last update and visibility. The latter two are only used for sorting the
        // results.
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        var propertiesToFetch: [Any] = [objectIDExpression]
        propertiesToFetch.append("lastUpdate")
        propertiesToFetch.append("visibility")
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.predicate = finalPredicate
        fetchRequest.fetchLimit = 0
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        fetchRequest.returnsDistinctResults = true
        
        do {
            managedObjectContext.performAndWait {
                if let results = try? fetchRequest.execute() as? [[String: Any]], !results.isEmpty {
                    for result in results {
                        guard let date = result["lastUpdate"] as? Date,
                              let objectID = result["objectID"] as? NSManagedObjectID,
                              let visibility = ConversationEntity
                              .Visibility(rawValue: (result["visibility"] as? Int) ?? 0)
                        else {
                            continue
                        }
                        
                        matchingIDs.append((objectID, date, visibility))
                    }
                }
            }
        }
        
        // We use a custom sort, to achieve the sort order of pinned, normal, archived.
        let sortedIDs = matchingIDs.sorted(by: { a, b in
            if a.visibility == .pinned,
               b.visibility == .default || b.visibility == .archived {
                false
            }
            else if a.visibility == .default,
                    b.visibility == .pinned {
                true
            }
            else if a.visibility == .default,
                    b.visibility == .archived {
                false
            }
            else if a.visibility == .archived,
                    b.visibility == .pinned ||
                    b.visibility == .default {
                false
            }
            else {
                a.date > b.date
            }
        })
        
        // We only return the NSManagedObjectIDs
        return sortedIDs.map(\.objectID)
    }
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    /// - Returns: Ordered array of matching conversations object IDs
    public func matchingConversationsForContactListSearch(
        containing text: String
    ) -> [NSManagedObjectID] {
        // We only fetch the managed object ID
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        let propertiesToFetch: [Any] = [objectIDExpression]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.predicate = .and(
            .conversationWithGroupName(text),
            .not(.conversationIsPrivate)
        )
        fetchRequest.fetchLimit = 0
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        fetchRequest.returnsDistinctResults = true
        
        var matchingIDs: [NSManagedObjectID] = []
        
        managedObjectContext.performAndWait {
            if let results = try? fetchRequest.execute() as? [[String: Any]], !results.isEmpty {
                for result in results {

                    guard let objectID = result["objectID"] as? NSManagedObjectID else {
                        continue
                    }
                    matchingIDs.append(objectID)
                }
            }
        }
        
        return matchingIDs
    }
}
