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
    /// Set `lastMessage` property to correct last message
    /// - Parameter entityManager: Entity manager to be used for the update
    public func updateLastDisplayMessage(with entityManager: EntityManager) {
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
    
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(groupName),
            #keyPath(contact.displayName),
            #keyPath(members),
        ]
    }
    
    @objc public var displayName: String {
        if isGroup {
            if let groupName, !groupName.isEmpty {
                groupName
            }
            else {
                ""
            }
        }
        else if let distributionList {
            distributionList.name ?? ""
        }
        else if let contact {
            contact.displayName
        }
        else {
            ""
        }
    }
}
