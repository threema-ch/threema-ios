//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import CoreData
import Foundation

extension EntityFetcher {
    
    enum PredicateFormat {
        case name
        case id
        case titleDepartmentCSI
        
        var format: String {
            switch self {
            case .name:
                "lastName contains[cd] %@ OR firstName contains[cd] %@ OR publicNickname contains[cd] %@"
        
            case .id:
                "identity contains[c] %@"
            
            case .titleDepartmentCSI:
                "csi contains[cd] %@ OR department contains[cd] %@ OR jobTitle contains[cd] %@"
            }
        }
        
        func arguments(for searchTerm: String) -> [String] {
            switch self {
            case .name, .titleDepartmentCSI:
                [searchTerm, searchTerm, searchTerm]
            case .id:
                [searchTerm]
            }
        }
    }
    
    /// Fetches all persisted `ContactEntity`
    /// - Returns: Optional array of `ContactEntity`
    @objc public func contactEntities() -> [ContactEntity]? {
        fetchEntities(entityName: "Contact", predicate: nil)
    }
    
    @objc public func gatewayContactEntities() -> [ContactEntity]? {
        let predicate = gatewayContactPredicate()
        return fetchEntities(entityName: "Contact", predicate: predicate)
    }
    
    @objc public func contactEntity(for identity: String) -> ContactEntity? {
        let predicate = contactIDPredicate(identity: identity)
        return fetchEntity(entityName: "Contact", predicate: predicate)
    }
    
    /// Returns all `ContactEntity` for a given ID
    /// Note: Normally we do not allow multiple contacts to have the same ID, but in the past there were some issues
    /// where this could happen.
    /// - Parameter identity: Identity of the contacts
    /// - Returns: Optional array of `ContactEntity`
    public func contactEntities(for identity: String) -> [ContactEntity]? {
        let predicate = contactIDPredicate(identity: identity)
        return fetchEntities(entityName: "Contact", predicate: predicate)
    }
    
    @objc public func contactEntitiesWithFeatureMaskNil() -> [ContactEntity]? {
        let predicate = contactFeatureMaskNilPredicate()
        return fetchEntities(entityName: "Contact", predicate: predicate)
    }
    
    @objc public func contactEntitiesWithCustomReadReceipt() -> [ContactEntity]? {
        let predicate = contactCustomReadReceiptPredicate()
        return fetchEntities(entityName: "Contact", predicate: predicate)
    }
    
    public func contactEntitiesWithCustomTypingIndicator() -> [ContactEntity]? {
        let predicate = contactCustomTypingIndicatorPredicate()
        return fetchEntities(entityName: "Contact", predicate: predicate)
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
        let predicate = contactIDPredicate(identity: myIdentity)
        return fetchEntity(entityName: "Contact", predicate: predicate)
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
        var predicates = [contactNotHiddenPredicate()]
        
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
            predicates.append(contactHideStalePredicate())
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
                contactPredicates.append(contactIDPredicate(identity: member.identity))
                
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
        
        let predicates = predicate(from: searchWords, for: .name) +
            predicate(from: searchWords, for: .id) +
            predicate(from: searchWords, for: .titleDepartmentCSI)
        
        let intermediaryPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: predicates
        )
        
        var visibilityPredicates = [contactNotHiddenPredicate()]
        if hideStaleContacts {
            visibilityPredicates.append(contactHideStalePredicate())
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
    
    // MARK: - Predicates
    
    func predicate(from words: [String], for predicateFormat: PredicateFormat) -> [NSPredicate] {
        guard words.isEmpty == false else {
            return []
        }
        
        var predicates = [NSPredicate]()
        
        for word in words {
            guard !word.isEmpty else {
                continue
            }
            
            let predicate = NSPredicate(
                format: predicateFormat.format,
                argumentArray: predicateFormat.arguments(for: word)
            )
        
            predicates.append(predicate)
        }
        
        return predicates
    }
    
    func contactIDPredicate(identity: String) -> NSPredicate {
        NSPredicate(format: "identity == %@", identity)
    }
    
    func contactNotHiddenPredicate() -> NSPredicate {
        NSPredicate(format: "hidden == nil OR hidden == 0")
    }
    
    func contactHideStalePredicate() -> NSPredicate {
        NSPredicate(format: "state == %d", ContactEntity.ContactState.active.rawValue)
    }
    
    func contactCustomReadReceiptPredicate() -> NSPredicate {
        NSPredicate(format: "readReceipts != %ld", ContactEntity.ReadReceipt.default.rawValue)
    }
    
    func contactCustomTypingIndicatorPredicate() -> NSPredicate {
        NSPredicate(format: "typingIndicators != %ld", ContactEntity.ReadReceipt.default.rawValue)
    }
    
    func contactFeatureMaskNilPredicate() -> NSPredicate {
        let featureMaskFieldName = ContactEntity.Field.name(
            for: .featureMask,
            encrypted: managedObjectContext.usesAdditionallyEncryptedModel
        )
        return NSPredicate(format: "\(featureMaskFieldName) == nil")
    }
    
    func gatewayContactPredicate() -> NSPredicate {
        NSPredicate(format: "identity beginswith '*'")
    }
}
