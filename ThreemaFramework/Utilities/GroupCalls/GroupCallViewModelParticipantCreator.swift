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

/// Used to fetch info from database to create participants in group calls
public class GroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    
    // MARK: - Properties

    public static let shared = GroupCallParticipantInfoFetcher()
    
    private let businessInjector = BusinessInjector()
    
    // MARK: - Public Functions
    
    public func fetchInfo(id: String) -> (displayName: String?, avatar: UIImage?, color: UIColor) {
        let entityManager = businessInjector.entityManager

        var displayName: String?
        var avatar: UIImage?
        var idColor = UIColor.primary
        
        entityManager.performBlockAndWait {
            guard let contact = entityManager.entityFetcher.contact(for: id) else {
                // TODO: error handling
                return
            }
            avatar = AvatarMaker.shared().avatar(for: contact, size: 40, masked: true)
            
            if AvatarMaker.shared().isDefaultAvatar(for: contact) {
                avatar = avatar?.withTintColor(.white)
            }
            
            displayName = contact.displayName
            idColor = contact.idColor
        }
        
        return (displayName, avatar, idColor)
    }
    
    public func fetchInfoForLocalIdentity() -> (displayName: String?, avatar: UIImage?, color: UIColor) {
        let identityStore = MyIdentityStore.shared()
        
        let displayName = BundleUtil.localizedString(forKey: "me")
        let idColor = identityStore?.idColor ?? .primary
        
        var avatar: UIImage?
        
        if let profilePictureDict = identityStore?.profilePicture,
           let imageData = profilePictureDict["ProfilePicture"] as? Data, let image = UIImage(data: imageData) {
            avatar = AvatarMaker.shared().maskedProfilePicture(image, size: 40)
        }
        
        return (displayName, avatar, idColor)
    }
}
