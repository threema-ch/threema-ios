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
        
        if let conversation {
            predicates.append(ballotConversationEntityPredicate(conversationEntity: conversation))
        }
        
        if let state {
            predicates.append(ballotStatePredicate(state: state))
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
        let openPredicate = ballotStatePredicate(state: .open)
        
        return countEntities(
            entityName: "Ballot",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [conversationPredicate, openPredicate])
        )
    }
    
    @objc public func ballotChoiceEntity(for ballotID: Data, and choiceID: NSNumber) -> BallotChoiceEntity? {
        let predicate = ballotChoicePredicate(ballotID: ballotID, choiceID: choiceID)
        return fetchEntity(entityName: "BallotChoice", predicate: predicate)
    }

    public func ballotEntities() -> [BallotEntity] {
        fetchEntities(entityName: "Ballot") ?? []
    }

    /// Fetches `BallotEntity` objects that belong to a contact or group conversation, i.e. excluding distribution
    /// lists and orphaned ballots (those without a conversation).
    ///
    /// Results are ordered by the unique `id` attribute to provide a stable, reproducible sequence across calls, which
    /// is required for correct, non-overlapping pagination/batching.
    ///
    /// - Parameters:
    ///   - offset: The number of initial entities to skip. Defaults to `0`.
    ///   - limit: The maximum number of entities to return. Pass `nil` (the default) for no limit.
    /// - Returns: Matching `BallotEntity` objects, or `nil` if the fetch fails.
    public func ballotEntitiesInContactOrGroupConversations(
        offset: Int = 0,
        limit: Int? = nil
    ) -> [BallotEntity] {
        fetchEntities(
            entityName: "Ballot",
            predicate: .ballotInContactOrGroupConversation,
            sortDescriptors: [NSSortDescriptor(key: "id", ascending: true)],
            offset: offset,
            limit: limit ?? 0 // 0 means no limit
        ) ?? []
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

    func ballotChoicePredicate(ballotID: Data, choiceID: NSNumber) -> NSPredicate {
        NSPredicate(format: "ballot.id == %@ AND id == %@", ballotID as CVarArg, choiceID)
    }
}
