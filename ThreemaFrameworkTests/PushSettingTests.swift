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

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class PushSettingTests: XCTestCase {
    func testEncodeDecodeIdentityWithDefaultValues() throws {
        var pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(pushSetting)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        var result = try decoder.decode(PushSetting.self, from: data)

        XCTAssertEqual(result.identity, pushSetting.identity)
        XCTAssertNil(result.groupIdentity)
        XCTAssertEqual(result.type, pushSetting.type)
        XCTAssertEqual(result.muted, pushSetting.muted)
        XCTAssertEqual(result.mentioned, pushSetting.mentioned)
        XCTAssertNil(result.periodOffTillDate)
    }

    func testEncodeDecodeGroupIdentityWithDefaultValues() throws {
        var pushSetting =
            PushSetting(groupIdentity: GroupIdentity(
                id: MockData.generateGroupID(),
                creator: ThreemaIdentity("ECHOECHO")
            ))
        pushSetting.type = .offPeriod
        pushSetting.setPeriodOffTime(.time1Day)

        let encoder = JSONEncoder()
        let data = try encoder.encode(pushSetting)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        var result = try decoder.decode(PushSetting.self, from: data)

        XCTAssertNil(result.identity)
        XCTAssertEqual(result.groupIdentity, pushSetting.groupIdentity)
        XCTAssertEqual(result.type, pushSetting.type)
        XCTAssertEqual(result.muted, pushSetting.muted)
        XCTAssertEqual(result.mentioned, pushSetting.mentioned)
        XCTAssertTrue(result.periodOffTillDate?.compare(Date()) == .orderedDescending)
    }
}
