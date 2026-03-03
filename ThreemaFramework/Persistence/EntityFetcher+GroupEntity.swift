//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

extension EntityFetcher {
    
    public func groupEntity(for groupIdentity: GroupIdentity, myIdentity: String) -> GroupEntity? {
        let predicate = groupCreatorIDPredicate(
            creator: groupIdentity.creator.rawValue == myIdentity ? nil : groupIdentity.creator.rawValue,
            id: groupIdentity.id
        )
        return fetchEntity(entityName: "Group", predicate: predicate)
    }
    
    public func groupEntity(for groupID: Data) -> GroupEntity? {
        let predicate = groupCreatorIDPredicate(creator: nil, id: groupID)
        return fetchEntity(entityName: "Group", predicate: predicate)
    }
    
    public func groupEntities(for groupID: Data) -> [GroupEntity]? {
        let predicate = groupIDPredicate(id: groupID)
        return fetchEntities(entityName: "Group", predicate: predicate)
    }
    
    @objc public func groupEntity(for conversationEntity: ConversationEntity) -> GroupEntity? {
        guard conversationEntity.isGroup, let groupID = conversationEntity.groupID else {
            return nil
        }
        let predicate = groupCreatorIDPredicate(creator: conversationEntity.contact?.identity ?? nil, id: groupID)
        return fetchEntity(entityName: "Group", predicate: predicate)
    }
    
    /// All active groups (i.e. not marked as (force) left)
    /// - Returns: An array of group entities for all active groups
    public func activeGroupEntities() -> [GroupEntity]? {
        let predicate = groupActivePredicate()
        return fetchEntities(entityName: "Group", predicate: predicate)
    }
    
    // MARK: - Predicates
    
    func groupCreatorIDPredicate(creator: String?, id: Data) -> NSPredicate {
        if let creator {
            NSPredicate(format: "groupId == %@ AND groupCreator == %@", id as CVarArg, creator)
        }
        else {
            NSPredicate(format: "groupId == %@ AND groupCreator == nil", id as CVarArg)
        }
    }
    
    func groupIDPredicate(id: Data) -> NSPredicate {
        NSPredicate(format: "groupId == %@", id as CVarArg)
    }
    
    func groupActivePredicate() -> NSPredicate {
        NSPredicate(
            format: "NOT (state == %ld OR state == %ld)",
            GroupEntity.GroupState.left.rawValue,
            GroupEntity.GroupState.forcedLeft.rawValue
        )
    }
}
