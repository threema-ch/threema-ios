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
import ThreemaProtocols

public struct GroupIdentity: Equatable, Hashable, CustomStringConvertible, Sendable, Codable {
    public enum Error: Swift.Error {
        case invalidCreatorIdentityLength
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, creator
    }
    
    /// Expected length of `id`
    public static let idLength = 8

    public let id: Data
    public let creator: ThreemaIdentity

    public init(id: Data, creator: ThreemaIdentity) {
        if id.count != GroupIdentity.idLength {
            assertionFailure("Tried to create a GroupIdentity with id length of \(id.count)")
            DDLogError("Tried to create a GroupIdentity with id length of \(id.count)")
        }

        self.id = id
        self.creator = creator
    }

    // MARK: - Common_GroupIdentity helper
    
    /// Create new group identity from `Common_GroupIdentity`
    /// - Parameter commonGroupIdentity: Common Group Identity to use
    /// - Throws: `GroupIdentity.Error` if `commonGroupIdentity` is not a valid group identity
    public init(commonGroupIdentity: Common_GroupIdentity) throws {
        // `commonGroupIdentity.groupID` will always be valid, also if it is 0
        
        guard commonGroupIdentity.creatorIdentity.count == ThreemaIdentity.stringLength else {
            throw Error.invalidCreatorIdentityLength
        }
        
        self.init(
            id: commonGroupIdentity.groupID.littleEndianData,
            creator: ThreemaIdentity(commonGroupIdentity.creatorIdentity)
        )
    }
    
    public var asCommonGroupIdentity: Common_GroupIdentity {
        var commonGroupIdentity = Common_GroupIdentity()
        commonGroupIdentity.groupID = id.paddedLittleEndian()
        commonGroupIdentity.creatorIdentity = creator.string
        return commonGroupIdentity
    }

    // MARK: - CustomStringConvertible
    
    public var description: String {
        "id: \(id.hexString) creator: \(creator)"
    }
}
