import CocoaLumberjackSwift
import CoreData
import Foundation

extension EntityFetcher {
    
    public func distributionListEntity(for id: Int) -> DistributionListEntity? {
        fetchEntity(
            entityName: "DistributionList",
            predicate: .distributionListWithID(id)
        )
    }
    
    public func distributionListEntity(for conversationEntity: ConversationEntity) -> DistributionListEntity? {
        fetchEntity(
            entityName: "DistributionList",
            predicate: .distributionListWithConversation(conversationEntity)
        )
    }
    
    @objc public func filteredDistributionListEntities(
        by words: [String],
        excludePrivate: Bool = false
    ) -> [DistributionListEntity] {
        guard ThreemaEnvironment.distributionListsActive else {
            return []
        }
        do {
            let distributionNames: [NSPredicate] = words
                .filter { !$0.isEmpty }
                .map { .distributionListWithName($0) }

            let request = NSFetchRequest<DistributionListEntity>(entityName: "DistributionList")
            request.fetchBatchSize = 100
            request.predicate = .and(
                .and(distributionNames),
                excludePrivate ? .not(.distributionListIsPrivate) : nil
            )
            let distributionListEntities = try managedObjectContext.performAndWait {
                try managedObjectContext.fetch(request)
            }
            return distributionListEntities
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch DistributionListEntities. Error: \(error)")
            return []
        }
    }
    
    /// Fetches the object IDs of distribution lists matching the passed parameters
    /// - Parameters:
    ///   - text: String used in several predicates
    /// - Returns: Ordered array of matching contacts object IDs
    public func matchingDistributionListsForContactListSearch(
        containing text: String
    ) -> [NSManagedObjectID] {
        // We only fetch the managed object ID
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        let propertiesToFetch: [Any] = [objectIDExpression]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DistributionList")
        fetchRequest.predicate = .and(
            .distributionListWithName(text),
            .not(.distributionListIsPrivate)
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
        
        // TODO: (IOS-4536) Sort

        return matchingIDs
    }

    /// Fetches a `DistributionListEntity` with an `NSManagedObjectID`
    /// - Returns: Optional `DistributionListEntity`
    public func distributionListEntity(with objectID: NSManagedObjectID) -> DistributionListEntity? {
        var result: DistributionListEntity?
        do {
            result = try managedObjectContext.existingObject(with: objectID) as? DistributionListEntity
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch DistributionListEntity with id: \(objectID). Error: \(error)")
        }
        return result
    }
}
