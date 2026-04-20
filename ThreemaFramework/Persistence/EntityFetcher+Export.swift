import CocoaLumberjackSwift
import Foundation

extension EntityFetcher {
    
    // MARK: - Conversation
    
    public func conversationIDsForExport() throws -> [NSManagedObjectID] {
        // We fetch the managed objectID
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        request.fetchLimit = 0
        request.resultType = .managedObjectIDResultType
        request.returnsDistinctResults = true
            
        var matchingIDs: [NSManagedObjectID] = []
        
        try managedObjectContext.performAndWait {
            if let results = try request.execute() as? [NSManagedObjectID] {
                matchingIDs = results
            }
        }
        return matchingIDs
    }
    
    public func messagesForExport(
        inConversationsWithID id: NSManagedObjectID,
        handleRecord: (BaseMessageEntity) throws -> Void
    ) throws {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.fetchBatchSize = 100
        
        let conversation: ConversationEntity? = try managedObjectContext.existingObject(with: id) as? ConversationEntity
        
        guard let conversation else {
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "conversation == %@", conversation)
        
        do {
            try managedObjectContext.performAndWait {

                let results = try managedObjectContext.fetch(fetchRequest)
            
                for result in results {
                    guard let message = result as? BaseMessageEntity else {
                        continue
                    }
                    
                    // Wrap in autoreleasepool to flush temporary memory immediately
                    try autoreleasepool {
                        try handleRecord(message)
                    }
                }
            }
        }
        catch {
            DDLogError("Fetch error: \(error)")
        }
    }
}
