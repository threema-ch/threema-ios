import Foundation

extension EntityFetcher {
    public func pollIDs(
        conversation: ConversationEntity? = nil,
        state: BallotEntity.BallotState? = nil
    ) async -> [NSManagedObjectID] {
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType
        
        let propertiesToFetch: [Any] = [objectIDExpression]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Ballot")
        fetchRequest.fetchLimit = 0
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = propertiesToFetch
        fetchRequest.returnsDistinctResults = true
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "createDate", ascending: false),
            NSSortDescriptor(key: "modifyDate", ascending: false),
        ]
        
        var predicates: [NSPredicate] = []
        
        if let state {
            predicates.append(ballotStatePredicate(state: state))
        }
        
        if let conversation {
            predicates.append(ballotConversationEntityPredicate(conversationEntity: conversation))
        }

        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        var matchingIDs: [NSManagedObjectID] = []
        
        await managedObjectContext.perform {
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
    
    @objc public func ballotEntity(for ballotID: Data) -> BallotEntity? {
        let predicate = ballotIDPredicate(ballotID: ballotID)
        return fetchEntity(entityName: "Ballot", predicate: predicate)
    }
    
    public func ballotEntitiesCount(for conversationEntity: ConversationEntity) -> Int {
        let predicate = ballotConversationEntityPredicate(conversationEntity: conversationEntity)
        return countEntities(entityName: "Ballot", predicate: predicate)
    }
    
    public func openBallotEntitiesCount(for conversationEntity: ConversationEntity) -> Int {
        let conversationPredicate = ballotConversationEntityPredicate(conversationEntity: conversationEntity)
        let openPredicate = ballotStateOpenPredicate()
        
        return countEntities(
            entityName: "Ballot",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, openPredicate])
        )
    }
    
    @objc public func ballotChoiceEntity(for ballotID: Data, and choiceID: NSNumber) -> BallotChoiceEntity? {
        let predicate = ballotChoicePredicate(ballotID: ballotID, choiceID: choiceID)
        return fetchEntity(entityName: "BallotChoice", predicate: predicate)
    }
    
    // MARK: - Predicates
    
    func ballotConversationEntityPredicate(conversationEntity: ConversationEntity) -> NSPredicate {
        NSPredicate(format: "conversation == %@", conversationEntity)
    }
    
    func ballotIDPredicate(ballotID: Data) -> NSPredicate {
        NSPredicate(format: "id == %@", ballotID as CVarArg)
    }
    
    func ballotStatePredicate(state: BallotEntity.BallotState) -> NSPredicate {
        NSPredicate(format: "state == %d", state.rawValue)
    }
    
    func ballotStateOpenPredicate() -> NSPredicate {
        ballotStatePredicate(state: .open)
    }
    
    func ballotChoicePredicate(ballotID: Data, choiceID: NSNumber) -> NSPredicate {
        NSPredicate(format: "ballot.id == %@ AND id == %@", ballotID as CVarArg, choiceID)
    }
}
