import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaEssentials

extension EntityFetcher {
        
    /// Fetches all persisted `ContactEntity`
    /// - Returns: Optional array of `ContactEntity`
    @objc public func contactEntities() -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: nil)
    }
    
    @objc public func gatewayContactEntities() -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: .contactIsGateway)
    }

    /// Fetches a `ContactEntity` with an `NSManagedObjectID`
    /// - Returns: Optional `ContactEntity`
    public func contactEntity(with objectID: NSManagedObjectID) -> ContactEntity? {
        var result: ContactEntity?
        do {
            result = try managedObjectContext.existingObject(with: objectID) as? ContactEntity
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch ContactEntity with id: \(objectID). Error: \(error)")
        }
        return result
    }

    @objc public func contactEntity(for identity: String) -> ContactEntity? {
        fetchEntity(entityName: "Contact", predicate: .contactWithIdentity(identity))
    }
    
    /// Returns all `ContactEntity` for a given ID
    /// Note: Normally we do not allow multiple contacts to have the same ID, but in the past there were some issues
    /// where this could happen.
    /// - Parameter identity: Identity of the contacts
    /// - Returns: Optional array of `ContactEntity`
    public func contactEntities(for identity: String) -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: .contactWithIdentity(identity))
    }
    
    @objc public func contactEntitiesWithFeatureMaskNil() -> [ContactEntity]? {
        fetchEntities(
            entityName: "Contact",
            predicate: .contactWithNullFeatureMask(
                encrypted: managedObjectContext.usesAdditionallyEncryptedModel
            )
        )
    }
    
    @objc public func contactEntitiesWithCustomReadReceipt() -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: .contactWithCustomReadReceipt)
    }
    
    public func contactEntitiesWithCustomTypingIndicator() -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: .contactWithCustomTypingIndicator)
    }
    
    /// A set of the identities of all contacts
    /// This doesn't fetch the full `ContactEntity` managed objects. Thus this is about 3x faster than using
    /// `allContacts` and reading all identities.
    /// - Returns: A set of identity strings. If there are no contacts the set is empty.
    @objc public func contactIdentities() -> Set<String> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        guard let description = NSEntityDescription.entity(forEntityName: "Contact", in: managedObjectContext),
              let property = description.propertiesByName["identity"] else {
            assertionFailure("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            DDLogError("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            return []
        }
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [property]
        fetchRequest.returnsDistinctResults = true
        
        var identities: Set<String> = []
        do {
            try managedObjectContext.performAndWait {
                
                if let results = try fetchRequest.execute() as? [[String: String]], !results.isEmpty {
                    for result in results {
                        if let id = result["identity"] {
                            identities.insert(id)
                        }
                    }
                }
            }
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch contact identities: \(error)")
        }
        
        return identities
    }
    
    /// Tries to fetch a `ContactEntity` that has the ID of the local user
    /// - Returns: The entity if it exists
    public func ownIdentityContactEntity(myIdentity: String?) -> ContactEntity? {
        guard let myIdentity else {
            return nil
        }
        return fetchEntity(entityName: "Contact", predicate: .contactWithIdentity(myIdentity))
    }
    
    ///  Checks if there are duplicate contacts in the contact table.
    /// - Returns: Set containing the identities of duplicate contacts if there are any.
    public func duplicateContactIdentities() -> Set<String>? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        guard let description = NSEntityDescription.entity(forEntityName: "Contact", in: managedObjectContext),
              let property = description.propertiesByName["identity"] else {
            assertionFailure("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            DDLogError("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            return []
        }
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [property]
        fetchRequest.returnsDistinctResults = false
        
        var identities: [String] = []
        do {
            try managedObjectContext.performAndWait {
                
                if let results = try fetchRequest.execute() as? [[String: String]], !results.isEmpty {
                    for result in results {
                        if let id = result["identity"] {
                            identities.append(id)
                        }
                    }
                }
            }
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch contact identities: \(error)")
            return []
        }
        
        let duplicates = Dictionary(grouping: identities, by: { $0 }).filter { $1.count > 1 }.keys
        return duplicates.isEmpty ? nil : Set(duplicates)
    }
    
    /// Used to find all valid contact identities that have a 1:1 conversation with `lastUpdate` set or are part of
    /// group that is not marked as left
    /// See _Application Setup Steps_ of Threema Protocols for full specification of `solicited-contacts`.
    /// - Returns: A set of identity strings. If there are no matches the set is empty.
    public func solicitedContactIdentities() -> Set<String> {
        // Fetch relevant conversations
        let nonGroupConversationsWithLastUpdatePredicate = NSPredicate(format: "groupId == nil AND lastUpdate != nil")
        let nonGroupConversationsEntitiesWithLastUpdate = fetchEntities(
            entityName: "Conversation",
            predicate: nonGroupConversationsWithLastUpdatePredicate
        ) ?? []
        let activeGroupConversations = activeGroupConversationEntities() ?? []
        
        // Prepare predicates
        let validContactsOnlyPredicate = NSPredicate(format: "state != %d", ContactEntity.ContactState.invalid.rawValue)
        let contactsWithActiveOneToOneConversationPredicate = NSPredicate(
            format: "SUBQUERY(conversations, $conversation, $conversation IN %@).@count > 0",
            nonGroupConversationsEntitiesWithLastUpdate
        )
        let contactsWithActiveGroupConversationPredicate = NSPredicate(
            format: "SUBQUERY(groupConversations, $conversation, $conversation IN %@).@count > 0",
            activeGroupConversations
        )
        
        let conversationsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            contactsWithActiveOneToOneConversationPredicate,
            contactsWithActiveGroupConversationPredicate,
        ])
        
        // Prepare contact fetch request
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            validContactsOnlyPredicate,
            conversationsPredicate,
        ])
        guard let description = NSEntityDescription.entity(forEntityName: "Contact", in: managedObjectContext),
              let property = description.propertiesByName["identity"] else {
            assertionFailure("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            DDLogError("[EntityFetcher] Failed to load NSEntityDescription for 'Contact'")
            return []
        }
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [property]
        fetchRequest.returnsDistinctResults = true
        
        // Fetch
        var identities: Set<String> = []
        do {
            try managedObjectContext.performAndWait {
                
                if let results = try fetchRequest.execute() as? [[String: String]], !results.isEmpty {
                    for result in results {
                        if let id = result["identity"] {
                            identities.insert(id)
                        }
                    }
                }
            }
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch solicited contact identities: \(error)")
        }
        
        return identities
    }
    
    @objc public func filteredContactEntities(
        by words: [String],
        for type: ContactType,
        of list: ListType,
        with members: Set<ContactEntity>?,
        hideStaleContacts: Bool,
        sortOrderFirstName: Bool
    ) -> [ContactEntity]? {
        var predicates: [NSPredicate] = [.contactIsVisible]

        switch type {
        case .all:
            break
        case .noGateway:
            let predicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(predicate)
        case .onlyGateway:
            let predicate = NSPredicate(format: "identity beginswith '*'")
            predicates.append(predicate)
        case .noEchoEcho:
            let predicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(predicate)
        case .noGatewayNoEchoEcho:
            let echoPredicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(echoPredicate)
            let gatewayPredicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(gatewayPredicate)
        }
        
        if hideStaleContacts {
            predicates.append(.contactIsActive)
        }
        
        switch list {
        case .contacts:
            let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: false))
            predicates.append(predicate)
        case .work:
            let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: true))
            predicates.append(predicate)
        case .contactsAndWork:
            break
        }
        
        for word in words where !word.isEmpty {
            let predicate = NSPredicate(
                format: "firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@ or jobTitle contains[cd] %@ or department contains[cd] %@",
                word,
                word,
                word,
                word,
                word,
                word
            )
            predicates.append(predicate)
        }
        
        var allPredicates = [NSCompoundPredicate(andPredicateWithSubpredicates: predicates) as NSPredicate]
        
        if hideStaleContacts, let members, !members.isEmpty {
            for member in members {
                var contactPredicates = [NSPredicate]()
                contactPredicates.append(.contactWithIdentity(member.identity))

                for word in words where !word.isEmpty {
                    let predicate = NSPredicate(
                        format: "firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@",
                        word,
                        word,
                        word,
                        word
                    )
                    predicates.append(predicate)
                }
                allPredicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: contactPredicates))
            }
        }
        
        let finalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: allPredicates)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")

        fetchRequest.predicate = finalPredicate
        fetchRequest.fetchBatchSize = 100
        let sortDescriptors = nameSortDescriptors(sortOrderFirstName: sortOrderFirstName)
        fetchRequest.sortDescriptors = sortDescriptors
        
        return execute(fetchRequest) as? [ContactEntity]
    }
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    /// - Returns: Ordered array of matching contacts object IDs
    public func matchingContactsForContactListSearch(
        containing text: String,
        hideStaleContacts: Bool
    ) -> [NSManagedObjectID] {
        
        let searchWords = text.components(separatedBy: .whitespaces)
        
        let predicates: [NSPredicate] =
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.name) +
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.id) +
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.titleDepartmentCSI)

        let intermediaryPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: predicates
        )
        
        var visibilityPredicates: [NSPredicate] = [.contactIsVisible]
        if hideStaleContacts {
            visibilityPredicates.append(.contactIsActive)
        }
        
        let finalPredicate =
            NSCompoundPredicate(andPredicateWithSubpredicates: [intermediaryPredicate] + visibilityPredicates)
        
        // We only fetch the managed object ID
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        let propertiesToFetch: [Any] = [objectIDExpression]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchRequest.predicate = finalPredicate
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
    
    public func matchingContactIDsForContactListSearch(
        containing text: String,
        hideStaleContacts: Bool
    ) -> [(objectID: NSManagedObjectID, identity: ThreemaIdentity)] {
        
        let searchWords = text.components(separatedBy: .whitespaces)
        
        let predicates: [NSPredicate] =
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.name) +
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.id) +
            NSPredicate.predicate(from: searchWords, for: NSPredicate.PredicateFormat.titleDepartmentCSI)

        let intermediaryPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: predicates
        )
        
        var visibilityPredicates: [NSPredicate] = [.contactIsVisible]
        if hideStaleContacts {
            visibilityPredicates.append(.contactIsActive)
        }
        
        let finalPredicate =
            NSCompoundPredicate(andPredicateWithSubpredicates: [intermediaryPredicate] + visibilityPredicates)
        
        // We fetch the managed objectID
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        // We also add the identity to be fetched
        let propertiesToFetch: [Any] = [objectIDExpression, "identity"]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchRequest.predicate = finalPredicate
        fetchRequest.fetchLimit = 0
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        fetchRequest.returnsDistinctResults = true
        
        var matchingIDs: [(NSManagedObjectID, ThreemaIdentity)] = []
        
        managedObjectContext.performAndWait {
            if let results = try? fetchRequest.execute() as? [[String: Any]], !results.isEmpty {
                for result in results {
                    guard
                        let objectID = result["objectID"] as? NSManagedObjectID,
                        let identity = result["identity"] as? String
                    else {
                        continue
                    }
                    
                    matchingIDs.append((
                        objectID,
                        ThreemaIdentity(rawValue: identity)
                    ))
                }
            }
        }

        return matchingIDs
    }
}
