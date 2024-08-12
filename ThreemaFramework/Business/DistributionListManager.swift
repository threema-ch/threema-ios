//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
        conversation: Conversation,
        name: String,
        imageData: Data?,
        recipients: Set<Contact>
    ) throws {
        try entityManager.performAndWaitSave {
            
            guard let distributionList = self.entityManager.entityCreator.distributionListEntity() else {
                throw DistributionListManager.DistributionListError.creationFailure
            }
            
            // We check for id collisions with existing objects
            var id = Int64.random(in: 0..<Int64.max)
            var idCollision = self.entityManager.entityFetcher
                .distributionListEntity(forDistributionListID: id as NSNumber) != nil
           
            while idCollision {
                id = Int64.random(in: 0..<Int64.max)
                idCollision = self.entityManager.entityFetcher
                    .distributionListEntity(forDistributionListID: id as NSNumber) != nil
            }
            
            distributionList.distributionListID = id
            distributionList.conversation = conversation
            distributionList.name = name
            
            let contactEntities: Set<ContactEntity> = Set(recipients.compactMap {
                self.entityManager.entityFetcher.contact(for: $0.identity.string)
            })
            
            conversation.members = contactEntities
            
            if let imageData, let image = UIImage(data: imageData) {
                let dbImage = self.entityManager.entityCreator.imageData()
                dbImage?.data = imageData
                dbImage?.width = NSNumber(floatLiteral: Double(image.size.width))
                dbImage?.height = NSNumber(floatLiteral: Double(image.size.height))
                conversation.groupImage = dbImage
            }
        }
    }

    public func distributionList(for conversation: Conversation) -> DistributionList? {
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
                .conversation(for: distributionList.distributionListID as NSNumber) else {
                return
            }
            guard let profilePicture else {
                conversation.groupImage = nil
                return
            }
            
            guard let image = UIImage(data: profilePicture) else {
                return
            }
            
            let dbImage = self.entityManager.entityCreator.imageData()
            dbImage?.data = profilePicture
            dbImage?.width = NSNumber(floatLiteral: Double(image.size.width))
            dbImage?.height = NSNumber(floatLiteral: Double(image.size.height))
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
                .distributionListEntity(forDistributionListID: distributionList.distributionListID as NSNumber) else {
                return
            }
            distributionListEntity.name = name
        }
    }
    
    public func setRecipients(of distributionList: DistributionList, to recipients: Set<Contact>) {
        
        entityManager.performAndWaitSave {
            guard let conversation = self.entityManager.entityFetcher
                .conversation(for: distributionList.distributionListID as NSNumber) else {
                return
            }
            let contactEntities: Set<ContactEntity> = Set(recipients.compactMap {
                self.entityManager.entityFetcher.contact(for: $0.identity.string)
            })
            
            conversation.members = contactEntities
        }
    }
}
