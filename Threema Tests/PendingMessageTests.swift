//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

@testable import Threema

class PendingMessageTests: XCTestCase {
    
    func testArchivePendingMessage() throws {
        // Inputs
        
        let senderId = "ABCDEFGH"
        let messageId = "0123456789abcdef"
        
        let threemaDict = [
            "cmd": "newmsg",
            "from": senderId,
            "nick": "Hansmuster",
            "messageId": messageId,
            "voip": "true",
        ]
        
        // Expected data
        
        let threemPushNotification = try ThreemaPushNotification(from: threemaDict)

        // Processing
        
        let pendingMessage = PendingMessage(senderIdentity: senderId, messageIdentity: messageId, pushPayload: threemaDict)
        let archivedPendingMessage = NSKeyedArchiver.archivedData(withRootObject: pendingMessage)
        
        let unarchivedMessage = NSKeyedUnarchiver.unarchiveObject(with: archivedPendingMessage) as? PendingMessage
        
        // Validation
        
        let message = try XCTUnwrap(unarchivedMessage)
        let actualThreemaPush = try XCTUnwrap(message.threemaPushNotification)
        
        XCTAssertEqual(message.senderId, senderId)
        XCTAssertEqual(message.messageId, messageId)
        verifyThreemPushNotifiaction(actual: actualThreemaPush, expected: threemPushNotification)
    }
    
    func testArchivePendingMessageNoVoip() throws {
        // Inputs
        
        let senderId = "ABCDEFGH"
        let messageId = "0123456789abcdef"
        
        let threemaDict = [
            "cmd": "newmsg",
            "from": senderId,
            "nick": "Hansmuster",
            "messageId": messageId,
        ]
        
        // Expected data
        
        let threemPushNotification = try ThreemaPushNotification(from: threemaDict)

        // Processing
        
        let pendingMessage = PendingMessage(senderIdentity: senderId, messageIdentity: messageId, pushPayload: threemaDict)
        let archivedPendingMessage = NSKeyedArchiver.archivedData(withRootObject: pendingMessage)
        
        let unarchivedMessage = NSKeyedUnarchiver.unarchiveObject(with: archivedPendingMessage) as? PendingMessage
        
        // Validation
        
        let message = try XCTUnwrap(unarchivedMessage)
        let actualThreemaPush = try XCTUnwrap(message.threemaPushNotification)
        
        XCTAssertEqual(message.senderId, senderId)
        XCTAssertEqual(message.messageId, messageId)
        verifyThreemPushNotifiaction(actual: actualThreemaPush, expected: threemPushNotification)
    }
    
    func testUnarchivingOldThreemaPushNotificationDictionary() throws {
        // Expected data
        
        let senderId = "ABCDEFGH"
        let messageId = "0123456789abcdef"
        
        let threemaDict = [
            "cmd": "newmsg",
            "from": senderId,
            "nick": "Hansmuster",
            "messageId": messageId,
            "voip": "true",
        ]
        
        let threemPushNotification = try ThreemaPushNotification(from: threemaDict)

        // Processing
        
        let testBundle = Bundle(for: PendingMessageTests.self)
        let tempArchivePath = testBundle.path(forResource: "PendingMessage", ofType: "plist", inDirectory: nil)
        let archivePath = try XCTUnwrap(tempArchivePath)

        let unarchivedMessage = NSKeyedUnarchiver.unarchiveObject(withFile: archivePath) as? PendingMessage

        // Validation

        let message = try XCTUnwrap(unarchivedMessage)
        let actualThreemaPush = try XCTUnwrap(message.threemaPushNotification)
        
        XCTAssertEqual(message.senderId, senderId)
        XCTAssertEqual(message.messageId, messageId)
        verifyThreemPushNotifiaction(actual: actualThreemaPush, expected: threemPushNotification)
    }
    
    func testUnarchivingOldThreemaPushNotificationDictionaryNoVoip() throws {
        // Expected data
        
        let senderId = "ABCDEFGH"
        let messageId = "0123456789abcdef"
        
        let threemaDict = [
            "cmd": "newmsg",
            "from": senderId,
            "nick": "Hansmuster",
            "messageId": messageId,
        ]
        
        let threemPushNotification = try ThreemaPushNotification(from: threemaDict)

        // Processing
        
        let testBundle = Bundle(for: PendingMessageTests.self)
        let tempArchivePath = testBundle.path(forResource: "PendingMessageNoVoip", ofType: "plist", inDirectory: nil)
        let archivePath = try XCTUnwrap(tempArchivePath)

        let unarchivedMessage = NSKeyedUnarchiver.unarchiveObject(withFile: archivePath) as? PendingMessage

        // Validation

        let message = try XCTUnwrap(unarchivedMessage)
        let actualThreemaPush = try XCTUnwrap(message.threemaPushNotification)
        
        XCTAssertEqual(message.senderId, senderId)
        XCTAssertEqual(message.messageId, messageId)
        verifyThreemPushNotifiaction(actual: actualThreemaPush, expected: threemPushNotification)
    }
    
}

// MARK: - Helper functions
private extension PendingMessageTests {
    func verifyThreemPushNotifiaction(actual: ThreemaPushNotification, expected: ThreemaPushNotification) {
        XCTAssertEqual(actual.command, expected.command)
        XCTAssertEqual(actual.from, expected.from)
        XCTAssertEqual(actual.nickname, expected.nickname)
        XCTAssertEqual(actual.messageId, expected.messageId)
        XCTAssertEqual(actual.voip, expected.voip)
    }
}
