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

import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

public struct GroupIdentity: Equatable, Hashable, CustomStringConvertible, Sendable, Codable {
    private enum CodingKeys: String, CodingKey {
        case id, creator
    }

    public let id: Data
    public let creator: ThreemaIdentity

    public init(id: Data, creator: ThreemaIdentity) {
        if id.count != 8 {
            assertionFailure("Tried to create a GroupIdentity with id length of \(id.count)")
            DDLogError("Tried to create a GroupIdentity with id length of \(id.count)")
        }

        self.id = id
        self.creator = creator
    }

    public init(identity: Common_GroupIdentity) {
        self.init(id: identity.groupID.littleEndianData, creator: ThreemaIdentity(identity.creatorIdentity))
    }

    public var description: String {
        "id: \(id.hexString) creator: \(creator)"
    }
}
