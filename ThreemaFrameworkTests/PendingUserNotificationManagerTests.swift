//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
@testable import ThreemaFramework

class PendingUserNotificationManagerTests: XCTestCase {

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        FileUtility.delete(at: URL(fileURLWithPath: PendingUserNotificationManager.pathPendingUserNotifications))
        FileUtility.delete(at: URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications))
        
        PendingUserNotificationManager.clear()
    }
    
    func testPendingUserNotificationAbstractMessage() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"
        
        let abstractMsg = BoxTextMessage()
        abstractMsg.text = "Test 1234"
        abstractMsg.messageID = expectedMessageID
        abstractMsg.fromIdentity = expectedFromIdentity
        
        let pendingManager1 = PendingUserNotificationManager(
            UserNotificationManagerMock(),
            UserNotificationCenterManagerMock(),
            EntityManager()
        )
        let pendingNotification1 = pendingManager1.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract,
            isPendingGroup: false
        )
        
        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification1?.key)
        
        PendingUserNotificationManager.clear()

        let pendingManager2 = PendingUserNotificationManager(
            UserNotificationManagerMock(),
            UserNotificationCenterManagerMock(),
            EntityManager()
        )
        let pendingNotification2 = pendingManager2.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract,
            isPendingGroup: false
        )
        
        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification2?.key)
        XCTAssertEqual(pendingNotification2?.stage, .abstract)
    }

    func testPendingUserNotificationAbstractMessageStartTimedNotification() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"
        let expectedFireDateGreaterThan = Date()
        
        let abstractMsg = BoxTextMessage()
        abstractMsg.text = "Test 1234"
        abstractMsg.messageID = expectedMessageID
        abstractMsg.fromIdentity = expectedFromIdentity
        
        let expectedPendingUserNotification = PendingUserNotification(key: "1")
        expectedPendingUserNotification.abstractMessage = abstractMsg
        
        let expectedUserNotificationContent = UserNotificationContent(expectedPendingUserNotification)
        
        let pendingManager = PendingUserNotificationManager(
            UserNotificationManagerMock(returnUserNotificationContent: expectedUserNotificationContent),
            UserNotificationCenterManagerMock(returnFireDate: Date()),
            EntityManager()
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract,
            isPendingGroup: false
        )
        
        let expect = expectation(description: "startTimedUserNotification")

        var result = false
        
        pendingManager.startTimedUserNotification(pendingUserNotification: pendingNotification!)
            .done { processed in
                result = processed
                expect.fulfill()
            }
        
        waitForExpectations(timeout: 3) { error in
            if let error {
                print(error.localizedDescription)
                XCTFail()
            }
            else {
                XCTAssertTrue(result)
                XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification?.key)
                XCTAssertNotNil(pendingNotification?.abstractMessage)
                XCTAssertEqual(UserNotificationStage.abstract, pendingNotification?.stage)
                XCTAssertNotNil(pendingNotification?.fireDate)
                if let fireDate = pendingNotification?.fireDate {
                    XCTAssertTrue(expectedFireDateGreaterThan < fireDate)
                }
            }
        }
    }

    func testPendingUserNotificationAbstractMessageStartTimedNotificationControlMessage() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"
        let expectedFireDateGreaterThan = Date()

        let abstractMsg = ContactRequestPhotoMessage()
        abstractMsg.messageID = expectedMessageID
        abstractMsg.fromIdentity = expectedFromIdentity

        let expectedPendingUserNotification = PendingUserNotification(key: "1")
        expectedPendingUserNotification.abstractMessage = abstractMsg

        let expectedUserNotificationContent = UserNotificationContent(expectedPendingUserNotification)

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())

        let pendingManager = PendingUserNotificationManager(
            UserNotificationManagerMock(returnUserNotificationContent: expectedUserNotificationContent),
            userNotificationCenterManagerMock,
            EntityManager()
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract,
            isPendingGroup: false
        )

        let expect = expectation(description: "startTimedUserNotification")

        var result = false

        pendingManager.startTimedUserNotification(pendingUserNotification: pendingNotification!)
            .done { processed in
                result = processed
                expect.fulfill()
            }

        wait(for: [expect], timeout: 3)

        XCTAssertTrue(result)
        XCTAssertTrue(try userNotificationCenterManagerMock.removeCalls.contains(XCTUnwrap(pendingNotification?.key)))
        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification?.key)
        XCTAssertNotNil(pendingNotification?.abstractMessage)
        XCTAssertEqual(UserNotificationStage.abstract, pendingNotification?.stage)
        XCTAssertNil(pendingNotification?.fireDate)
    }
}
