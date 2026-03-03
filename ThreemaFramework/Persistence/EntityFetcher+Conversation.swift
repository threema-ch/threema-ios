//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaEssentials

extension EntityFetcher {
    
    /// Fetches all persisted `ConversationEntity`
    /// - Returns: Optional array of `ConversationEntity`
    @objc public func conversationEntities() -> [ConversationEntity]? {
        fetchEntities(entityName: "Conversation")
    }
    
    /// Fetches all `ConversationEntity` that are not archived
    /// - Returns: Optional array of `ConversationEntity`
    public func notArchivedConversationEntities() -> [ConversationEntity]? {
        let predicate = conversationNotArchivedPredicate()
        return fetchEntities(entityName: "Conversation", predicate: predicate)
    }
    
    /// Fetches all `ConversationEntity` that belong to groups
    /// - Returns: Optional array of `ConversationEntity`
    public func groupConversationEntities() -> [ConversationEntity]? {
        let predicate = conversationAllGroupsPredicate()
        return fetchEntities(entityName: "Conversation", predicate: predicate)
    }
    
    /// Fetches all persisted `ConversationEntity` that are private
    /// - Returns: Optional array of `ConversationEntity`
    public func privateConversationEntities() -> [ConversationEntity]? {
        let predicate = conversationPrivatePredicate()
        return fetchEntities(entityName: "Conversation", predicate: predicate)
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
        let predicate = conversationContactIdentityPredicate(identity: identity)
        return fetchEntity(entityName: "Conversation", predicate: predicate)
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
        let predicate = conversationGroupPredicate(
            identity: groupIdentity.creator.rawValue,
            id: groupIdentity.id,
            myIdentity: myIdentity
        )
        return fetchEntity(entityName: "Conversation", predicate: predicate)
    }
    
    @available(*, deprecated, message: "This is deprecated and will be removed together with the web client code.")
    public func legacyConversationEntity(for groupID: Data?) -> ConversationEntity? {
        guard let groupID else {
            return nil
        }
        let predicate = legacyConversationGroupIDPredicate(id: groupID)
        return fetchEntity(entityName: "Conversation", predicate: predicate)
    }
    
    public func conversationEntity(for distributionListID: Int) -> ConversationEntity? {
        let predicate = conversationDistributionListPredicate(distributionListID: distributionListID)
        return fetchEntity(entityName: "Conversation", predicate: predicate)
    }
    
    public func conversationEntities(for member: ContactEntity) -> [ConversationEntity]? {
        let predicate = conversationMemberPredicate(member: member)
        return fetchEntities(entityName: "Conversation", predicate: predicate)
    }
    
    @objc public func filteredGroupConversationEntities(by words: [String]) -> [ConversationEntity]? {
        var predicates = [conversationAllGroupsPredicate()]
        
        for word in words where !word.isEmpty {
            let predicate = NSPredicate(format: "groupName contains[cd] %@", word)
            predicates.append(predicate)
        }
                
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.fetchBatchSize = 100
        
        return execute(fetchRequest) as? [ConversationEntity]
    }
    
    public func archivedConversationEntitiesCount() -> Int {
        let predicate = conversationArchivedPredicate()
        return countEntities(entityName: "Conversation", predicate: predicate)
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
                conversationGroupNamePredicate(name: text),
                conversationFirstNamePredicate(firstName: text),
                conversationLastNamePredicate(lastName: text),
                conversationNickNamePredicate(nickName: text),
                conversationContactIdentityContainsPredicate(identity: text),
            ])
        case .oneToOne:
            intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                conversationFirstNamePredicate(firstName: text),
                conversationLastNamePredicate(lastName: text),
                conversationNickNamePredicate(nickName: text),
                conversationContactIdentityContainsPredicate(identity: text),
            ])
        case .groups:
            intermediaryPredicate = conversationGroupNamePredicate(name: text)
        case .archived:
            let allPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                conversationGroupNamePredicate(name: text),
                conversationFirstNamePredicate(firstName: text),
                conversationLastNamePredicate(lastName: text),
                conversationNickNamePredicate(nickName: text),
                conversationContactIdentityContainsPredicate(identity: text),
            ])
            intermediaryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                allPredicate,
                conversationArchivedPredicate(),
            ])
        }
        
        let finalPredicate: NSPredicate =
            if hidePrivateChats {
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    intermediaryPredicate,
                    conversationNotPrivatePredicate(),
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
               
        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            conversationGroupNamePredicate(name: text),
            conversationNotPrivatePredicate(),
        ])
        
        // We only fetch the managed object ID
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        let propertiesToFetch: [Any] = [objectIDExpression]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
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
    
    func conversationFirstNamePredicate(firstName: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.firstName contains[c] %@", firstName)
    }
    
    func conversationLastNamePredicate(lastName: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.lastName contains[c] %@", lastName)
    }
    
    func conversationNickNamePredicate(nickName: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.publicNickname contains[c] %@", nickName)
    }
    
    func conversationContactIdentityPredicate(identity: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.identity == %@", identity)
    }
    
    func conversationContactIdentityContainsPredicate(identity: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.identity contains[c] %@", identity)
    }
    
    func conversationGroupNamePredicate(name: String) -> NSPredicate {
        NSPredicate(format: "groupId != nil AND groupName contains[c] %@", name)
    }
    
    func conversationArchivedPredicate() -> NSPredicate {
        NSPredicate(format: "visibility == %d", ConversationEntity.Visibility.archived.rawValue)
    }
    
    func conversationNotArchivedPredicate() -> NSPredicate {
        NSPredicate(format: "visibility != %d", ConversationEntity.Visibility.archived.rawValue)
    }
    
    func conversationPrivatePredicate() -> NSPredicate {
        NSPredicate(format: "category == %d", ConversationEntity.Category.private.rawValue)
    }
    
    func conversationNotPrivatePredicate() -> NSPredicate {
        NSPredicate(format: "category != %d", ConversationEntity.Category.private.rawValue)
    }
    
    func conversationDistributionListPredicate(distributionListID: Int) -> NSPredicate {
        NSPredicate(format: "distributionList.distributionListID == %@", distributionListID as NSNumber)
    }
    
    func conversationMemberPredicate(member: ContactEntity) -> NSPredicate {
        NSPredicate(format: "%@ IN members", member)
    }
    
    func conversationGroupPredicate(identity: String, id: Data, myIdentity: String?) -> NSPredicate {
        if identity != myIdentity {
            NSPredicate(format: "contact.identity == %@ AND groupId == %@", identity, id as CVarArg)
        }
        else {
            NSPredicate(format: "contact == nil AND groupId == %@", id as CVarArg)
        }
    }
    
    func conversationAllGroupsPredicate() -> NSPredicate {
        NSPredicate(format: "groupId != nil")
    }
    
    func conversationsWithLastUpdatePredicate() -> NSPredicate {
        NSPredicate(format: "lastUpdate != nil")
    }
    
    func legacyConversationGroupIDPredicate(id: Data) -> NSPredicate {
        NSPredicate(format: "groupId == %@", id as CVarArg)
    }
}
