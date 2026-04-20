import Foundation

public final class DistributionListManager: NSObject, DistributionListManagerProtocol {
    
    public enum DistributionListError: Error {
        case creationFailure
    }
    
    // MARK: - Private properties

    private let entityManager: EntityManager

    // MARK: - Lifecycle
    
    public init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    // MARK: - Public functions

    public func createDistributionList(
        conversation: ConversationEntity,
        name: String,
        imageData: Data?,
        recipients: Set<Contact>
    ) -> DistributionList? {
        entityManager.performAndWaitSave {
            
            // We check for id collisions with existing objects
            var id = Int64.random(in: 0..<Int64.max)
            var idCollision = self.entityManager.entityFetcher
                .distributionListEntity(for: Int(id)) != nil
           
            while idCollision {
                id = Int64.random(in: 0..<Int64.max)
                idCollision = self.entityManager.entityFetcher
                    .distributionListEntity(for: Int(id)) != nil
            }
            
            let distributionList = self.entityManager.entityCreator.distributionListEntity(
                distributionListID: id,
                conversation: conversation
            )
            distributionList.name = name
            
            let contactEntities: Set<ContactEntity> = Set(recipients.compactMap {
                self.entityManager.entityFetcher.contactEntity(for: $0.identity.rawValue)
            })
            
            conversation.members = contactEntities
            
            if let imageData, let image = UIImage(data: imageData) {
                let dbImage = self.entityManager.entityCreator.imageDataEntity(data: imageData, size: image.size)
                conversation.groupImage = dbImage
            }
            
            return DistributionList(distributionListEntity: distributionList)
        }
    }

    public func distributionList(for conversation: ConversationEntity) -> DistributionList? {
        entityManager.performAndWait {
            guard let distributionListEntity = self.entityManager.entityFetcher
                .distributionListEntity(for: conversation) else {
                return nil
            }
            
            return DistributionList(distributionListEntity: distributionListEntity)
        }
    }
    
    public func setProfilePicture(of distributionList: DistributionList, to profilePicture: Data?) {
        
        entityManager.performAndWaitSave {
            guard let conversation = self.entityManager.entityFetcher
                .conversationEntity(for: distributionList.distributionListID) else {
                return
            }
            guard let profilePicture else {
                conversation.groupImage = nil
                return
            }
            
            guard let image = UIImage(data: profilePicture) else {
                return
            }
            
            let dbImage = self.entityManager.entityCreator.imageDataEntity(data: profilePicture, size: image.size)
            conversation.groupImage = dbImage
        }
    }
    
    public func setName(of distributionList: DistributionList, to name: String) {
        
        guard distributionList.displayName != name else {
            // Name didn't change
            return
        }
        
        entityManager.performAndWaitSave {
            guard let distributionListEntity = self.entityManager.entityFetcher
                .distributionListEntity(for: distributionList.distributionListID) else {
                return
            }
            distributionListEntity.name = name
        }
    }
    
    public func setRecipients(of distributionList: DistributionList, to recipients: Set<Contact>) {
        
        entityManager.performAndWaitSave {
            guard let conversation = self.entityManager.entityFetcher
                .conversationEntity(for: distributionList.distributionListID) else {
                return
            }
            let contactEntities: Set<ContactEntity> = Set(recipients.compactMap {
                self.entityManager.entityFetcher.contactEntity(for: $0.identity.rawValue)
            })
            
            conversation.members = contactEntities
        }
    }
}
