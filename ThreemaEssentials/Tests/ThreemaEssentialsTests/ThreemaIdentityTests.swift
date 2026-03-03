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

@Suite("Threema ID Codable")
struct ThreemaIdentityCodableTests {
    
    @Test("Encode Threema ID")
    func encodeThreemaIdentity() throws {
        let rawIdentity = "ABCDEFGH"
        
        let expectedEncodedString = #"{"string":"\#(rawIdentity)"}"#
        
        let threemaIdentity = ThreemaIdentity(rawIdentity)
        let encodedThreemaIdentity = try JSONEncoder().encode(threemaIdentity)
        let encodedThreemaIdentityString = String(data: encodedThreemaIdentity, encoding: .utf8)
        
        #expect(encodedThreemaIdentityString == expectedEncodedString)
    }
    
    @Test("Decode Threema ID")
    func decodeThreemaIdentity() throws {
        let rawIdentity = "ABCDEFGH"
        
        let expectedThreemaIdentity = ThreemaIdentity(rawIdentity)
        
        let encodedString = #"{"string":"\#(rawIdentity)"}"#
        let decodedThreemaIdentity = try JSONDecoder().decode(ThreemaIdentity.self, from: Data(encodedString.utf8))
        
        #expect(decodedThreemaIdentity == expectedThreemaIdentity)
    }
}
