import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaEssentials
import ThreemaMacros

/// Used to fetch info from database to create participants in group calls
public final class GroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    
    // MARK: - Properties

    public static let shared = GroupCallParticipantInfoFetcher()
    
    private let businessInjector = BusinessInjector()
    
    // MARK: - Public Functions
    
    public func fetchProfilePicture(for id: ThreemaIdentity) -> UIImage {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        
        // swiftformat:disable:next conditionalAssignment
        if let localIdentity = identityStore.identity, localIdentity == id.rawValue {
            return identityStore.resolvedGroupCallProfilePicture
        }
        else {
            return entityManager.performAndWait {
                guard let contactEntity = entityManager.entityFetcher.contactEntity(for: id.rawValue) else {
                    return ProfilePictureGenerator.unknownContactGroupCallsImage
                }
                let contact = Contact(contactEntity: contactEntity)
                return contact.profilePictureForGroupCalls()
            }
        }
    }
    
    public func fetchDisplayName(for id: ThreemaIdentity) -> String {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        let displayName: String =
            if let localIdentity = identityStore.identity, localIdentity == id.rawValue {
                #localize("me")
            }
            else {
                entityManager.performAndWait {
                    guard let contact = entityManager.entityFetcher.contactEntity(for: id.rawValue) else {
                        return id.rawValue
                    }
                
                    return contact.displayName
                }
            }
        
        return displayName
    }
    
    public func fetchIDColor(for id: ThreemaIdentity) -> UIColor {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        let idColor: UIColor =
            if let localIdentity = identityStore.identity, localIdentity == id.rawValue {
                IDColor.forData(Data(id.rawValue.utf8))
            }
            else {
                entityManager.performAndWait {
                    guard let contact = entityManager.entityFetcher.contactEntity(for: id.rawValue) else {
                        return .tintColor
                    }
                
                    return contact.idColor
                }
            }
        
        return idColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }
    
    public func isIdentity(_ identity: ThreemaIdentity, memberOfGroupWith groupID: GroupIdentity) -> Bool {
        let groupManager = businessInjector.groupManager
        
        guard let group = groupManager.group(for: groupID) else {
            DDLogError("[GroupCall] Did not find group to check if participant is member in.")
            return false
        }
        
        return group.isMember(identity: identity.rawValue)
    }
}
