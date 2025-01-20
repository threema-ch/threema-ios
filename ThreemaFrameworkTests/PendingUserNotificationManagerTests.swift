//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class PendingUserNotificationManagerTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        FileUtility.shared.delete(at: URL(fileURLWithPath: PendingUserNotificationManager.pathPendingUserNotifications))
        FileUtility.shared
            .delete(at: URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications))
        
        PendingUserNotificationManager.clear()

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()

        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
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
            PushSettingManagerMock(),
            EntityManager()
        )
        let pendingNotification1 = pendingManager1.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
        )

        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification1?.key)

        PendingUserNotificationManager.clear()

        let pendingManager2 = PendingUserNotificationManager(
            UserNotificationManagerMock(),
            UserNotificationCenterManagerMock(),
            PushSettingManagerMock(),
            EntityManager()
        )
        let pendingNotification2 = pendingManager2.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
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

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())

        let pendingManager = PendingUserNotificationManager(
            UserNotificationManagerMock(returnUserNotificationContent: expectedUserNotificationContent),
            userNotificationCenterManagerMock,
            PushSettingManagerMock(),
            EntityManager()
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
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
        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification?.key)
        XCTAssertEqual(pendingNotification?.key, pendingNotification?.contentKey)
        XCTAssertNotNil(pendingNotification?.abstractMessage)
        XCTAssertEqual(UserNotificationStage.abstract, pendingNotification?.stage)
        XCTAssertNotNil(pendingNotification?.fireDate)
        if let fireDate = pendingNotification?.fireDate {
            XCTAssertTrue(expectedFireDateGreaterThan < fireDate)
        }
        XCTAssertTrue(
            try userNotificationCenterManagerMock.addCalls
                .contains(XCTUnwrap(pendingNotification?.contentKey))
        )
    }

    func testPendingUserNotificationAbstractMessageStartTimedNotificationControlMessage() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"

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
            PushSettingManagerMock(),
            EntityManager()
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
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
        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification?.key)
        XCTAssertEqual(pendingNotification?.key, pendingNotification?.contentKey)
        XCTAssertNotNil(pendingNotification?.abstractMessage)
        XCTAssertEqual(UserNotificationStage.abstract, pendingNotification?.stage)
        XCTAssertNil(pendingNotification?.fireDate)
        XCTAssertEqual(userNotificationCenterManagerMock.addCalls.count, 0)
        XCTAssertTrue(try userNotificationCenterManagerMock.removeCalls.contains(XCTUnwrap(pendingNotification?.key)))
    }

    func testPendingUserNotificationStartTimedNotificationEditMessage() throws {
        let expectedFromIdentity = "SENDER01"

        let editMessage = EditMessage()
        editMessage.fromIdentity = expectedFromIdentity

        let editGroupMessage = EditGroupMessage()
        editGroupMessage.fromIdentity = expectedFromIdentity

        for abstractMessage in [editMessage, editGroupMessage] {
            let expectedMessageID = MockData.generateMessageID()
            abstractMessage.messageID = expectedMessageID

            let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
                returnFireDate: Date()
            )
            userNotificationCenterManagerMock.removeCalls.removeAll()

            let pendingManager = PendingUserNotificationManager(
                UserNotificationManagerMock(),
                userNotificationCenterManagerMock,
                PushSettingManagerMock(),
                EntityManager()
            )
            let pendingNotification = pendingManager.pendingUserNotification(
                for: abstractMessage,
                stage: .abstract
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
            XCTAssertEqual(pendingNotification?.key, "\(expectedFromIdentity)\(expectedMessageID.hexString)")
            XCTAssertEqual(pendingNotification?.key, pendingNotification?.contentKey)
            XCTAssertNotNil(pendingNotification?.abstractMessage)
            XCTAssertEqual(pendingNotification?.stage, .abstract)
            XCTAssertNil(pendingNotification?.fireDate)
            XCTAssertEqual(userNotificationCenterManagerMock.addCalls.count, 0)
            XCTAssertTrue(
                try userNotificationCenterManagerMock.removeCalls
                    .contains(XCTUnwrap(pendingNotification?.key))
            )
        }
    }

    func testPendingUserNotificationStartTimedNotificationEditMessageWithBaseMessage() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedFromIdentity = "SENDER01"
        let expectedEditedMessageID = MockData.generateMessageID()

        let abstractMessage = EditMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.fromIdentity = expectedFromIdentity
        let e2eEditMessage = try CspE2e_EditMessage.with { message in
            message.messageID = try expectedMessageID.littleEndian()
        }
        try abstractMessage.fromRawProtoBufMessage(
            rawProtobufMessage: e2eEditMessage.serializedData() as NSData
        )

        let sender = ContactEntity(context: dbMainCnx.current)
        sender.identity = expectedFromIdentity
        let baseMessage = TextMessageEntity(context: dbMainCnx.current, text: "")
        baseMessage.conversation = ConversationEntity(context: dbMainCnx.current)
        baseMessage.sender = sender
        baseMessage.id = expectedEditedMessageID

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
            returnFireDate: Date()
        )

        let pendingManager = PendingUserNotificationManager(
            UserNotificationManagerMock(),
            userNotificationCenterManagerMock,
            PushSettingManagerMock(),
            EntityManager()
        )
        _ = pendingManager.pendingUserNotification(
            for: abstractMessage,
            stage: .abstract
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMessage,
            baseMessage: baseMessage,
            stage: .base
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
        XCTAssertEqual(pendingNotification?.key, "\(expectedFromIdentity)\(expectedMessageID.hexString)")
        XCTAssertNotEqual(pendingNotification?.key, pendingNotification?.contentKey)
        XCTAssertNotNil(pendingNotification?.abstractMessage)
        XCTAssertNotNil(pendingNotification?.baseMessage)
        XCTAssertEqual(pendingNotification?.stage, .base)
        XCTAssertNil(pendingNotification?.fireDate)
        XCTAssertEqual(userNotificationCenterManagerMock.addCalls.count, 0)
        XCTAssertFalse(
            try userNotificationCenterManagerMock.removeCalls
                .contains(XCTUnwrap(pendingNotification?.key))
        )
        XCTAssertTrue(
            try userNotificationCenterManagerMock.removeCalls
                .contains(XCTUnwrap(pendingNotification?.contentKey))
        )
    }

    func testPendingUserNotificationStartTimedNotificationEditMessageWithBaseMessageAndDeliveredNotification() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedFromIdentity = "SENDER01"
        let expectedEditedMessageID = MockData.generateMessageID()

        let abstractMessage = EditMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.fromIdentity = expectedFromIdentity
        let e2eEditMessage = try CspE2e_EditMessage.with { message in
            message.messageID = try expectedMessageID.littleEndian()
        }
        try abstractMessage.fromRawProtoBufMessage(
            rawProtobufMessage: e2eEditMessage.serializedData() as NSData
        )

        let sender = ContactEntity(context: dbMainCnx.current)
        sender.identity = expectedFromIdentity
        let baseMessage = TextMessageEntity(context: dbMainCnx.current, text: "")
        baseMessage.conversation = ConversationEntity(context: dbMainCnx.current)
        baseMessage.sender = sender
        baseMessage.id = expectedEditedMessageID

        let expectedPendingUserNotification =
            PendingUserNotification(key: "\(expectedFromIdentity)\(expectedMessageID.hexString)")
        expectedPendingUserNotification.abstractMessage = abstractMessage
        expectedPendingUserNotification.baseMessage = baseMessage

        let expectedUserNotificationContent = UserNotificationContent(expectedPendingUserNotification)

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
            returnFireDate: Date(),
            deliveredNotifications: ["\(expectedFromIdentity)\(expectedEditedMessageID.hexString)"]
        )

        let pendingManager = PendingUserNotificationManager(
            UserNotificationManagerMock(returnUserNotificationContent: expectedUserNotificationContent),
            userNotificationCenterManagerMock,
            PushSettingManagerMock(),
            EntityManager()
        )
        _ = pendingManager.pendingUserNotification(
            for: abstractMessage,
            stage: .abstract
        )
        let pendingNotification = pendingManager.pendingUserNotification(
            for: abstractMessage,
            baseMessage: baseMessage,
            stage: .base
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
        XCTAssertEqual(pendingNotification?.key, "\(expectedFromIdentity)\(expectedMessageID.hexString)")
        XCTAssertNotEqual(pendingNotification?.key, pendingNotification?.contentKey)
        XCTAssertNotNil(pendingNotification?.abstractMessage)
        XCTAssertNotNil(pendingNotification?.baseMessage)
        XCTAssertEqual(pendingNotification?.stage, .base)
        XCTAssertNotNil(pendingNotification?.fireDate)
        XCTAssertTrue(
            try userNotificationCenterManagerMock.addCalls
                .contains(XCTUnwrap(pendingNotification?.contentKey))
        )
        XCTAssertFalse(
            try userNotificationCenterManagerMock.removeCalls
                .contains(XCTUnwrap(pendingNotification?.key))
        )
        XCTAssertFalse(
            try userNotificationCenterManagerMock.removeCalls
                .contains(XCTUnwrap(pendingNotification?.contentKey))
        )
    }

    func testPendingUserNotificationStartTimedNotificationDeleteMessageWithBaseMessageAndDeliveredNotification() throws {
        let expectedFromIdentity = "SENDER01"

        let deleteMessage = DeleteMessage()
        deleteMessage.fromIdentity = expectedFromIdentity

        let deleteGroupMessage = DeleteGroupMessage()
        deleteGroupMessage.fromIdentity = expectedFromIdentity

        for abstractMessage in [deleteGroupMessage] {
            let expectedMessageID = MockData.generateMessageID()
            let expectedDeletedMessageID = MockData.generateMessageID()
            abstractMessage.messageID = expectedMessageID
            let e2eDeleteMessage = try CspE2e_DeleteMessage.with { message in
                message.messageID = try expectedMessageID.littleEndian()
            }
            try abstractMessage.fromRawProtoBufMessage(
                rawProtobufMessage: e2eDeleteMessage.serializedData() as NSData
            )

            let sender = ContactEntity(context: dbMainCnx.current)
            sender.identity = expectedFromIdentity
            let baseMessage = TextMessageEntity(context: dbMainCnx.current, text: "")
            baseMessage.conversation = ConversationEntity(context: dbMainCnx.current)
            baseMessage.sender = sender
            baseMessage.id = expectedDeletedMessageID

            let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
                returnFireDate: Date(),
                deliveredNotifications: ["\(expectedFromIdentity)\(expectedDeletedMessageID.hexString)"]
            )

            let pendingManager = PendingUserNotificationManager(
                UserNotificationManagerMock(),
                userNotificationCenterManagerMock,
                PushSettingManagerMock(),
                EntityManager()
            )
            _ = pendingManager.pendingUserNotification(
                for: abstractMessage,
                stage: .abstract
            )
            let pendingNotification = pendingManager.pendingUserNotification(
                for: abstractMessage,
                baseMessage: baseMessage,
                stage: .base
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
            XCTAssertEqual(pendingNotification?.key, "\(expectedFromIdentity)\(expectedMessageID.hexString)")
            XCTAssertNotEqual(pendingNotification?.key, pendingNotification?.contentKey)
            XCTAssertNotNil(pendingNotification?.abstractMessage)
            XCTAssertNotNil(pendingNotification?.baseMessage)
            XCTAssertEqual(pendingNotification?.stage, .base)
            XCTAssertNil(pendingNotification?.fireDate)
            XCTAssertEqual(userNotificationCenterManagerMock.addCalls.count, 0)
            XCTAssertFalse(
                try userNotificationCenterManagerMock.removeCalls
                    .contains(XCTUnwrap(pendingNotification?.key))
            )
            XCTAssertTrue(
                try userNotificationCenterManagerMock.removeCalls
                    .contains(XCTUnwrap(pendingNotification?.contentKey))
            )
        }
    }
    
    func testPendingUserNotificationEncodeDecode() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"

        let abstractMsg = BoxTextMessage()
        abstractMsg.text = "Test 1234"
        abstractMsg.messageID = expectedMessageID
        abstractMsg.fromIdentity = expectedFromIdentity

        let pendingManager1 = PendingUserNotificationManager(
            UserNotificationManagerMock(),
            UserNotificationCenterManagerMock(),
            PushSettingManagerMock(),
            EntityManager()
        )
        guard let pendingNotification1 = pendingManager1.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
        ) else {
            XCTFail()
            return
        }
        
        let pendingNotifications = [pendingNotification1]
        
        let archivedData = try NSKeyedArchiver.archivedData(
            withRootObject: pendingNotifications,
            requiringSecureCoding: true
        )
        
        let unarchived = try NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [
                PendingUserNotification.self,
                NSString.self,
                AbstractMessage.self,
                NSData.self,
                NSDate.self,
                NSArray.self,
            ],
            from: archivedData
        ) as? [PendingUserNotification]
        
        let unarchivedUnwrapped = try XCTUnwrap(unarchived)
        XCTAssertEqual(unarchivedUnwrapped.first?.key, pendingNotification1.key)
        
        let processed = [pendingNotification1.key]
        
        let archivedData2 = try NSKeyedArchiver.archivedData(
            withRootObject: processed,
            requiringSecureCoding: true
        )
        
        let unarchived2 = try NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, NSString.self],
            from: archivedData2
        ) as? [String]
        
        let unarchivedUnwrapped2 = try XCTUnwrap(unarchived2)
        XCTAssertEqual(unarchivedUnwrapped2.first, pendingNotification1.key)
    }
}
