import FileUtility
import ThreemaEssentials

import ThreemaProtocols
import XCTest

@testable import ThreemaFramework

final class PendingUserNotificationManagerTests: XCTestCase {
    private var dbMainCnx: DatabaseContextProtocol!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        FileUtility.updateSharedInstance(with: FileUtility())
        
        FileUtility.shared
            .deleteIfExists(at: URL(fileURLWithPath: PendingUserNotificationManager.pathPendingUserNotifications))
        FileUtility.shared
            .deleteIfExists(at: URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications))
        
        PendingUserNotificationManager.clear()

        let testDatabase = TestDatabase()
        dbMainCnx = testDatabase.context

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testPendingUserNotificationAbstractMessage() throws {
        let expectedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedFromIdentity = "SENDER01"

        let abstractMsg = BoxTextMessage()
        abstractMsg.text = "Test 1234"
        abstractMsg.messageID = expectedMessageID
        abstractMsg.fromIdentity = expectedFromIdentity

        let pendingManager1 = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
        )
        let pendingNotification1 = pendingManager1.pendingUserNotification(
            for: abstractMsg,
            stage: .abstract
        )

        XCTAssertEqual("\(expectedFromIdentity)\(expectedMessageID.hexString)", pendingNotification1?.key)

        PendingUserNotificationManager.clear()

        let pendingManager2 = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
            userNotificationManager: UserNotificationManagerMock(
                returnUserNotificationContent: expectedUserNotificationContent
            ),
            userNotificationCenterManager: userNotificationCenterManagerMock,
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
            userNotificationManager: UserNotificationManagerMock(
                returnUserNotificationContent: expectedUserNotificationContent
            ),
            userNotificationCenterManager: userNotificationCenterManagerMock,
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
            let expectedMessageID = BytesUtility.generateMessageID()
            abstractMessage.messageID = expectedMessageID

            let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
                returnFireDate: Date()
            )
            userNotificationCenterManagerMock.removeCalls.removeAll()

            let pendingManager = PendingUserNotificationManager(
                userNotificationManager: UserNotificationManagerMock(),
                userNotificationCenterManager: userNotificationCenterManagerMock,
                pushSettingManager: PushSettingManagerMock(),
                entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedFromIdentity = "SENDER01"
        let expectedEditedMessageID = BytesUtility.generateMessageID()

        let abstractMessage = EditMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.fromIdentity = expectedFromIdentity
        let e2eEditMessage = try CspE2e_EditMessage.with { message in
            message.messageID = try expectedMessageID.littleEndian()
        }
        try abstractMessage.fromRawProtoBufMessage(
            rawProtobufMessage: e2eEditMessage.serializedData() as NSData
        )

        let sender = ContactEntity(
            context: dbMainCnx.current,
            featureMask: 1,
            forwardSecurityState: 1,
            identity: expectedFromIdentity,
            publicKey: BytesUtility.generatePublicKey(),
            readReceipts: 0,
            typingIndicators: 0,
            verificationLevel: 0,
            sortOrderFirstName: true
        )
        sender.setIdentity(to: expectedFromIdentity, sortOrderFirstName: true)
        let baseMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: expectedEditedMessageID,
            isOwn: false,
            text: "",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        baseMessage.sender = sender

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
            returnFireDate: Date()
        )

        let pendingManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: userNotificationCenterManagerMock,
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
        let expectedMessageID = BytesUtility.generateMessageID()
        let expectedFromIdentity = "SENDER01"
        let expectedEditedMessageID = BytesUtility.generateMessageID()

        let abstractMessage = EditMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.fromIdentity = expectedFromIdentity
        let e2eEditMessage = try CspE2e_EditMessage.with { message in
            message.messageID = try expectedMessageID.littleEndian()
        }
        try abstractMessage.fromRawProtoBufMessage(
            rawProtobufMessage: e2eEditMessage.serializedData() as NSData
        )

        let sender = ContactEntity(
            context: dbMainCnx.current,
            featureMask: 1,
            forwardSecurityState: 1,
            identity: expectedFromIdentity,
            publicKey: BytesUtility.generatePublicKey(),
            readReceipts: 0,
            typingIndicators: 0,
            verificationLevel: 0,
            sortOrderFirstName: true
        )

        sender.setIdentity(to: expectedFromIdentity, sortOrderFirstName: true)
        let baseMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: expectedEditedMessageID,
            isOwn: false,
            text: "",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        baseMessage.sender = sender

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
            userNotificationManager: UserNotificationManagerMock(
                returnUserNotificationContent: expectedUserNotificationContent
            ),
            userNotificationCenterManager: userNotificationCenterManagerMock,
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
            let expectedMessageID = BytesUtility.generateMessageID()
            let expectedDeletedMessageID = BytesUtility.generateMessageID()
            abstractMessage.messageID = expectedMessageID
            let e2eDeleteMessage = try CspE2e_DeleteMessage.with { message in
                message.messageID = try expectedMessageID.littleEndian()
            }
            try abstractMessage.fromRawProtoBufMessage(
                rawProtobufMessage: e2eDeleteMessage.serializedData() as NSData
            )

            let sender = ContactEntity(
                context: dbMainCnx.current,
                featureMask: 1,
                forwardSecurityState: 1,
                identity: expectedFromIdentity,
                publicKey: BytesUtility.generatePublicKey(),
                readReceipts: 0,
                typingIndicators: 0,
                verificationLevel: 0,
                sortOrderFirstName: true
            )
            sender.setIdentity(to: expectedFromIdentity, sortOrderFirstName: true)
            let baseMessage = TextMessageEntity(
                context: dbMainCnx.current,
                id: expectedDeletedMessageID,
                isOwn: false,
                text: "",
                conversation: ConversationEntity(context: dbMainCnx.current)
            )
            baseMessage.sender = sender

            let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
                returnFireDate: Date(),
                deliveredNotifications: ["\(expectedFromIdentity)\(expectedDeletedMessageID.hexString)"]
            )

            let pendingManager = PendingUserNotificationManager(
                userNotificationManager: UserNotificationManagerMock(),
                userNotificationCenterManager: userNotificationCenterManagerMock,
                pushSettingManager: PushSettingManagerMock(),
                entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false)
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
