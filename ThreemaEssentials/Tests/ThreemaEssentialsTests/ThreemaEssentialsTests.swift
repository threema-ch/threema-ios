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

import XCTest
@testable import ThreemaEssentials

final class ThreemaEssentialsTests: XCTestCase {
    func testTypeThreemaIdentityDescription() throws {
        let identityString = "ECHOECHO"

        let threemaIdentity = ThreemaIdentity(identityString)

        XCTAssertEqual(threemaIdentity.string, identityString)
        XCTAssertEqual(threemaIdentity.description, identityString)
    }

    func testTypeGroupIdentityDescription() throws {
        let groupID = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        let groupCreator = ThreemaIdentity("ECHOECHO")

        let groupIdentity = GroupIdentity(id: groupID, creator: groupCreator)

        XCTAssertEqual(groupIdentity.id, groupID)
        XCTAssertEqual(groupIdentity.creator, groupCreator)
        XCTAssertEqual(groupIdentity.description, "id: \(groupID.hexString) creator: \(groupCreator)")
    }
}
