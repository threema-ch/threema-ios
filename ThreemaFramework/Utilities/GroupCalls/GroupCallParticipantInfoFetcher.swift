//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import GroupCalls
import ThreemaEssentials

/// Used to fetch info from database to create participants in group calls
public class GroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    
    // MARK: - Properties

    public static let shared = GroupCallParticipantInfoFetcher()
    
    private let businessInjector = BusinessInjector()
    
    // MARK: - Public Functions
    
    public func fetchAvatar(for id: ThreemaIdentity) -> UIImage? {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        let avatar: UIImage?
        
        if let localIdentity = identityStore.identity, localIdentity == id.string,
           let profilePictureDict = identityStore.profilePicture,
           let imageData = profilePictureDict["ProfilePicture"] as? Data, let image = UIImage(data: imageData) {
            if ProcessInfoHelper.isRunningForScreenshots {
                avatar = image
            }
            else {
                avatar = AvatarMaker.shared().maskedProfilePicture(image, size: 40)
            }
        }
        else {
            avatar = entityManager.performAndWait {
                guard let contact = entityManager.entityFetcher.contact(for: id.string) else {
                    // TODO: (IOS-4124) Error handling
                    return nil
                }
                
                let localAvatar: UIImage?
                if ProcessInfoHelper.isRunningForScreenshots {
                    localAvatar = AvatarMaker.shared().avatar(for: contact, size: 200, masked: false, scaled: true)
                }
                else {
                    localAvatar = AvatarMaker.shared().avatar(for: contact, size: 40, masked: true)
                }
                
                if AvatarMaker.shared().isDefaultAvatar(for: contact) {
                    return localAvatar?.withTintColor(.white)
                }
                
                return localAvatar
            }
        }
        
        return avatar
    }
    
    public func fetchDisplayName(for id: ThreemaIdentity) -> String {
        let identityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        let displayName: String
        
        if let localIdentity = identityStore.identity, localIdentity == id.string {
            displayName = "me".localized
        }
        else {
            displayName = entityManager.performAndWait {
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
        let idColor: UIColor

        if let localIdentity = identityStore.identity, localIdentity == id.string {
            idColor = IDColor.forData(Data(id.string.utf8))
        }
        else {
            idColor = entityManager.performAndWait {
                guard let contact = entityManager.entityFetcher.contact(for: id.string) else {
                    return .primary
                }
                
                return contact.idColor
            }
        }
        
        return idColor
    }
}
