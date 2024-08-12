//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

/// Threema Group Conversation representation used in group calls
public struct GroupCallThreemaGroupModel: Hashable, Sendable {
    // MARK: - Public Properties

    public let groupIdentity: GroupIdentity
    public let groupName: String
    
    // MARK: - Lifecycle

    public init(groupIdentity: GroupIdentity, groupName: String) {
        self.groupIdentity = groupIdentity
        self.groupName = groupName
    }
}

// MARK: - Equatable

extension GroupCallThreemaGroupModel: Equatable {
    public static func == (lhs: GroupCallThreemaGroupModel, rhs: GroupCallThreemaGroupModel) -> Bool {
        lhs.groupIdentity == rhs.groupIdentity
    }
}
