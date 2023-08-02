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

/// Threema Group Conversation representation used in group calls
public struct GroupCallsThreemaGroupModel: Sendable {
    // MARK: - Public Properties

    public let creator: ThreemaID
    public let groupID: Data
    public let groupName: String
    
    // MARK: - Internal Properties

    let members: Set<ThreemaID>
    
    // MARK: - Lifecycle

    public init(creator: ThreemaID, groupID: Data, groupName: String, members: Set<ThreemaID>) {
        self.creator = creator
        self.groupID = groupID
        self.groupName = groupName
        self.members = members
    }
}

// MARK: - Equatable

extension GroupCallsThreemaGroupModel: Equatable {
    public static func == (lhs: GroupCallsThreemaGroupModel, rhs: GroupCallsThreemaGroupModel) -> Bool {
        lhs.groupID == rhs.groupID && lhs.creator.id == rhs.creator.id
    }
}

// MARK: - Hashable

extension GroupCallsThreemaGroupModel: Hashable { }
