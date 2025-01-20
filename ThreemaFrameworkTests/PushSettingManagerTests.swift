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

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class PushSettingManagerTests: XCTestCase {
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    func testSaveAndFind() async throws {
        let userSettingsMock = UserSettingsMock()

        let groupID = MockData.generateGroupID()

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(),
            TaskManagerMock(),
            false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("ECHOECHO")), sync: false)
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO"))),
            sync: false
        )

        XCTAssertEqual(userSettingsMock.pushSettings.count, 2)

        let pushSettingContact = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(pushSettingContact.identity, ThreemaIdentity("ECHOECHO"))

        let pushSettingGroup = pushSettingManager
            .find(forGroup: GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO")))

        XCTAssertEqual(pushSettingGroup.groupIdentity, GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO")))
    }

    func testSaveAndDelete() async throws {
        let userSettingsMock = UserSettingsMock()

        let groupID = MockData.generateGroupID()

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(),
            TaskManagerMock(),
            false
        )
        let pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"), groupIdentity: nil, _type: .off)
        await pushSettingManager.save(pushSetting: pushSetting, sync: false)

        XCTAssertEqual(userSettingsMock.pushSettings.count, 1)

        await pushSettingManager.delete(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(userSettingsMock.pushSettings.count, 0)
    }

    func testSaveAndUpdate() async throws {
        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(),
            TaskManagerMock(),
            false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("ECHOECHO")), sync: false)

        XCTAssertEqual(userSettingsMock.pushSettings.count, 1)

        var pushSetting = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(pushSetting.identity, ThreemaIdentity("ECHOECHO"))
        XCTAssertEqual(pushSetting.type, .on)
        XCTAssertNil(pushSetting.periodOffTillDate)

        // Update push setting and save
        pushSetting.type = .off
        pushSetting.setPeriodOffTime(.time1Hour)
        await pushSettingManager.save(pushSetting: pushSetting, sync: false)

        var updatedPushSetting = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))
        XCTAssertEqual(updatedPushSetting.type, .off)
        XCTAssertNotNil(updatedPushSetting.periodOffTillDate)
    }

    func testSaveIdentityAndGroupIdentity() async throws {
        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(),
            TaskManagerMock(),
            false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID01")), sync: false)
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID02")), sync: false)
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID02")), sync: false)
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: MockData.generateGroupID(),
                creator: ThreemaIdentity("TESTID01")
            )),
            sync: false
        )

        let groupID = MockData.generateGroupID()
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: groupID,
                creator: ThreemaIdentity("TESTID02")
            )),
            sync: false
        )
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: groupID,
                creator: ThreemaIdentity("TESTID02")
            )),
            sync: false
        )

        XCTAssertEqual(userSettingsMock.pushSettings.count, 4)
    }

    func testSaveNSOrderedSet() throws {

        enum pushSettingError: Error {
            case decodingFailed
        }

        let pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(pushSetting)

        let pushSettingList = NSOrderedSet(array: [data])
        let pushSettings = try pushSettingList.map { item in
            guard let data = item as? Data else {
                throw pushSettingError.decodingFailed
            }
            
            return try decoder.decode(PushSetting.self, from: data)
        }

        let result = pushSettings.filter { item in
            item.identity == ThreemaIdentity("ECHOECHO")
        }

        XCTAssertEqual(result.count, 1)
    }
}
