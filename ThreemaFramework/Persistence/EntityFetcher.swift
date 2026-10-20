import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaEssentials

public final class EntityFetcher: NSObject {
    
    // MARK: - Private properties
    
    /// The `NSManagedObjectContext` to fetch the entities in
    let managedObjectContext: NSManagedObjectContext

    // MARK: - Lifecycle
    
    /// EntityFetcher:
    /// - Parameters:
    ///   - managedObjectContext: The `NSManagedObjectContext` to fetch the entities in
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    // MARK: - Object
    
    /// Fetches a `NSManagedObject` for a given `NSManagedObjectID`
    /// - Parameter id: `NSManagedObjectID` of the desired object
    /// - Returns: Returns either an existing object from the context or a fault that represents that object.
    @objc public func managedObject(with id: NSManagedObjectID) -> NSManagedObject? {
        managedObjectContext.object(with: id)
    }
    
    @objc public func existingObject(with id: NSManagedObjectID) -> NSManagedObject? {
        do {
            return try managedObjectContext.existingObject(with: id)
        }
        catch {
            DDLogError("[EntityFetcher] Unable to load existing object with ID: \(id). Error: \(error)")
            return nil
        }
    }
    
    public func existingObject(with idString: String) -> NSManagedObject? {
        guard let url = URL(string: idString),
              let id = managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
        else {
            DDLogError("[EntityFetcher] Unable to retrieve ID for string: \(idString)")
            return nil
        }
        
        return existingObject(with: id)
    }
    
    // Functions
    
    public func callEntities(with identity: String, and callID: UInt32) -> [CallEntity]? {
        let sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let twoWeeksAgo = Date().addingTimeInterval(-60 * 60 * 24 * 14)
        let predicate = NSPredicate(
            format: "contact.identity == %@ AND date > %@ AND callID == %u",
            identity,
            twoWeeksAgo as CVarArg,
            callID
        )
        
        return fetchEntities(entityName: "Call", predicate: predicate, sortDescriptors: sortDescriptors)
    }
    
    public func messageReactionEntity(
        for messageID: Data,
        creator: ContactEntity?,
        reaction: String
    ) -> MessageReactionEntity? {
        // Filtering reaction for encrypted variants in memory
        let messagePredicate =
            if let creator {
                NSPredicate(
                    format: "creator == %@ AND message.id == %@",
                    creator,
                    messageID as CVarArg
                )
            }
            else {
                NSPredicate(
                    format: "creator == nil AND message.id == %@",
                    messageID as CVarArg
                )
            }

        let predicate =
            if !managedObjectContext.usesAdditionallyEncryptedModel {
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    messagePredicate,
                    NSPredicate(format: "reaction = %@", reaction),
                ])
            }
            else {
                messagePredicate
            }

        if !managedObjectContext.usesAdditionallyEncryptedModel {
            return fetchEntity(entityName: "MessageReaction", predicate: predicate)
        }
        else {
            let messages = fetchEntities(
                entityName: "MessageReaction",
                predicate: predicate
            ) as? [MessageReactionEntity]
            return messages?.first(where: { $0.reaction == reaction })
        }
    }
    
    public func messageReactionEntities(for message: BaseMessageEntity) -> [MessageReactionEntity]? {
        let predicate = NSPredicate(format: "message == %@", message)
        return fetchEntities(entityName: "MessageReaction", predicate: predicate)
    }
    
    public func messageReactionEntities(
        for message: BaseMessageEntity,
        creator: ContactEntity?
    ) -> [MessageReactionEntity]? {
        let predicate =
            if let creator {
                NSPredicate(format: "creator == %@ AND message == %@", creator, message)
            }
            else {
                NSPredicate(format: "creator == nil AND message == %@", message)
            }
        return fetchEntities(entityName: "MessageReaction", predicate: predicate)
    }
    
    public func groupCallEntities() -> [GroupCallEntity]? {
        fetchEntities(entityName: "GroupCallEntity")
    }
    
    public func lastGroupSyncRequestEntity(
        for groupIdentity: GroupIdentity,
        since: Date
    ) -> LastGroupSyncRequestEntity? {
        let predicate = NSPredicate(
            format: "groupId == %@ AND groupCreator == %@ AND lastSyncRequest >= %@",
            groupIdentity.id as CVarArg,
            groupIdentity.creator.rawValue,
            since as CVarArg
        )
        return fetchEntity(entityName: "LastGroupSyncRequest", predicate: predicate)
    }
    
    public func lastGroupSyncRequestEntities() -> [LastGroupSyncRequestEntity]? {
        fetchEntities(entityName: "LastGroupSyncRequest")
    }
    
    public func nonceEntities() -> [NonceEntity]? {
        fetchEntities(entityName: "Nonce")
    }

    // Fetches `NonceEntity` objects using deterministic ordering with pagination.
    ///
    /// Results are sorted to ensure stable and reproducible ordering across calls,
    /// which is required for correct batching behavior. Ordering is applied using
    /// the `nonce` attribute to guarantee a strict and consistent sequence.
    ///
    /// - Important: Sorting must rely only on Core Data attributes. Index names
    ///   (for example SQLite indexes) are not part of the Core Data model and
    ///   cannot be used for sorting.
    ///
    /// - Parameters:
    ///   - offset: The number of initial entities to skip. Used for pagination.
    ///   - limit: The maximum number of entities to return. A value of `0` means no limit.
    /// - Returns: An optional array of `NonceEntity` objects. Returns `nil` if the fetch fails.
    /// - Throws: `EntityCreatorError.missingData` or fetch errors
    public func nonceEntities(offset: Int, limit: Int) throws -> [NonceEntity]? {
        let sortDescriptors = [
            NSSortDescriptor(key: "nonce", ascending: true),
        ]

        return try fetchEntities(entityName: "Nonce", sortDescriptors: sortDescriptors, offset: offset, limit: limit)
    }

    /// Performs a batch lookup to determine which of the provided nonce values
    /// already exist in the persistent store.
    ///
    /// This method is optimized for large input sets and avoids per-item database
    /// queries by:
    /// - Splitting the input into smaller chunks to limit predicate size
    /// - Using a compound `OR` predicate over the `nonce` attribute
    /// - Fetching only the `nonce` field using a lightweight dictionary result type
    ///
    /// The method returns only the subset of input values that are already stored,
    /// represented as a `Set<Data>` for efficient O(1) membership checks.
    ///
    /// - Important: This method relies on the `nonce` attribute, not any SQLite index.
    ///   Core Data automatically uses available indexes for performance.
    /// - Note: In case of a fetch failure, the affected chunk is ignored and the error is logged.
    ///
    /// - Parameter values: Array of nonce `Data` values to check in the database.
    /// - Returns: A set containing all values from the input that already exist in storage.
    ///            Returns an empty set if no matches are found or input is empty.
    public func existingNonces(in values: [Data]) throws -> Set<Data> {
        guard !values.isEmpty else {
            return []
        }

        let chunkSize = 200
        var result = Set<Data>()

        for chunk in values.chunked(into: chunkSize) {
            let predicates = chunk.map {
                NSPredicate(format: "nonce == %@", $0 as CVarArg)
            }

            let compound = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Nonce")
            fetchRequest.predicate = compound
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["nonce"]

            let partial: Set<Data> = try managedObjectContext.performAndWait {
                do {
                    let results = try fetchRequest.execute() as? [[String: Any]] ?? []
                    return Set(results.compactMap { $0["nonce"] as? Data })
                }
                catch {
                    DDLogError("[EntityFetcher] Failed batch lookup. Error: \(error)")
                    throw error
                }
            }

            result.formUnion(partial)
        }

        return result
    }

    public func isNonceEntityAlreadyInDB(_ hashedNonce: Data) -> Bool {
        let predicate = NSPredicate(format: "nonce == %@", hashedNonce as CVarArg)
        return fetchEntity(entityName: "Nonce", predicate: predicate) != nil
    }
    
    public func webClientSessionEntities() -> [WebClientSessionEntity]? {
        let sortDescriptor = NSSortDescriptor(key: "lastConnection", ascending: true)
        return fetchEntities(entityName: "WebClientSession", sortDescriptors: [sortDescriptor])
    }
    
    public func activeWebClientSessionEntities() -> [WebClientSessionEntity]? {
        let predicate = NSPredicate(format: "active == true")
        let sortDescriptor = NSSortDescriptor(key: "lastConnection", ascending: true)
        
        return fetchEntities(entityName: "WebClientSession", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    public func activeWebClientSessionEntity() -> WebClientSessionEntity? {
        let predicate = NSPredicate(format: "active == true")
        return fetchEntity(entityName: "WebClientSession", predicate: predicate)
    }
    
    public func notPermanentWebClientSessionEntities() -> [WebClientSessionEntity]? {
        let predicate = NSPredicate(format: "permanent == NO")
        return fetchEntities(entityName: "WebClientSession", predicate: predicate)
    }
    
    public func webClientSessionEntity(for initiatorPermanentPublicKeyHash: String) -> WebClientSessionEntity? {
        let predicate = NSPredicate(format: "initiatorPermanentPublicKeyHash == %@", initiatorPermanentPublicKeyHash)
        return fetchEntity(entityName: "WebClientSession", predicate: predicate)
    }
    
    /// Use this function just for migration!
    public func fileMessagesWithJSONCaptionButEmptyCaption() -> [FileMessageEntity]? {
        let predicate = NSPredicate(format: "caption == nil && json contains[cd] %@", "\"d\":\"")
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        return fetchEntities(entityName: "FileMessage", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    public func imageMessages(for conversationEntity: ConversationEntity) -> [ImageMessageEntity]? {
        let imageDataFieldName = ImageDataEntity.Field.name(
            for: .data,
            encrypted: managedObjectContext.usesAdditionallyEncryptedModel
        )
        let predicate = NSPredicate(
            format: "conversation == %@ AND image.\(imageDataFieldName) != nil",
            conversationEntity
        )
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        return fetchEntities(entityName: "ImageMessage", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    public func videoMessages(for conversationEntity: ConversationEntity) -> [VideoMessageEntity]? {
        let videoDataFieldName = VideoDataEntity.Field.name(
            for: .data,
            encrypted: managedObjectContext.usesAdditionallyEncryptedModel
        )
        let predicate = NSPredicate(
            format: "conversation == %@ AND video.\(videoDataFieldName) != nil",
            conversationEntity
        )
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        return fetchEntities(entityName: "VideoMessage", predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    /// Returns all files pertaining to the given conversation.
    /// - Parameters:
    ///   - conversationEntity: The entity of the conversation.
    ///   - filteredMimeTypes: All mime types should be filtered with type 2 and 1. Files (type = 0) cannot be filtered
    /// out.
    /// - Returns: A comprehensive list of all filtered file messages.
    public func fileMessagesForPhotoBrowser(
        for conversationEntity: ConversationEntity,
        filteredMimeTypes: [String]
    ) -> [FileMessageEntity]? {
        // Filtering type and mime type for encrypted variants in memory
        let fileDataFieldName = FileDataEntity.Field.name(
            for: .data,
            encrypted: managedObjectContext.usesAdditionallyEncryptedModel
        )
        let conversationPredicate = NSPredicate(
            format: "(conversation == %@) AND data.\(fileDataFieldName) != nil",
            conversationEntity
        )

        let predicate =
            if !managedObjectContext.usesAdditionallyEncryptedModel {
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    conversationPredicate,
                    NSPredicate(
                        format: "((type != 2) AND !(mimeType IN %@)) OR ((type == 0))",
                        filteredMimeTypes,
                    ),
                ])
            }
            else {
                conversationPredicate
            }

        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        let messages = fetchEntities(
            entityName: "FileMessage",
            predicate: predicate,
            sortDescriptors: [sortDescriptor]
        ) as? [FileMessageEntity]

        return if !managedObjectContext.usesAdditionallyEncryptedModel {
            messages
        }
        else {
            messages?.filter {
                guard let mimeType = $0.mimeType else {
                    return false
                }
                return ($0.type != 2 && !filteredMimeTypes.contains(mimeType)) || $0.type == 0
            }
        }
    }
    
    func fileMessageObjectIDsWithDataAvailable() throws -> [NSManagedObjectID] {
        let fileDataFieldName = FileDataEntity.Field.name(
            for: .data,
            encrypted: managedObjectContext.usesAdditionallyEncryptedModel
        )
        
        let predicate = NSPredicate(
            format: "data != nil AND data.\(fileDataFieldName) != nil"
        )
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "FileMessage")
        fetchRequest.predicate = predicate
        fetchRequest.resultType = .managedObjectIDResultType
        
        var matchingIDs: [NSManagedObjectID] = []

        try managedObjectContext.performAndWait {
            if let results = try fetchRequest.execute() as? [NSManagedObjectID], !results.isEmpty {
                matchingIDs = results
            }
        }

        return matchingIDs
    }
    
    // Fetch helpers
    
    func fetchEntity<Entity: NSManagedObject>(entityName: String, predicate: NSPredicate) -> Entity? {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        
        var fetchedEntity: Entity?
        managedObjectContext.performAndWait {
            do {
                if let result = try fetchRequest.execute() as? [Entity], let first = result.first {
                    fetchedEntity = first
                }
            }
            catch {
                DDLogError("[EntityFetcher] Failed to fetch single entity of type \(entityName). Error: \(error)")
            }
        }
        
        return fetchedEntity
    }

    func fetchEntities<Entity: NSManagedObject>(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) -> [Entity]? {
        do {
            return try fetchEntities(
                entityName: entityName,
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                offset: 0,
                limit: 0
            )
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch entities of type \(entityName). Error: \(error)")
            return nil
        }
    }

    func fetchEntities<Entity: NSManagedObject>(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        offset: Int = 0,
        limit: Int = 0 // 0 means no limit
    ) throws -> [Entity] {

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)

        fetchRequest.fetchOffset = offset
        fetchRequest.fetchLimit = limit

        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
       
        return try managedObjectContext.performAndWait {
            guard let entities = try fetchRequest.execute() as? [Entity] else {
                throw EntityCreatorError.missingData
            }
            return entities
        }
    }
    
    @available(*, deprecated, message: "Do not use anymore")
    func execute(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> [NSManagedObject]? {
        var fetchedEntities: [NSManagedObject]?
        managedObjectContext.performAndWait {
            do {
                fetchedEntities = try fetchRequest.execute() as? [NSManagedObject]
            }
            catch {
                DDLogError("[EntityFetcher] Failed to fetch entities. Error: \(error)")
            }
        }
        return fetchedEntities
    }
    
    public func execute(batchUpdateRequest: NSBatchUpdateRequest) -> NSBatchUpdateResult? {
        do {
            return try managedObjectContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
        }
        catch {
            DDLogError("[EntityFetcher] Failed to execute batch update request. Error: \(error)")
        }
        return nil
    }
    
    func countEntities(entityName: String, predicate: NSPredicate?) -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.fetchLimit = 0
        if let predicate {
            fetchRequest.predicate = predicate
        }
        
        var count = 0
        managedObjectContext.performAndWait {
            do {
                count = try managedObjectContext.count(for: fetchRequest)
            }
            catch {
                DDLogError("[EntityFetcher] Failed to count entities of type \(entityName). Error: \(error)")
            }
        }
        return count
    }
    
    @available(*, deprecated, message: "Do not use anymore")
    func executeCount(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> Int {
        var count = 0
        managedObjectContext.performAndWait {
            do {
                count = try managedObjectContext.count(for: fetchRequest)
            }
            catch {
                DDLogError("[EntityFetcher] Failed to count entities. Error: \(error)")
            }
        }
        return count
    }
    
    @available(*, deprecated, message: "Do not use anymore")
    func executeCount(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>, onCompletion: @escaping (Int) -> Void) {
        managedObjectContext.perform {
            var count = 0
            do {
                count = try self.managedObjectContext.count(for: fetchRequest)
            }
            catch {
                DDLogError("[EntityFetcher] Failed to count entities. Error: \(error)")
            }
            onCompletion(count)
        }
    }
}
