
import CocoaLumberjackSwift
import Foundation

public final class PersistenceMigration {
    
    let entityManager: EntityManager
    
    public init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    public func migrateDataAvailable(remoteSecretEnabled: Bool) throws {
       
        // Audio
        let audioEntityName = AudioMessageEntity.entityName
        let audioFieldName = AudioMessageEntity.Field.name(for: .dataAvailable, encrypted: remoteSecretEnabled)

        let audioNotNilPredicate = NSPredicate(format: "audio != nil")
        updateDataAvailable(
            entityName: audioEntityName,
            fieldName: audioFieldName,
            predicate: audioNotNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: true
        )
        
        let audioNilPredicate = NSPredicate(format: "audio == nil")
        updateDataAvailable(
            entityName: audioEntityName,
            fieldName: audioFieldName,
            predicate: audioNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: false
        )
        
        // File
        // For `FileMessageEntities` we need to check if `data.data` is nil, since it's optional. We need an extra fetch
        // for that.
        let fileEntityName = FileMessageEntity.entityName
        let fileFieldName = FileMessageEntity.Field.name(for: .dataAvailable, encrypted: remoteSecretEnabled)

        let em = entityManager
       
        let objectIDs = try em.performAndWait {
            try em.entityFetcher.fileMessageObjectIDsWithDataAvailable()
        }
        let fileNotNilPredicate = NSPredicate(format: "self IN %@", objectIDs)
        updateDataAvailable(
            entityName: fileEntityName,
            fieldName: fileFieldName,
            predicate: fileNotNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: true
        )
    
        let fileNilPredicate = NSPredicate(format: "NOT(self IN %@)", objectIDs)
        updateDataAvailable(
            entityName: fileEntityName,
            fieldName: fileFieldName,
            predicate: fileNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: false
        )
        
        // Image
        let imageEntityName = ImageMessageEntity.entityName
        let imageFieldName = ImageMessageEntity.Field.name(for: .dataAvailable, encrypted: remoteSecretEnabled)

        let imageNotNilPredicate = NSPredicate(format: "image != nil")
        updateDataAvailable(
            entityName: imageEntityName,
            fieldName: imageFieldName,
            predicate: imageNotNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: true
        )
        
        let imageNilPredicate = NSPredicate(format: "image == nil")
        updateDataAvailable(
            entityName: imageEntityName,
            fieldName: imageFieldName,
            predicate: imageNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: false
        )
        
        // Video
        let videoEntityName = VideoMessageEntity.entityName
        let videoFieldName = VideoMessageEntity.Field.name(for: .dataAvailable, encrypted: remoteSecretEnabled)

        let videoNotNilPredicate = NSPredicate(format: "video != nil")
        updateDataAvailable(
            entityName: videoEntityName,
            fieldName: videoFieldName,
            predicate: videoNotNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: true
        )
        
        let videoNilPredicate = NSPredicate(format: "video == nil")
        updateDataAvailable(
            entityName: videoEntityName,
            fieldName: videoFieldName,
            predicate: videoNilPredicate,
            remoteSecretEnabled: remoteSecretEnabled,
            available: false
        )
        
        // Shared upate function
        func updateDataAvailable(
            entityName: String,
            fieldName: String,
            predicate: NSPredicate,
            remoteSecretEnabled: Bool,
            available: Bool
        ) {
            entityManager.performAndWaitSave {
                
                let batch = NSBatchUpdateRequest(entityName: entityName)
                batch.resultType = .statusOnlyResultType
                batch.predicate = predicate
               
                let value: Any = remoteSecretEnabled ? EntityCryptoManager.shared.encrypt(available) : NSNumber(
                    booleanLiteral: available
                )
                batch.propertiesToUpdate = [fieldName: value]
                
                // If there was an error, the execute function will return nil or a result with the result 0
                if let result = self.entityManager.entityFetcher.execute(batchUpdateRequest: batch) {
                    if let success = result.result as? Int,
                       success == 0 {
                        DDLogError(
                            "[PersistenceMigration] Failed to set data available for \(entityName)"
                        )
                    }
                }
                else {
                    DDLogError(
                        "[PersistenceMigration] Failed to set data available for \(entityName)"
                    )
                }
                self.entityManager.refreshAllObjects()
            }
        }
    }
    
    public func migrateReadMessageReactions(remoteSecretEnabled: Bool) throws {
        entityManager.performAndWaitSave {
            
            let batch = NSBatchUpdateRequest(entityName: MessageReactionEntity.entityName)
            batch.resultType = .statusOnlyResultType
           
            let fieldName = MessageReactionEntity.Field.name(for: .readAt, encrypted: remoteSecretEnabled)
            let readAt = Date()
            let readAtValue: Any = remoteSecretEnabled ? EntityCryptoManager.shared.encrypt(readAt) : readAt
            batch.propertiesToUpdate = [fieldName: readAtValue]
            
            // If there was an error, the execute function will return nil or a result with the result 0
            if let result = self.entityManager.entityFetcher.execute(batchUpdateRequest: batch) {
                if let success = result.result as? Int,
                   success == 0 {
                    DDLogError(
                        "[PersistenceMigration] Failed to set read value for \(MessageReactionEntity.entityName)"
                    )
                }
            }
            else {
                DDLogError(
                    "[PersistenceMigration] Failed to set \(MessageReactionEntity.entityName)"
                )
            }
            self.entityManager.refreshAllObjects()
        }
    }
}
