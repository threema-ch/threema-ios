//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaEssentials

extension ConversationEntity {
    @objc(ConversationCategory) public enum Category: Int {
        case `default`, `private`
    }
    
    @objc(ConversationVisibility) public enum Visibility: Int {
        case `default`, archived, pinned
    }
    
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(groupName),
            #keyPath(contact.displayName),
            #keyPath(members),
        ]
    }
    
    public var groupID: Data? {
        // swiftformat:disable:next acronyms
        groupId
    }
    
    @objc public var isGroup: Bool {
        groupID != nil
    }
    
    @objc public var displayName: String {
        if isGroup {
            if let groupName, !groupName.isEmpty {
                return groupName
            }
            else {
                return ""
            }
        }
        else if let distributionList {
            return distributionList.name ?? ""
        }
        else if let contact {
            return contact.displayName
        }
        return ""
    }
    
    public var unwrappedMembers: Set<ContactEntity> {
        members ?? Set<ContactEntity>()
    }
    
    @objc public var participants: Set<ContactEntity> {
        if isGroup {
            if let members {
                members
            }
            else {
                Set<ContactEntity>()
            }
        }
        else {
            if let contact {
                Set<ContactEntity>([contact])
            }
            else {
                Set<ContactEntity>()
            }
        }
    }
    
    /// Set `lastMessage` property to correct last message
    /// - Parameter entityManager: Entity manager to be used for the update
    @objc public func updateLastDisplayMessage(with entityManager: EntityManager) {
        entityManager.performAndWaitSave {
            let messageFetcher = MessageFetcher(for: self, with: entityManager)
            guard let message = messageFetcher.lastDisplayMessage() else {
                self.lastMessage = nil
                return
            }
            
            guard self.lastMessage != message else {
                return
            }
            
            self.lastMessage = message
        }
    }
    
    /// Checks whether self is the group conversation with given groupID and creator
    /// - Parameters:
    ///   - groupID:
    ///   - creator:
    /// - Returns:
    public func isEqualTo(groupIdentity: GroupIdentity, myIdentity: String) -> Bool {
        
        guard isGroup else {
            return false
        }
    
        guard groupID == groupIdentity.id else {
            return false
        }
    
        if let id = contact?.identity, id != groupIdentity.creator.string {
            return false
        }
    
        if contact == nil, myIdentity != groupIdentity.creator.string {
            return false
        }
        
        return true
    }
}
