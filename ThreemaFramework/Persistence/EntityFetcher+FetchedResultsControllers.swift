import CoreData
import Foundation

extension EntityFetcher {
    
    // MARK: - Contacts
    
    @objc public enum ContactType: Int {
        case all, noGateway, onlyGateway, noEchoEcho, noGatewayNoEchoEcho
    }
    
    @objc public enum ListType: Int {
        case contacts, work, contactsAndWork
    }
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsController(
        for type: ContactType,
        of list: ListType,
        with members: Set<ContactEntity>?,
        hideStaleContacts: Bool,
        sortOrderFirstName: Bool,
        isBusinessApp: Bool
    ) -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchRequest.fetchBatchSize = 100
        
        var predicates = [NSPredicate]()
        
        if let members {
            let ids = members.map(\.identity)
            let predicate = NSPredicate(
                format: "(hidden == nil OR hidden == 0) OR (hidden == 1 AND identity IN %@)",
                ids
            )
            predicates.append(predicate)
        }
        else {
            let predicate = NSPredicate(format: "hidden == nil OR hidden == 0")
            predicates.append(predicate)
        }
        
        switch type {
        case .all:
            break
        case .noGateway:
            let predicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(predicate)
        case .onlyGateway:
            let predicate = NSPredicate(format: "identity beginswith '*'")
            predicates.append(predicate)
        case .noEchoEcho:
            let predicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(predicate)
        case .noGatewayNoEchoEcho:
            let echoPredicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(echoPredicate)
            let gatewayPredicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(gatewayPredicate)
        }
        
        if hideStaleContacts {
            let predicate = NSPredicate(format: "state == %d", ContactEntity.ContactState.active.rawValue)
            predicates.append(predicate)
        }
        
        if list == .work {
            let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: true))
            predicates.append(predicate)
        }
        else {
            if list == .contactsAndWork {
                // do not predicate for work contacts
            }
            else if isBusinessApp {
                let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: false))
                predicates.append(predicate)
            }
        }
        
        var allPredicates = [NSCompoundPredicate(andPredicateWithSubpredicates: predicates) as NSPredicate]
        
        if hideStaleContacts, let members, !members.isEmpty {
            for member in members {
                let predicate = NSPredicate(format: "identity == %@", member.identity)
                allPredicates.append(predicate)
            }
        }
        
        let finalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: allPredicates)
        fetchRequest.predicate = finalPredicate
        
        let sortDescriptors = nameSortDescriptors(sortOrderFirstName: sortOrderFirstName)
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "sortIndex",
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    func nameSortDescriptors(sortOrderFirstName: Bool) -> [NSSortDescriptor] {
        let sortIndex = NSSortDescriptor(key: "sortIndex", ascending: true)
        let firstName = NSSortDescriptor(
            key: "firstName",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        let lastName = NSSortDescriptor(
            key: "lastName",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        let publicNickname = NSSortDescriptor(
            key: "publicNickname",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        
        if sortOrderFirstName {
            return [sortIndex, firstName, lastName, publicNickname]
        }
        else {
            return [sortIndex, lastName, firstName, publicNickname]
        }
    }
    
    // MARK: - DistributionLists
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForDistributionListEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DistributionList")
        fetchRequest.fetchBatchSize = 20
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - Group conversations

    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForGroupConversationEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.predicate = NSPredicate(format: "groupId != nil")
        fetchRequest.fetchBatchSize = 20
        
        let sortDescriptors = [NSSortDescriptor(key: "groupName", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - Conversations
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForConversationEntities(
        hidePrivateChats: Bool
    ) -> NSFetchedResultsController<NSFetchRequestResult> {
        let hideDistributionLists = !ThreemaEnvironment.distributionListsActive
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.relationshipKeyPathsForPrefetching = ["members"]
        fetchRequest.fetchBatchSize = 20
        fetchRequest.predicate = .and(
            .not(.conversationIsArchived),
            .conversationHasLastUpdate,
            hideDistributionLists ? .not(.conversationIsDistributionList) : nil,
            hidePrivateChats ? .not(.conversationIsPrivate) : nil,
            .conversationContactIsVisible
        )
        let visibilityDescriptor = NSSortDescriptor(key: "visibility", ascending: false)
        let lastUpdateDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        let lastMessageDescriptor = NSSortDescriptor(key: "lastMessage.date", ascending: false)
        fetchRequest.sortDescriptors = [visibilityDescriptor, lastUpdateDescriptor, lastMessageDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForArchivedConversationEntities(
        hidePrivateChats: Bool
    ) -> NSFetchedResultsController<NSFetchRequestResult> {
        let hideDistributionLists = !ThreemaEnvironment.distributionListsActive
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.relationshipKeyPathsForPrefetching = ["members"]
        fetchRequest.fetchBatchSize = 20
        fetchRequest.predicate = .and(
            .conversationIsArchived,
            .conversationHasLastUpdate,
            hideDistributionLists ? .not(.conversationIsDistributionList) : nil,
            hidePrivateChats ? .not(.conversationIsPrivate) : nil,
            .conversationContactIsVisible
        )
        let visibilityDescriptor = NSSortDescriptor(key: "visibility", ascending: false)
        let lastUpdateDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        let lastMessageDescriptor = NSSortDescriptor(key: "lastMessage.date", ascending: false)
        fetchRequest.sortDescriptors = [visibilityDescriptor, lastUpdateDescriptor, lastMessageDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    public func fetchedResultsControllerForWebClientSessionEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WebClientSession")
        fetchRequest.fetchBatchSize = 20
        
        let activeDescriptor = NSSortDescriptor(key: "active", ascending: false)
        let lastConnectionDescriptor = NSSortDescriptor(key: "lastConnection", ascending: false)

        fetchRequest.sortDescriptors = [activeDescriptor, lastConnectionDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - FileMessages
    
    /// Creates a fetch results controller for the media grid in gallery
    ///
    /// If `mediaMessagesRequireInMemoryFiltering` is set, filter the results with `filterMediaMessages(_:cache:)`.
    ///
    /// - Parameter conversationID: `NSManagedObjectID` of the conversation
    /// - Returns: NSFetchedResultsController for `BaseMessages` that can be displayed in media grid, Image, Videos
    /// etc., no audio and files.
    public func mediaMessagesFetchResultsController(for conversationID: NSManagedObjectID) -> NSFetchedResultsController<
        BaseMessageEntity
    > {
        let fileMessageEntity = NSEntityDescription.entity(forEntityName: "FileMessage", in: managedObjectContext)!
        let imageMessageEntity = NSEntityDescription.entity(forEntityName: "ImageMessage", in: managedObjectContext)!
        let videoMessageEntity = NSEntityDescription.entity(forEntityName: "VideoMessage", in: managedObjectContext)!

        // Encrypted values can only be checked for `nil` in the store, the rest is done by `filterMediaMessages`
        let encrypted = mediaMessagesRequireInMemoryFiltering
        let deletedAtFieldName = BaseMessageEntity.Field.name(for: .deletedAt, encrypted: encrypted)
        let typeFieldName = FileMessageEntity.Field.name(for: .type, encrypted: encrypted)
        let mimeTypeFieldName = FileMessageEntity.Field.name(for: .mimeType, encrypted: encrypted)

        let hasConversationID = NSPredicate(format: "conversation == %@", conversationID)
        let isNotDeleted = NSPredicate(format: "%K == nil", deletedAtFieldName)
        let isMediaFileMessage = NSPredicate.and(
            NSPredicate(format: "self.entity = %@", fileMessageEntity),
            encrypted
                ? NSPredicate(format: "%K != nil", typeFieldName)
                : NSPredicate(format: "%K != 0", typeFieldName),
            // We cannot use the general approach with "mimeType in …" here due to CoreData limitations
            encrypted
                ? NSPredicate(format: "%K != nil", mimeTypeFieldName)
                : NSPredicate(format: "NOT (%K BEGINSWITH 'audio/')", mimeTypeFieldName)
        )
        let isImageMessage = NSPredicate(format: "self.entity = %@", imageMessageEntity)
        let isVideoMessage = NSPredicate(format: "self.entity = %@", videoMessageEntity)

        let fetchRequest = NSFetchRequest<BaseMessageEntity>(entityName: "Message")
        
        fetchRequest.predicate = .and(
            hasConversationID,
            isNotDeleted,
            .or(isMediaFileMessage, isImageMessage, isVideoMessage)
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        fetchRequest.fetchBatchSize = 100
        
        return NSFetchedResultsController<BaseMessageEntity>(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    /// With remote secret the type and mime type of file messages are encrypted and cannot be compared in the store
    public var mediaMessagesRequireInMemoryFiltering: Bool {
        managedObjectContext.usesAdditionallyEncryptedModel
    }

    /// Creation dates (`date`) of the messages matching the predicate, without loading the messages
    public func messageDates(matching predicate: NSPredicate?) -> [NSManagedObjectID: Date] {
        let objectIDExpression = NSExpressionDescription()
        objectIDExpression.name = "objectID"
        objectIDExpression.expression = NSExpression.expressionForEvaluatedObject()
        objectIDExpression.expressionResultType = .objectIDAttributeType

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Message")
        fetchRequest.predicate = predicate
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [objectIDExpression, "date"]

        return managedObjectContext.performAndWait {
            var dates = [NSManagedObjectID: Date]()
            for result in (try? managedObjectContext.fetch(fetchRequest)) ?? [] {
                guard let objectID = result["objectID"] as? NSManagedObjectID,
                      let date = result["date"] as? Date else {
                    continue
                }
                dates[objectID] = date
            }
            return dates
        }
    }

    /// Removes the results of `mediaMessagesFetchResultsController(for:)` the store could not filter
    ///
    /// - Parameters:
    ///   - objectIDs: Results of the fetch request
    ///   - cache: Results of earlier calls, so every message is only loaded once
    /// - Returns: `objectIDs` without the messages not shown in the media browser
    public func filterMediaMessages(
        _ objectIDs: [NSManagedObjectID],
        cache: inout [NSManagedObjectID: Bool]
    ) -> [NSManagedObjectID] {
        guard mediaMessagesRequireInMemoryFiltering else {
            return objectIDs
        }

        managedObjectContext.performAndWait {
            for objectID in objectIDs where cache[objectID] == nil {
                // The store filters everything else
                guard objectID.entity.name == "FileMessage" else {
                    cache[objectID] = true
                    continue
                }

                let fileMessage = try? managedObjectContext.existingObject(with: objectID) as? FileMessageEntity
                cache[objectID] = fileMessage?.isMediaBrowserMedia ?? false
            }
        }

        return objectIDs.filter { cache[$0] == true }
    }
    
    // MARK: - General
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchRequest(for entityName: String) -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return fetchRequest
    }
}

// MARK: - Media browser filter

extension FileMessageEntity {
    /// Encrypted part of the store filter of `EntityFetcher.mediaMessagesFetchResultsController(for:)`, keep in sync
    fileprivate var isMediaBrowserMedia: Bool {
        guard let type = type?.intValue, let mimeType else {
            return false
        }
        return type != 0 && !mimeType.hasPrefix("audio/")
    }
}
