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

import Foundation

extension EntityFetcher {
    
    /// Fetches the object IDs of conversations matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    /// - Returns: Ordered array of matching contacts object IDs
    public func matchingContactsForContactListSearch(
        containing text: String
    ) -> [NSManagedObjectID] {
        
        let intermediaryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            contactNamePredicate(text: text),
            contactIDPredicate(text: text),
            contactTitleDepartementCSIPredicate(text: text),
        ])
        
        var visibilityPredicates = [contactNotHiddenPredicate()]
        if UserSettings.shared().hideStaleContacts {
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
        
        // TODO: (IOS-4536) Sort

        return matchingIDs
    }
    
    // MARK: - Predicates

    func contactNamePredicate(text: String) -> NSPredicate {
        NSPredicate(
            format: "lastName contains[c] %@ OR firstName contains[c] %@ OR publicNickname contains[c] %@",
            text,
            text,
            text
        )
    }
    
    func contactIDPredicate(text: String) -> NSPredicate {
        NSPredicate(format: "identity contains[c] %@", text)
    }
    
    func contactNotHiddenPredicate() -> NSPredicate {
        NSPredicate(format: "hidden == nil OR hidden == 0")
    }
    
    func contactHideStalePredicate() -> NSPredicate {
        NSPredicate(format: "state == %d", ContactEntity.ContactState.active.rawValue)
    }
    
    func contactTitleDepartementCSIPredicate(text: String) -> NSPredicate {
        NSPredicate(
            format: "csi contains[c] %@ OR department contains[c] %@ OR jobTitle contains[c] %@",
            text,
            text,
            text
        )
    }
}
