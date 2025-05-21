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

import Foundation

extension EntityFetcher {
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates such as group or contact name and ThreemaID
    ///   - scope: Scope limiting the search to some types of conversation
    /// - Returns: Ordered array of matching conversations object IDs
    public func matchingConversationsForGlobalSearch(
        containing text: String,
        scope: GlobalSearchConversationScope
    ) -> [NSManagedObjectID] {
        
        var intermediaryPredicate: NSPredicate
        
        switch scope {
        case .all:
            intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                conversationGroupNamePredicate(text: text),
                conversationFirstNamePredicate(text: text),
                conversationLastNamePredicate(text: text),
                conversationNickNamePredicate(text: text),
                conversationIdentityPredicate(text: text),
            ])
        case .oneToOne:
            intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                conversationFirstNamePredicate(text: text),
                conversationLastNamePredicate(text: text),
                conversationNickNamePredicate(text: text),
                conversationIdentityPredicate(text: text),
            ])
        case .groups:
            intermediaryPredicate = conversationGroupNamePredicate(text: text)
        case .archived:
            let allPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                conversationGroupNamePredicate(text: text),
                conversationFirstNamePredicate(text: text),
                conversationLastNamePredicate(text: text),
                conversationNickNamePredicate(text: text),
                conversationIdentityPredicate(text: text),
            ])
            intermediaryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                allPredicate,
                conversationArchivedPredicate(),
            ])
        }
        
        let finalPredicate: NSPredicate =
            if UserSettings.shared().hidePrivateChats {
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
            conversationGroupNamePredicate(text: text),
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
        
        // TODO: (IOS-4536) Sort

        return matchingIDs
    }
    
    // MARK: - Predicates
    
    func conversationFirstNamePredicate(text: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.firstName contains[c] %@", text)
    }
    
    func conversationLastNamePredicate(text: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.lastName contains[c] %@", text)
    }
    
    func conversationNickNamePredicate(text: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.publicNickname contains[c] %@", text)
    }
    
    func conversationIdentityPredicate(text: String) -> NSPredicate {
        NSPredicate(format: "groupId == nil AND contact.identity contains[c] %@", text)
    }
    
    func conversationGroupNamePredicate(text: String) -> NSPredicate {
        NSPredicate(format: "groupId != nil AND groupName contains[c] %@", text)
    }
    
    func conversationArchivedPredicate() -> NSPredicate {
        NSPredicate(format: "visibility == %d", ConversationEntity.Visibility.archived.rawValue)
    }
    
    func conversationNotPrivatePredicate() -> NSPredicate {
        NSPredicate(format: "category != %d", ConversationEntity.Category.private.rawValue)
    }
}
