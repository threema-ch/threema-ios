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

    /// If a specific message from the sender has already been delivered.
    /// - Parameters:
    /// - identity: Sender of the message
    /// - messageID: Message ID of the message looking for
    public func isMessageDelivered(from identity: String, with messageID: Data) -> Bool {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.fetchLimit = 1
        // Get delivered message in 1-1 or group conversation
        fetchRequest.predicate = NSPredicate(
            format: "(conversation.contact.identity == %@ OR sender.identity == %@) AND id == %@ AND delivered == true",
            identity,
            identity,
            messageID as CVarArg
        )

        do {
            return try managedObjectContext.count(for: fetchRequest) > 0
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
        let noPrivatePredicate = baseMessageNoPrivatePredicate()
        let dateRangePredicate = baseMessageDateRangePredicate(from: start, to: end)
        
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
    
    // MARK: - Global Search

    private func textMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate]
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Text
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "text contains[cd] %@", text))
        }
        
        return searchMessages(
            of: "TextMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates)
        )
    }
    
    private func ballotMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate]
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Title
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "ballot.title contains[cd] %@", text))
        }
        
        return searchMessages(
            of: "BallotMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates)
        )
    }
    
    private func locationMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate]
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Name or Address
        if let text, text != "" {
            allPredicates
                .append(NSPredicate(format: "poiName contains[cd] %@ || poiAddress contains[cd] %@", text, text))
        }
        
        return searchMessages(
            of: "LocationMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates)
        )
    }
    
    private func fileMessages(
        containing text: String?,
        conformingTo predicates: [NSPredicate]
    ) -> [(objectID: NSManagedObjectID, date: Date)] {
        var allPredicates = predicates
        
        // Name or Caption
        if let text, text != "" {
            allPredicates.append(NSPredicate(format: "fileName contains[cd] %@ || caption contains[cd] %@", text, text))
        }
        
        return searchMessages(
            of: "FileMessage",
            with: NSCompoundPredicate(andPredicateWithSubpredicates: allPredicates)
        )
    }
    
    private func searchMessages(
        of entityName: String,
        with compoundPredicate: NSCompoundPredicate
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
        fetchRequest.fetchLimit = 0
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
    
    func baseMessageNoPrivatePredicate() -> NSPredicate {
        NSPredicate(format: "conversation.category != %d", ConversationEntity.Category.private.rawValue)
    }
    
    func baseMessageDateRangePredicate(from start: Date, to end: Date) -> NSPredicate {
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
}
