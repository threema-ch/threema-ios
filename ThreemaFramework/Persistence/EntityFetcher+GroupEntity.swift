import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

extension EntityFetcher {
    
    public func groupEntity(for groupIdentity: GroupIdentity, myIdentity: String) -> GroupEntity? {
        fetchEntity(
            entityName: "Group",
            predicate: .groupWith(
                creator: groupIdentity.creator.rawValue == myIdentity ? nil : groupIdentity.creator.rawValue,
                id: groupIdentity.id
            )
        )
    }
    
    public func groupEntity(for groupID: Data) -> GroupEntity? {
        fetchEntity(
            entityName: "Group",
            predicate: .groupWith(creator: nil, id: groupID)
        )
    }
    
    public func groupEntities(for groupID: Data) -> [GroupEntity]? {
        fetchEntities(entityName: "Group", predicate: .groupWithID(groupID))
    }
    
    @objc public func groupEntity(for conversationEntity: ConversationEntity) -> GroupEntity? {
        guard conversationEntity.isGroup, let groupID = conversationEntity.groupID else {
            return nil
        }
        return fetchEntity(
            entityName: "Group",
            predicate: .groupWith(creator: conversationEntity.contact?.identity, id: groupID)
        )
    }
    
    /// All active groups (i.e. not marked as (force) left)
    /// - Returns: An array of group entities for all active groups
    public func activeGroupEntities() -> [GroupEntity]? {
        fetchEntities(entityName: "Group", predicate: .groupIsActive)
    }

    /// Fetches a `GroupEntity` with an `NSManagedObjectID`
    /// - Returns: Optional `GroupEntity`
    public func groupEntity(with objectID: NSManagedObjectID) -> GroupEntity? {
        var result: GroupEntity?
        do {
            result = try managedObjectContext.existingObject(with: objectID) as? GroupEntity
        }
        catch {
            DDLogError("[EntityFetcher] Failed to fetch GroupEntity with id: \(objectID). Error: \(error)")
        }
        return result
    }
}
