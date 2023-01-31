//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class PendingUserNotificationTests: XCTestCase {

    func testEncodeDecode() throws {
        let expectedMessageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedKey = "sender\(expectedMessageID.hexString)"
        let expectedText = "123"

        let boxTextMessage = BoxTextMessage()
        boxTextMessage.messageID = expectedMessageID
        boxTextMessage.text = "123"

        let pendingUserNotification = PendingUserNotification(key: expectedKey)
        pendingUserNotification.abstractMessage = boxTextMessage

        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(pendingUserNotification, forKey: "key")
        archiver.finishEncoding()

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let decodedObject = try unarchiver.decodeTopLevelObject(of: [PendingUserNotification.self], forKey: "key")

        XCTAssertTrue(decodedObject is PendingUserNotification)
        let decodedPendingUserNotification = try XCTUnwrap(decodedObject as? PendingUserNotification)
        XCTAssertEqual(decodedPendingUserNotification.key, expectedKey)

        XCTAssertTrue(decodedPendingUserNotification.abstractMessage is BoxTextMessage)
        let decodedBoxTextMessage = try XCTUnwrap(decodedPendingUserNotification.abstractMessage as? BoxTextMessage)
        XCTAssertEqual(decodedBoxTextMessage.messageID, expectedMessageID)
        XCTAssertEqual(decodedBoxTextMessage.text, expectedText)
    }
}
