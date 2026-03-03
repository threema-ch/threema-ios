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
import Testing
@testable import ThreemaEssentials

@Suite("Group Identity Codable")
struct GroupIdentityCodableTests {
    
    @Test("Encode Group Identity")
    func encodeGroupIdentity() throws {
        let rawGroupIdentity = Data(repeating: 1, count: GroupIdentity.idLength)
        let rawIdentity = "ABCDEFGH"
        
        let expectedEncodedString =
            #"{"creator":{"string":"\#(rawIdentity)"},"id":"\#(rawGroupIdentity.base64EncodedString())"}"#
        
        let groupIdentity = GroupIdentity(id: rawGroupIdentity, creator: ThreemaIdentity(rawIdentity))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encodedGroupIdentity = try encoder.encode(groupIdentity)
        let encodedGroupIdentityString = String(data: encodedGroupIdentity, encoding: .utf8)
        
        #expect(encodedGroupIdentityString == expectedEncodedString)
    }
    
    @Test("Decode Group Identity")
    func decodeGroupIdentity() throws {
        let rawGroupIdentity = Data(repeating: 2, count: GroupIdentity.idLength)
        let rawIdentity = "ABCDEFGH"

        let expectedGroupIdentity = GroupIdentity(id: rawGroupIdentity, creator: ThreemaIdentity(rawIdentity))
        
        let encodedString =
            #"{"creator":{"string":"\#(rawIdentity)"},"id":"\#(rawGroupIdentity.base64EncodedString())"}"#
        let decodedGroupIdentity = try JSONDecoder().decode(GroupIdentity.self, from: Data(encodedString.utf8))
        
        #expect(decodedGroupIdentity == expectedGroupIdentity)
    }
}
