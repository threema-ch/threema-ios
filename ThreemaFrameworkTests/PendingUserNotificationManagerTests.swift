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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
                entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
                userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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
                entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
                userSettings: UserSettingsMock()
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
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
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

    // MARK: - Processed user notifications limit

    func testAddAsProcessedKeepsNewest300Keys() throws {
        let pendingManager = makePendingManager()
        let keys = (0..<301).map { "KEY\($0)" }

        for key in keys {
            pendingManager.addAsProcessed(pendingUserNotification: PendingUserNotification(key: key))
        }

        XCTAssertEqual(try savedProcessedKeys(), Array(keys.dropFirst()))
    }

    func testAddAsProcessedKeepsAllKeysAtLimit() throws {
        let pendingManager = makePendingManager()
        let keys = (0..<300).map { "KEY\($0)" }

        for key in keys {
            pendingManager.addAsProcessed(pendingUserNotification: PendingUserNotification(key: key))
        }

        XCTAssertEqual(try savedProcessedKeys(), keys)
    }

    func testAddAsProcessedDoesNotRewriteFileForKnownKey() throws {
        let pendingManager = makePendingManager()
        let pendingUserNotification = PendingUserNotification(key: "KEY0")
        let fileURL = URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications)

        pendingManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
        XCTAssertEqual(try savedProcessedKeys(), ["KEY0"])

        // Any write would recreate the file
        FileUtility.shared.deleteIfExists(at: fileURL)
        pendingManager.addAsProcessed(pendingUserNotification: pendingUserNotification)

        XCTAssertFalse(FileUtility.shared.fileExists(atPath: fileURL.path))
    }

    func testLoadAllTrimsOversizedProcessedFile() throws {
        let keys = (0..<350).map { "KEY\($0)" }
        let archivedData = try NSKeyedArchiver.archivedData(withRootObject: keys, requiringSecureCoding: true)
        FileUtility.shared.write(
            contents: archivedData,
            to: URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications)
        )

        _ = makePendingManager()

        XCTAssertEqual(try savedProcessedKeys(), Array(keys.suffix(300)))
    }

    // MARK: - Processed user notifications content

    func testAddAsProcessedSkipsMessagesThatNeverNotify() throws {
        let pendingManager = makePendingManager()
        let messages: [AbstractMessage] = [
            TypingIndicatorMessage(),
            DeliveryReceiptMessage(),
            ContactRequestPhotoMessage(),
        ]

        for (index, message) in messages.enumerated() {
            let pendingUserNotification = PendingUserNotification(key: "KEY\(index)")
            pendingUserNotification.abstractMessage = message
            pendingManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
        }

        XCTAssertFalse(
            FileUtility.shared.fileExists(atPath: PendingUserNotificationManager.pathProcessedUserNotifications)
        )
    }

    func testAddAsProcessedRecordsMessagesThatNotify() throws {
        let pendingManager = makePendingManager()
        let messages: [AbstractMessage] = [
            BoxTextMessage(),
            ReactionMessage(),
            GroupReactionMessage(),
        ]

        for (index, message) in messages.enumerated() {
            let pendingUserNotification = PendingUserNotification(key: "KEY\(index)")
            pendingUserNotification.abstractMessage = message
            pendingManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
        }

        XCTAssertEqual(try savedProcessedKeys(), ["KEY0", "KEY1", "KEY2"])
    }

    func testAddAsProcessedRemovesPendingEntry() throws {
        let messages: [AbstractMessage] = [BoxTextMessage(), DeliveryReceiptMessage()]

        for message in messages {
            message.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            message.fromIdentity = "SENDER01"

            let pendingManager = makePendingManager()
            let pendingUserNotification = try XCTUnwrap(
                pendingManager.pendingUserNotification(for: message, stage: .abstract)
            )
            XCTAssertTrue(
                FileUtility.shared.fileExists(atPath: PendingUserNotificationManager.pathPendingUserNotifications),
                "\(type(of: message)): pending entry was not saved"
            )

            pendingManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
            // The removal runs async on `pendingQueue`
            PendingUserNotificationManager.pendingQueue.sync { }

            // The file is deleted when the last pending entry is removed
            XCTAssertFalse(
                FileUtility.shared.fileExists(atPath: PendingUserNotificationManager.pathPendingUserNotifications),
                "\(type(of: message)): pending entry was not removed"
            )
        }
    }

    // MARK: - Helpers

    private func makePendingManager() -> PendingUserNotificationManager {
        PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
        )
    }

    private func savedProcessedKeys() throws -> [String] {
        let data = try XCTUnwrap(
            FileUtility.shared.read(
                fileURL: URL(fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications)
            )
        )
        let keys = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self], from: data)
        return try XCTUnwrap(keys as? [String])
    }
    
    func testPendingUserNotificationReactionsOfSeveralPeopleShareOneNotification() throws {
        let expectedReactedMessageID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

        let firstReactionMsg = GroupReactionMessage()
        firstReactionMsg.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        firstReactionMsg.fromIdentity = "SENDER01"

        let secondReactionMsg = GroupReactionMessage()
        secondReactionMsg.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        secondReactionMsg.fromIdentity = "SENDER02"

        // The message that was reacted to is one of ours
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: expectedReactedMessageID,
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )

        let pendingManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
        )

        let firstPendingNotification = pendingManager.pendingUserNotification(
            for: firstReactionMsg,
            baseMessage: reactedMessage,
            stage: .base
        )
        let secondPendingNotification = pendingManager.pendingUserNotification(
            for: secondReactionMsg,
            baseMessage: reactedMessage,
            stage: .base
        )

        // Every reaction message is still tracked on its own …
        XCTAssertNotEqual(firstPendingNotification?.key, secondPendingNotification?.key)

        // … but they all end up in the one notification of the message they belong to
        XCTAssertEqual(
            "REACTION-\(expectedReactedMessageID.hexString)",
            firstPendingNotification?.contentKey
        )
        XCTAssertEqual(firstPendingNotification?.contentKey, secondPendingNotification?.contentKey)
    }

    func testPendingUserNotificationMessagesOfSeveralPeopleHaveOwnNotification() throws {
        let firstMsg = BoxTextMessage()
        firstMsg.text = "Test 1234"
        firstMsg.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        firstMsg.fromIdentity = "SENDER01"

        let secondMsg = BoxTextMessage()
        secondMsg.text = "Test 5678"
        secondMsg.messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        secondMsg.fromIdentity = "SENDER02"

        let conversation = ConversationEntity(context: dbMainCnx.current)

        let pendingManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(),
            userNotificationCenterManager: UserNotificationCenterManagerMock(),
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
        )

        var contentKeys = [String]()
        for msg in [firstMsg, secondMsg] {
            let baseMessage = TextMessageEntity(
                context: dbMainCnx.current,
                id: msg.messageID,
                isOwn: false,
                text: msg.text,
                conversation: conversation
            )
            let pendingNotification = pendingManager.pendingUserNotification(
                for: msg,
                baseMessage: baseMessage,
                stage: .base
            )
            try contentKeys.append(XCTUnwrap(pendingNotification?.contentKey))
        }

        XCTAssertEqual("SENDER01\(firstMsg.messageID.hexString)", contentKeys.first)
        XCTAssertNotEqual(contentKeys.first, contentKeys.last)
    }

    // MARK: - Reactions

    func testReactionToOwnMessageIsShown() throws {
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        let (pendingNotification, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock
        )

        XCTAssertTrue(shown)
        XCTAssertEqual(userNotificationCenterManagerMock.addCalls, [pendingNotification.contentKey])
    }

    func testReactionToMessageOfSomebodyElseIsNotShown() throws {
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: false,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        let (pendingNotification, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock
        )

        // Only the author of a message is told about reactions to it
        XCTAssertFalse(shown)
        XCTAssertTrue(userNotificationCenterManagerMock.addCalls.isEmpty)
        XCTAssertTrue(userNotificationCenterManagerMock.removeCalls.contains(pendingNotification.contentKey))
    }

    func testReactionNotificationIsRemovedWhenAllReactionsAreWithdrawn() throws {
        // A message of ours without any reaction left, e.g. after the only one was withdrawn
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        let (pendingNotification, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock
        )

        XCTAssertFalse(shown)
        XCTAssertTrue(userNotificationCenterManagerMock.addCalls.isEmpty)
        // The notification already shown goes away, not just a pending one
        XCTAssertTrue(userNotificationCenterManagerMock.removeDeliveredCalls.contains(pendingNotification.contentKey))
    }

    func testReactionToOwnMessageIsShownWithoutAbstractStage() throws {
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        // A message of our own has no sender, so the sender identity can only come from the abstract message
        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        let (pendingNotification, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock,
            runsAbstractStage: false
        )

        XCTAssertTrue(shown)
        XCTAssertEqual(pendingNotification.senderIdentity, "SENDER01")
        XCTAssertEqual(userNotificationCenterManagerMock.addCalls, [pendingNotification.contentKey])
    }

    func testTakingAReactionBackUpdatesTheNotificationSilently() throws {
        // One reaction is left after the other one was taken back
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        let withdrawalCenterMock = UserNotificationCenterManagerMock(
            returnFireDate: Date(),
            deliveredNotifications: [PendingUserNotificationKey.reactionKey(reactedMessageID: reactedMessage.id)]
        )
        _ = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: withdrawalCenterMock,
            isWithdrawal: true
        )

        let updatedNotification = try XCTUnwrap(withdrawalCenterMock.addedNotifications.first)
        XCTAssertNil(updatedNotification.sound)
        XCTAssertEqual(updatedNotification.interruptionLevel, .passive)

        // Applying a reaction alerts as usual
        let applyCenterMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        _ = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: applyCenterMock
        )

        let newNotification = try XCTUnwrap(applyCenterMock.addedNotifications.first)
        XCTAssertNotEqual(newNotification.interruptionLevel, .passive)
    }

    func testTakingAReactionBackDoesNotBringBackADismissedNotification() throws {
        // One reaction is left, but its notification was swiped away
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(returnFireDate: Date())
        let (_, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock,
            isWithdrawal: true
        )

        XCTAssertFalse(shown)
        XCTAssertTrue(userNotificationCenterManagerMock.addCalls.isEmpty)
    }

    func testTakingAReactionBackUpdatesANotificationNotShownYet() throws {
        // The notification about the reaction that remains is still waiting for its trigger
        let reactedMessage = TextMessageEntity(
            context: dbMainCnx.current,
            id: BytesUtility.generateMessageID(),
            isOwn: true,
            text: "Test 1234",
            conversation: ConversationEntity(context: dbMainCnx.current)
        )
        _ = MessageReactionEntity(context: dbMainCnx.current, reaction: "❤️", message: reactedMessage)

        let contentKey = PendingUserNotificationKey.reactionKey(reactedMessageID: reactedMessage.id)
        let userNotificationCenterManagerMock = UserNotificationCenterManagerMock(
            returnFireDate: Date(),
            pendingNotifications: [contentKey]
        )
        let (_, shown) = try startReactionNotification(
            reactedMessage: reactedMessage,
            userNotificationCenterManager: userNotificationCenterManagerMock,
            isWithdrawal: true
        )

        // Otherwise it would still show the reaction that was taken back
        XCTAssertTrue(shown)
        XCTAssertEqual(userNotificationCenterManagerMock.addCalls, [contentKey])
    }

    /// Runs a reaction to `reactedMessage` through `startTimedUserNotification`
    /// - Parameters:
    ///   - reactedMessage: Message the reaction is for
    ///   - userNotificationCenterManager: Records what is added and removed
    ///   - runsAbstractStage: Pass `false` to skip the stage an incoming message usually goes through first
    ///   - isWithdrawal: Pass `true` if the incoming reaction takes a reaction back
    /// - Returns: The pending notification and whether it was shown
    private func startReactionNotification(
        reactedMessage: BaseMessageEntity,
        userNotificationCenterManager: UserNotificationCenterManagerMock,
        runsAbstractStage: Bool = true,
        isWithdrawal: Bool = false
    ) throws -> (pendingNotification: PendingUserNotification, shown: Bool) {
        let reactionMsg = ReactionMessage()
        reactionMsg.messageID = BytesUtility.generateMessageID()
        reactionMsg.fromIdentity = "SENDER01"

        var cspReaction = CspE2e_Reaction()
        cspReaction.messageID = try reactedMessage.id.littleEndian()
        let emojiData = try XCTUnwrap("❤️".data(using: .utf8))
        cspReaction.action = isWithdrawal ? .withdraw(emojiData) : .apply(emojiData)
        reactionMsg.decoded = cspReaction

        // Only whether a notification is added or removed matters here, not what it contains
        let contentPendingNotification = PendingUserNotification(key: "1")
        contentPendingNotification.abstractMessage = reactionMsg

        let pendingManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManagerMock(
                returnUserNotificationContent: UserNotificationContent(contentPendingNotification)
            ),
            userNotificationCenterManager: userNotificationCenterManager,
            pushSettingManager: PushSettingManagerMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx, isRemoteSecretEnabled: false),
            userSettings: UserSettingsMock()
        )

        // Same order as a reaction coming in: the abstract message first, then the message reacted to
        if runsAbstractStage {
            _ = pendingManager.pendingUserNotification(for: reactionMsg, stage: .abstract)
        }
        let pendingNotification = try XCTUnwrap(pendingManager.pendingUserNotification(
            for: reactionMsg,
            baseMessage: reactedMessage,
            stage: .base
        ))

        let expect = expectation(description: "startTimedUserNotification")
        var shown = false
        pendingManager.startTimedUserNotification(pendingUserNotification: pendingNotification)
            .done { result in
                shown = result
                expect.fulfill()
            }
        wait(for: [expect], timeout: 3)

        return (pendingNotification, shown)
    }
}
