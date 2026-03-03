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

    @objc public var isGroup: Bool {
        groupID != nil
    }

    public var unwrappedMembers: Set<ContactEntity> {
        members ?? Set<ContactEntity>()
    }

    public var participants: Set<ContactEntity> {
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

        if let id = contact?.identity, id != groupIdentity.creator.rawValue {
            return false
        }

        if contact == nil, myIdentity != groupIdentity.creator.rawValue {
            return false
        }

        return true
    }
}
