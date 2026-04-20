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
            format: "contact.identity == %@ AND callID == %u AND date > %@",
            identity,
            callID,
            twoWeeksAgo as CVarArg
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
                    format: "message.id == %@ AND creator == %@",
                    messageID as CVarArg,
                    creator,
                    reaction
                )
            }
            else {
                NSPredicate(
                    format: "message.id == %@ AND creator == nil",
                    messageID as CVarArg,
                    reaction
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
                NSPredicate(format: "message == %@ AND creator == %@", message, creator)
            }
            else {
                NSPredicate(format: "message == %@ AND creator == nil", message)
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
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.fetchLimit = 0
        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
       
        return managedObjectContext.performAndWait {
            do {
                return try fetchRequest.execute() as? [Entity]
            }
            catch {
                DDLogError("[EntityFetcher] Failed to fetch entities of type \(entityName). Error: \(error)")
                return nil
            }
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
