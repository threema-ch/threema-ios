//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaEssentials
import ThreemaMacros

/// Used to fetch info from database to create participants in group calls
public class GroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    
    // MARK: - Properties

    public static let shared = GroupCallParticipantInfoFetcher()
    
    private let businessInjector = BusinessInjector()
    
    // MARK: - Public Functions
    
    public func fetchProfilePicture(for id: ThreemaIdentity) -> UIImage {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        
        // swiftformat:disable:next conditionalAssignment
        if let localIdentity = identityStore.identity, localIdentity == id.string {
            return identityStore.resolvedGroupCallProfilePicture
        }
        else {
            return entityManager.performAndWait {
                guard let contactEntity = entityManager.entityFetcher.contact(for: id.string) else {
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
            if let localIdentity = identityStore.identity, localIdentity == id.string {
                #localize("me")
            }
            else {
                entityManager.performAndWait {
                    guard let contact = entityManager.entityFetcher.contact(for: id.string) else {
                        return id.string
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
            if let localIdentity = identityStore.identity, localIdentity == id.string {
                IDColor.forData(Data(id.string.utf8))
            }
            else {
                entityManager.performAndWait {
                    guard let contact = entityManager.entityFetcher.contact(for: id.string) else {
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
        
        return group.isMember(identity: identity.string)
    }
}
