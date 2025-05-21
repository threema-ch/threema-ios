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

import ThreemaEssentials
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class UserNotificationManagerTests: XCTestCase {
    private var databaseCnx: DatabaseContext!
    private var databasePreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        databaseCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainCnx)
    }

    func testUserNotificationContentSenderBlocked() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blacklist = ["ECHOECHO"]
        
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
            ])

        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            userSettingsMock,
            MyIdentityStoreMock(),
            PushSettingManagerMock(),
            ContactStoreMock(),
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNil(result)
    }

    func testUserNotificationContentBlockUnknown() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = true

        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
            ])

        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            userSettingsMock,
            MyIdentityStoreMock(),
            PushSettingManagerMock(),
            ContactStoreMock(),
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNil(result)
    }

    func testUserNotificationContentflagImmediateDeliveryRequiredNo() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
            ])
        pendingUserNotification.abstractMessage = TypingIndicatorMessage()

        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            UserSettingsMock(),
            MyIdentityStoreMock(),
            PushSettingManagerMock(),
            ContactStoreMock(),
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNil(result)
    }

    func testUserNotificationContentflagImmediateDeliveryRequiredYes() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
            ])
        pendingUserNotification.abstractMessage = BoxTextMessage()

        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            UserSettingsMock(),
            MyIdentityStoreMock(),
            PushSettingManagerMock(),
            ContactStoreMock(),
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNotNil(result)
    }

    func testUserNotificationContentDoNotDisturbDisabled() throws {

        let testsData = [false, true]

        for testData in testsData {
            let settingStoreMock = SettingsStoreMock()
            settingStoreMock.blockUnknown = false

            let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": "ECHOECHO",
                    "messageId": "94c605d0e3150619",
                    "voip": false,
                    "cmd": "newmsg",
                ])

            let userNotificationManager = UserNotificationManager(
                settingStoreMock,
                UserSettingsMock(),
                MyIdentityStoreMock(),
                PushSettingManagerMock(),
                ContactStoreMock(),
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                testData
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertNotNil(result)
        }
    }

    func testUserNotificationContentDoNotDisturbEnabled() throws {

        let testsData = [
            ["isWorkApp": false, "isResultNil": false],
            ["isWorkApp": true, "isResultNil": true],
        ]

        for testData in testsData {
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMasterDnd = true
            userSettingsMock.masterDndWorkingDays = [2, 3, 4, 5, 6, 7, 1]
            let startDate = Date().addingTimeInterval(60)
            let endDate = startDate.addingTimeInterval(60)

            let calendar = Calendar.current
            userSettingsMock.masterDndStartTime = String(
                format: "%02d:%02d",
                calendar.component(.hour, from: startDate),
                calendar.component(.minute, from: startDate)
            )
            userSettingsMock.masterDndEndTime = String(
                format: "%02d:%02d",
                calendar.component(.hour, from: endDate),
                calendar.component(.minute, from: endDate)
            )

            let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": "ECHOECHO",
                    "messageId": "94c605d0e3150619",
                    "voip": false,
                    "cmd": "newmsg",
                ])

            let userNotificationManager = UserNotificationManager(
                SettingsStoreMock(),
                userSettingsMock,
                MyIdentityStoreMock(),
                PushSettingManager(
                    userSettingsMock,
                    GroupManagerMock(),
                    EntityManager(databaseContext: databaseCnx),
                    TaskManagerMock(),
                    testData["isWorkApp"]!
                ),
                ContactStoreMock(),
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                testData["isWorkApp"]!
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            let isResultNil: Bool = testData["isResultNil"]!
            if isResultNil {
                XCTAssertNil(result)
            }
            else {
                XCTAssertNotNil(result)
            }
        }
    }

    func testUserNotificationContentBlockUnknownWithKnownContact() throws {
        let expectedMessageID = "94c605d0e3150619"
        let expectedSenderID = ThreemaIdentity("0S9AE6CP")
        let expectedFromName = "red99"
        let expectedTitle: String? = "red99"
        let expectedBody = "new_message"
        let expectedAttachmentName: String? = nil
        let expectedAttachmentURL: URL? = nil
        let expectedCmd = "newmsg"
        let expectedCategoryIdentifier = "SINGLE"
        let expectedIsGroupMessage = false
        let expectedGroupID: String? = nil

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = true
        
        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.notificationType = .restrictive
        settingsStoreMock.pushShowPreview = true

        // Create contact for mocking
        let entityManager = EntityManager(databaseContext: databaseCnx)
        databasePreparer.createContact(
            publicKey: Data([1]),
            identity: expectedSenderID.string,
            nickname: expectedFromName
        )
        let contact = entityManager.entityFetcher.contact(for: expectedSenderID.string)
        let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)

        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID.string)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])
        
        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            entityManager,
            TaskManagerMock(),
            false
        )

        let userNotificationManager = UserNotificationManager(
            settingsStoreMock,
            userSettingsMock,
            MyIdentityStoreMock(),
            pushSettingManager,
            contactStoreMock,
            GroupManagerMock(),
            entityManager,
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertEqual(result?.messageID, expectedMessageID)
        XCTAssertEqual(result?.senderID, expectedSenderID.string)
        XCTAssertEqual(result?.fromName, expectedFromName)
        XCTAssertEqual(result?.title, expectedTitle)
        XCTAssertEqual(result?.body, expectedBody)
        XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
        XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
        XCTAssertEqual(result?.cmd, expectedCmd)
        XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
        XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
        XCTAssertEqual(result?.groupID, expectedGroupID)
        
        var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
        XCTAssertEqual(pushSetting?.identity, expectedSenderID)
        XCTAssertEqual(pushSetting?.type, .on)
    }
    
    func testUserNotificationContentBlockUnknownWithSpecialContact() throws {
        let specialContact: PredefinedContacts = .threemaPush
        let expectedMessageID = "94c605d0e3150619"
        guard let expectedSenderID = specialContact.identity else {
            XCTFail("Expected sender identity not found for predefined contact: \(specialContact)")
            return
        }
        let expectedFromName = specialContact.identity?.string
        let expectedTitle: String? = specialContact.identity?.string
        let expectedBody = "new_message"
        let expectedAttachmentName: String? = nil
        let expectedAttachmentURL: URL? = nil
        let expectedCmd = "newmsg"
        let expectedCategoryIdentifier = "SINGLE"
        let expectedIsGroupMessage = false
        let expectedGroupID: String? = nil

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = true
        
        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.notificationType = .restrictive
        settingsStoreMock.pushShowPreview = true

        let entityManager = EntityManager(databaseContext: databaseCnx)
        let contactStoreMock = ContactStoreMock(callOnCompletion: false)
        
        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID.string)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])
        
        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            entityManager,
            TaskManagerMock(),
            false
        )

        let userNotificationManager = UserNotificationManager(
            settingsStoreMock,
            userSettingsMock,
            MyIdentityStoreMock(),
            pushSettingManager,
            contactStoreMock,
            GroupManagerMock(),
            entityManager,
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertEqual(result?.messageID, expectedMessageID)
        XCTAssertEqual(result?.senderID, expectedSenderID.string)
        XCTAssertEqual(result?.fromName, expectedFromName)
        XCTAssertEqual(result?.title, expectedTitle)
        XCTAssertEqual(result?.body, expectedBody)
        XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
        XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
        XCTAssertEqual(result?.cmd, expectedCmd)
        XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
        XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
        XCTAssertEqual(result?.groupID, expectedGroupID)
        
        var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
        XCTAssertEqual(pushSetting?.identity, expectedSenderID)
        XCTAssertEqual(pushSetting?.type, .on)
    }
    
    func testUserNotificationContentBlockUnknownWithPredefiendContact() throws {
        let predefinedContact: PredefinedContacts = .support
        let expectedMessageID = "94c605d0e3150619"
        guard let expectedSenderID = predefinedContact.identity else {
            XCTFail("Expected sender identity not found for predefined contact: \(predefinedContact)")
            return
        }
        let expectedCmd = "newmsg"

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = true
        
        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.notificationType = .restrictive
        settingsStoreMock.pushShowPreview = true

        let entityManager = EntityManager(databaseContext: databaseCnx)
        let contactStoreMock = ContactStoreMock(callOnCompletion: false)
        
        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID.string)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])
        
        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            entityManager,
            TaskManagerMock(),
            false
        )

        let userNotificationManager = UserNotificationManager(
            settingsStoreMock,
            userSettingsMock,
            MyIdentityStoreMock(),
            pushSettingManager,
            contactStoreMock,
            GroupManagerMock(),
            entityManager,
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNil(result)
                
        var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
        XCTAssertEqual(pushSetting?.identity, expectedSenderID)
        XCTAssertEqual(pushSetting?.type, .on)
    }

    func testUserNotificationContentBaseMessageFlags() throws {
        let testsFlags: [Int: Bool] = [
            0: true,
            Int(MESSAGE_FLAG_SEND_PUSH): false,
            Int(MESSAGE_FLAG_IMMEDIATE_DELIVERY): true,
            Int(MESSAGE_FLAG_SEND_PUSH) | Int(MESSAGE_FLAG_IMMEDIATE_DELIVERY): true,
            Int(MESSAGE_FLAG_SEND_PUSH) | Int(MESSAGE_FLAG_DONT_ACK) | Int(MESSAGE_FLAG_GROUP): false,
        ]

        for testFlags in testsFlags {
            // Create base message for mocking
            var textMessage: TextMessageEntity!
            databasePreparer.save {
                let contact = databasePreparer.createContact(
                    publicKey: Data([1]),
                    identity: "ECHOECHO",
                    nickname: "red99"
                )
                databasePreparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        textMessage = self.databasePreparer.createTextMessage(
                            conversation: conversation,
                            text: "This is a test message to test flags!",
                            date: Date(),
                            delivered: true,
                            id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                            isOwn: false,
                            read: false,
                            sent: true,
                            userack: false,
                            sender: contact,
                            remoteSentDate: Date(timeIntervalSinceNow: -100)
                        )

                        textMessage.flags = NSNumber(integerLiteral: testFlags.key)
                    }
            }

            let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": "ECHOECHO",
                    "messageId": "94c605d0e3150619",
                    "voip": false,
                    "cmd": "newmsg",
                ])
            pendingUserNotification.baseMessage = textMessage

            let userNotificationManager = UserNotificationManager(
                SettingsStoreMock(),
                UserSettingsMock(),
                MyIdentityStoreMock(),
                PushSettingManagerMock(),
                ContactStoreMock(),
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result == nil, testFlags.value)
        }
    }

    func testUserNotificationContentPushSettingSendPushSingleChat() throws {
        let expectedMessageID = "94c605d0e3150619"
        let expectedSenderID = ThreemaIdentity("0S9AE6CP")
        let expectedFromName = "0S9AE6CP"
        let expectedTitle: String? = "0S9AE6CP"
        let expectedBody = "new_message"
        let expectedAttachmentName: String? = nil
        let expectedAttachmentURL: URL? = nil
        let expectedCmd = "newmsg"
        let expectedCategoryIdentifier = "SINGLE"
        let expectedIsGroupMessage = false
        let expectedGroupID: String? = nil

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = false

        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.notificationType = .restrictive
        settingsStoreMock.pushShowPreview = true

        var pushSetting = PushSetting(identity: expectedSenderID, groupIdentity: nil, _type: .off)
        pushSetting.setPeriodOffTime(.time1Day)
        userSettingsMock.pushSettings = try [JSONEncoder().encode(pushSetting)]

        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])
        let entityManager = EntityManager(databaseContext: databaseCnx)
        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            entityManager,
            TaskManagerMock(),
            false
        )
        
        let userNotificationManager = UserNotificationManager(
            settingsStoreMock,
            userSettingsMock,
            MyIdentityStoreMock(),
            PushSettingManager(
                userSettingsMock,
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                TaskManagerMock(),
                false
            ),
            ContactStoreMock(),
            GroupManagerMock(),
            entityManager,
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertEqual(result?.messageID, expectedMessageID)
        XCTAssertEqual(result?.senderID, expectedSenderID.string)
        XCTAssertEqual(result?.fromName, expectedFromName)
        XCTAssertEqual(result?.title, expectedTitle)
        XCTAssertEqual(result?.body, expectedBody)
        XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
        XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
        XCTAssertEqual(result?.cmd, expectedCmd)
        XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
        XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
        XCTAssertEqual(result?.groupID, expectedGroupID)
        
        if let pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification) {
            XCTAssertFalse(pushSetting.canSendPush())
        }
        else {
            XCTFail("Push setting is missing")
        }
    }

    func testUserNotificationContentPushSettingSendPushGroupChat() throws {
        let groupID: Data = MockData.generateGroupID()
        let groupCreator = ThreemaIdentity("CREATOR1")

        let expectedMessageID = "94c605d0e3150619"
        let expectedSenderID = ThreemaIdentity("0S9AE6CP")
        let expectedFromName = "red99"
        let expectedTitle: String? = "This is a group text"
        let expectedBody = "red99: This is a group message"
        let expectedAttachmentName: String? = nil
        let expectedAttachmentURL: URL? = nil
        let expectedCmd = "newgroupmsg"
        let expectedCategoryIdentifier = "GROUP"
        let expectedIsGroupMessage = true
        let expectedGroupIdentity = GroupIdentity(id: groupID, creator: groupCreator)

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = false
        userSettingsMock.pushDecrypt = true

        var pushSetting = PushSetting(identity: nil, groupIdentity: expectedGroupIdentity, _type: .off)
        pushSetting.setPeriodOffTime(.time1Day)
        userSettingsMock.pushSettings = try [JSONEncoder().encode(pushSetting)]

        let settingsStoreMock = SettingsStoreMock()
        settingsStoreMock.pushShowPreview = true
        settingsStoreMock.notificationType = .restrictive

        // Create message for mocking
        var textMessage: TextMessageEntity!
        databasePreparer.save {
            let contactGroupCreator = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: groupCreator.string,
                nickname: groupCreator.string
            )
            let contact = databasePreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: expectedSenderID.string,
                nickname: expectedFromName
            )
            let group = databasePreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreator.string)
            databasePreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = group.groupId
                    conversation.contact = contactGroupCreator
                    conversation.groupName = expectedTitle

                    textMessage = self.databasePreparer.createTextMessage(
                        conversation: conversation,
                        text: "This is a group message",
                        date: Date(),
                        delivered: true,
                        id: Data(BytesUtility.toBytes(hexString: expectedMessageID)!),
                        isOwn: false,
                        read: false,
                        sent: true,
                        userack: false,
                        sender: contact,
                        remoteSentDate: Date(timeIntervalSinceNow: -100)
                    )
                }
        }

        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])
        pendingUserNotification.baseMessage = textMessage

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            TaskManagerMock(),
            false
        )

        let userNotificationManager = UserNotificationManager(
            settingsStoreMock,
            userSettingsMock,
            MyIdentityStoreMock(),
            pushSettingManager,
            ContactStoreMock(),
            GroupManagerMock(),
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertEqual(result?.messageID, expectedMessageID)
        XCTAssertEqual(result?.senderID, expectedSenderID.string)
        XCTAssertEqual(result?.fromName, expectedFromName)
        XCTAssertEqual(result?.title, expectedTitle)
        XCTAssertEqual(result?.body, expectedBody)
        XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
        XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
        XCTAssertEqual(result?.cmd, expectedCmd)
        XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
        XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
        XCTAssertEqual(result?.groupID, expectedGroupIdentity.id.base64EncodedString())

        if let pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification) {
            XCTAssertFalse(pushSetting.canSendPush())
        }
        else {
            XCTFail("Push setting is missing")
        }
    }

    func testUserNotificationContentPushOnly() throws {
        let expectedMessageID = "94c605d0e3150619"
        let expectedSenderID = ThreemaIdentity("0S9AE6CP")
        let expectedFromName = "0S9AE6CP"
        let expectedTitle: String? = "0S9AE6CP"
        let expectedBody = "new_message"
        let expectedAttachmentName: String? = nil
        let expectedAttachmentURL: URL? = nil
        let expectedCmd = "newmsg"
        let expectedCategoryIdentifier = "SINGLE"
        let expectedIsGroupMessage = false
        let expectedGroupID: String? = nil

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = false

        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
        pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
            "from": expectedSenderID.string,
            "messageId": expectedMessageID,
            "voip": false,
            "cmd": expectedCmd,
        ])

        let entityManager = EntityManager(databaseContext: databaseCnx)
        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            entityManager,
            TaskManagerMock(),
            false
        )
        
        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            userSettingsMock,
            MyIdentityStoreMock(),
            pushSettingManager,
            ContactStoreMock(),
            GroupManagerMock(),
            entityManager,
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertEqual(result?.messageID, expectedMessageID)
        XCTAssertEqual(result?.senderID, expectedSenderID.string)
        XCTAssertEqual(result?.fromName, expectedFromName)
        XCTAssertEqual(result?.title, expectedTitle)
        XCTAssertEqual(result?.body, expectedBody)
        XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
        XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
        XCTAssertEqual(result?.cmd, expectedCmd)
        XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
        XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
        XCTAssertEqual(result?.groupID, expectedGroupID)
        
        var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
        XCTAssertEqual(pushSetting?.identity, expectedSenderID)
        XCTAssertEqual(pushSetting?.type, .on)
    }

    func testUserNotificationContentPushWithAbstractMessage() throws {

        let testsData = [
            [
                "pushShowNickname": false,
                "pushDecrypt": false,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "new_message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": false,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "new_message",
            ],
            [
                "pushShowNickname": false,
                "pushDecrypt": true,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "This is a message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": true,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "This is a message",
            ],
        ]

        for testData in testsData {
            let expectedMessageID = "94c605d0e3150619"
            let expectedSenderID = ThreemaIdentity("0S9AE6CP")
            let expectedAttachmentName: String? = nil
            let expectedAttachmentURL: URL? = nil
            let expectedCmd = "newmsg"
            let expectedCategoryIdentifier = "SINGLE"
            let expectedIsGroupMessage = false
            let expectedGroupID: String? = nil

            // Create contact for mocking
            var contact: ContactEntity!
            databasePreparer.save {
                contact = databasePreparer.createContact(
                    publicKey: Data([1]),
                    identity: expectedSenderID.string,
                    nickname: "red99"
                )
                contact.setFirstName(to: "Hans")
                contact.setLastName(to: "Muster")
            }
            
            let settingsStoreMock = SettingsStoreMock()
            if testData["pushShowNickname"] as! Bool {
                settingsStoreMock.notificationType = .restrictive
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            else {
                settingsStoreMock.notificationType = .balanced
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.blockUnknown = false
            userSettingsMock.pushDecrypt = testData["pushDecrypt"] as! Bool

            let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)

            // Create abstract message for mocking
            let message = BoxTextMessage()
            message.text = "This is a message"
            message.messageID = Data(BytesUtility.toBytes(hexString: expectedMessageID)!)

            let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": expectedSenderID.string,
                    "messageId": expectedMessageID,
                    "voip": false,
                    "cmd": expectedCmd,
                ])
            pendingUserNotification.abstractMessage = message
            
            let entityManager = EntityManager(databaseContext: databaseCnx)
            let pushSettingManager = PushSettingManager(
                userSettingsMock,
                GroupManagerMock(),
                entityManager,
                TaskManagerMock(),
                false
            )
            
            let userNotificationManager = UserNotificationManager(
                settingsStoreMock,
                userSettingsMock,
                MyIdentityStoreMock(),
                pushSettingManager,
                contactStoreMock,
                GroupManagerMock(),
                entityManager,
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result?.messageID, expectedMessageID)
            XCTAssertEqual(result?.senderID, expectedSenderID.string)
            XCTAssertEqual(result?.fromName, testData["expectedFromName"] as? String)
            XCTAssertEqual(result?.title, testData["expectedTitle"] as? String)
            XCTAssertEqual(result?.body, testData["expectedBody"] as? String)
            XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
            XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
            XCTAssertEqual(result?.cmd, expectedCmd)
            XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
            XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
            XCTAssertEqual(result?.groupID, expectedGroupID)

            var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
            XCTAssertEqual(pushSetting?.identity, expectedSenderID)
            XCTAssertEqual(pushSetting?.type, .on)
        }
    }

    func testUserNotificationContentPushWithAbstractGroupMessage() throws {
        let groupID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreator = "CREATOR1"

        let testsData = [
            [
                "pushShowNickname": false,
                "pushDecrypt": false,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "new_group_message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": false,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "new_group_message",
            ],
            [
                "pushShowNickname": false,
                "pushDecrypt": true,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "new_group_message",
                "expectedBody": "Hans Muster: This is a group message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": true,
                "expectedFromName": "red99",
                "expectedTitle": "new_group_message",
                "expectedBody": "red99: This is a group message",
            ],
        ]

        for testData in testsData {
            let expectedMessageID = "94c605d0e3150619"
            let expectedSenderID = "0S9AE6CP"
            let expectedAttachmentName: String? = nil
            let expectedAttachmentURL: URL? = nil
            let expectedCmd = "newgroupmsg"
            let expectedCategoryIdentifier = "GROUP"
            let expectedIsGroupMessage = true
            let expectedGroupID: String? = groupID
                .base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))

            // Setup Mocks and DB

            let myIdentityStoreMock = MyIdentityStoreMock()
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.blockUnknown = false
            userSettingsMock.pushDecrypt = testData["pushDecrypt"] as! Bool

            let settingsStoreMock = SettingsStoreMock()
            if testData["pushShowNickname"] as! Bool {
                settingsStoreMock.notificationType = .restrictive
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            else {
                settingsStoreMock.notificationType = .balanced
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }

            let groupManagerMock = GroupManagerMock()

            var contact: ContactEntity!
            var creatorContact: ContactEntity!
            var groupEntity: GroupEntity!
            var conversation: ConversationEntity!
            databasePreparer.save {
                contact = databasePreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: expectedSenderID,
                    nickname: "red99"
                )
                contact.setFirstName(to: "Hans")
                contact.setLastName(to: "Muster")

                creatorContact = databasePreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: groupCreator,
                    nickname: "red99"
                )

                groupEntity = databasePreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreator)
                conversation = databasePreparer.createConversation(
                    typing: false,
                    unreadMessageCount: 0,
                    visibility: .default,
                    complete: { conversation in
                        // swiftformat:disable:next acronyms
                        conversation.groupId = groupID
                        conversation.contact = creatorContact
                        conversation.groupMyIdentity = myIdentityStoreMock.identity
                    }
                )
            }
            conversation.members = Set([contact])
            let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)
            
            groupManagerMock.getGroupReturns.append(Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            ))

            // Create abstract group message for mocking
            let message = GroupTextMessage()
            message.groupID = groupID
            message.groupCreator = groupCreator
            message.text = "This is a group message"
            message.messageID = Data(BytesUtility.toBytes(hexString: expectedMessageID)!)
            message.fromIdentity = expectedSenderID

            let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": expectedSenderID,
                    "messageId": expectedMessageID,
                    "voip": false,
                    "cmd": expectedCmd,
                ])
            pendingUserNotification.abstractMessage = message
            
            let entityManager = EntityManager(databaseContext: databaseCnx)
            let pushSettingManager = PushSettingManager(
                userSettingsMock,
                GroupManagerMock(),
                entityManager,
                TaskManagerMock(),
                false
            )
            
            let userNotificationManager = UserNotificationManager(
                settingsStoreMock,
                userSettingsMock,
                MyIdentityStoreMock(),
                pushSettingManager,
                contactStoreMock,
                groupManagerMock,
                entityManager,
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result?.messageID, expectedMessageID)
            XCTAssertEqual(result?.senderID, expectedSenderID)
            XCTAssertEqual(result?.fromName, testData["expectedFromName"] as? String)
            XCTAssertEqual(result?.title, testData["expectedTitle"] as? String)
            XCTAssertEqual(result?.body, testData["expectedBody"] as? String)
            XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
            XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
            XCTAssertEqual(result?.cmd, expectedCmd)
            XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
            XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
            XCTAssertEqual(result?.groupID, expectedGroupID)
            
            let pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
            XCTAssertNotNil(pushSetting)
        }
    }

    func testUserNotificationContentPushWithAbstractGroupMessageGroupLeft() throws {
        let groupID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let groupCreator = "CREATOR1"

        let expectedMessageID = "94c605d0e3150619"
        let expectedSenderID = "0S9AE6CP"
        let expectedCmd = "newgroupmsg"

        // Setup Mocks and DB

        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.blockUnknown = false
        userSettingsMock.pushDecrypt = false
        let groupManagerMock = GroupManagerMock()

        var contact: ContactEntity!
        var creatorContact: ContactEntity!
        var groupEntity: GroupEntity!
        var conversation: ConversationEntity!
        databasePreparer.save {
            contact = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedSenderID,
                nickname: "red99"
            )
            contact.setFirstName(to: "Hans")
            contact.setLastName(to: "Muster")

            creatorContact = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: groupCreator,
                nickname: "red99"
            )

            groupEntity = databasePreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreator)
            groupEntity.state = NSNumber(value: GroupState.left.rawValue)

            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.contact = creatorContact
                    conversation.groupMyIdentity = myIdentityStoreMock.identity
                }
            )
        }

        let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)

        groupManagerMock.getGroupReturns.append(Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        ))

        // Create abstract group message for mocking
        let message = GroupTextMessage()
        message.groupID = groupID
        message.groupCreator = groupCreator
        message.text = "This is a group message"

        let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": expectedSenderID,
                "messageId": expectedMessageID,
                "voip": false,
                "cmd": expectedCmd,
            ])
        pendingUserNotification.abstractMessage = message

        let userNotificationManager = UserNotificationManager(
            SettingsStoreMock(),
            userSettingsMock,
            MyIdentityStoreMock(),
            PushSettingManagerMock(),
            contactStoreMock,
            groupManagerMock,
            EntityManager(databaseContext: databaseCnx),
            false
        )
        let result = userNotificationManager.userNotificationContent(pendingUserNotification)

        XCTAssertNil(result)
    }

    func testUserNotificationContentPushWithBaseMessage() throws {

        let testsData = [
            [
                "pushShowNickname": false,
                "pushDecrypt": false,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "new_message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": false,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "new_message",
            ],
            [
                "pushShowNickname": false,
                "pushDecrypt": true,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "This is a message",
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": true,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "This is a message",
            ],
        ]

        for testData in testsData {
            let expectedMessageID = "94c605d0e3150619"
            let expectedSenderID = ThreemaIdentity("0S9AE6CP")
            let expectedAttachmentName: String? = nil
            let expectedAttachmentURL: URL? = nil
            let expectedCmd = "newmsg"
            let expectedCategoryIdentifier = "SINGLE"
            let expectedIsGroupMessage = false
            let expectedGroupID: String? = nil

            // Create base message in single cnversation for mocking
            var contact: ContactEntity!
            var message: TextMessageEntity!
            databasePreparer.save {
                contact = databasePreparer.createContact(
                    publicKey: Data([1]),
                    identity: expectedSenderID.string,
                    nickname: "red99"
                )
                contact.setFirstName(to: "Hans")
                contact.setLastName(to: "Muster")
                databasePreparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        conversation.contact = contact

                        message = self.databasePreparer.createTextMessage(
                            conversation: conversation,
                            text: "This is a message",
                            date: Date(),
                            delivered: true,
                            id: Data(BytesUtility.toBytes(hexString: expectedMessageID)!),
                            isOwn: false,
                            read: false,
                            sent: true,
                            userack: false,
                            sender: contact,
                            remoteSentDate: Date(timeIntervalSinceNow: -100)
                        )
                    }
            }

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.blockUnknown = false
            userSettingsMock.pushDecrypt = testData["pushDecrypt"] as! Bool

            let settingsStoreMock = SettingsStoreMock()
            if testData["pushShowNickname"] as! Bool {
                settingsStoreMock.notificationType = .restrictive
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            else {
                settingsStoreMock.notificationType = .balanced
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            
            let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)

            let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": expectedSenderID.string,
                    "messageId": expectedMessageID,
                    "voip": false,
                    "cmd": expectedCmd,
                ])
            pendingUserNotification.baseMessage = message

            let entityManager = EntityManager(databaseContext: databaseCnx)
            let pushSettingManager = PushSettingManager(
                userSettingsMock,
                GroupManagerMock(),
                entityManager,
                TaskManagerMock(),
                false
            )
            
            let userNotificationManager = UserNotificationManager(
                settingsStoreMock,
                userSettingsMock,
                MyIdentityStoreMock(),
                pushSettingManager,
                contactStoreMock,
                GroupManagerMock(),
                entityManager,
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result?.messageID, expectedMessageID)
            XCTAssertEqual(result?.senderID, expectedSenderID.string)
            XCTAssertEqual(result?.fromName, testData["expectedFromName"] as? String)
            XCTAssertEqual(result?.title, testData["expectedTitle"] as? String)
            XCTAssertEqual(result?.body, testData["expectedBody"] as? String)
            XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
            XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
            XCTAssertEqual(result?.cmd, expectedCmd)
            XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
            XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
            XCTAssertEqual(result?.groupID, expectedGroupID)

            var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
            XCTAssertEqual(pushSetting?.identity, expectedSenderID)
            XCTAssertEqual(pushSetting?.type, .on)
        }
    }

    func testUserNotificationContentPushWithBaseMessageGroup() throws {
        let groupID = MockData.generateGroupID()
        let groupCreator = ThreemaIdentity("CREATOR1")

        let testsData = [
            [
                "pushShowNickname": false,
                "pushDecrypt": false,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "Hans Muster",
                "expectedBody": "new_group_message",
                "expectedGroupId": groupID.base64EncodedString(),
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": false,
                "expectedFromName": "red99",
                "expectedTitle": "red99",
                "expectedBody": "new_group_message",
                "expectedGroupId": groupID.base64EncodedString(),
            ],
            [
                "pushShowNickname": false,
                "pushDecrypt": true,
                "expectedFromName": "Hans Muster",
                "expectedTitle": "This is a group test",
                "expectedBody": "Hans Muster: This is a group message",
                "expectedGroupId": groupID.base64EncodedString(),
            ],
            [
                "pushShowNickname": true,
                "pushDecrypt": true,
                "expectedFromName": "red99",
                "expectedTitle": "This is a group test",
                "expectedBody": "red99: This is a group message",
                "expectedGroupId": groupID.base64EncodedString(),
            ],
        ]

        for testData in testsData {
            let expectedMessageID = "94c605d0e3150619"
            let expectedSenderID = "0S9AE6CP"
            let expectedAttachmentName: String? = nil
            let expectedAttachmentURL: URL? = nil
            let expectedCmd = "newgroupmsg"
            let expectedCategoryIdentifier = "GROUP"
            let expectedIsGroupMessage = true

            // Create base message in group conversation for mocking
            var contact: ContactEntity!
            var message: TextMessageEntity!
            databasePreparer.save {
                let contactGroupCreator = databasePreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: groupCreator.string,
                    nickname: groupCreator.string
                )
                contact = databasePreparer.createContact(
                    publicKey: Data([1]),
                    identity: expectedSenderID,
                    nickname: "red99"
                )
                contact.setFirstName(to: "Hans")
                contact.setLastName(to: "Muster")

                let group = databasePreparer.createGroupEntity(groupID: groupID, groupCreator: groupCreator.string)
                databasePreparer
                    .createConversation(
                        typing: false,
                        unreadMessageCount: 0,
                        visibility: .default
                    ) { conversation in
                        // swiftformat:disable:next acronyms
                        conversation.groupId = group.groupId
                        conversation.contact = contactGroupCreator
                        conversation.groupName = "This is a group test"

                        message = self.databasePreparer.createTextMessage(
                            conversation: conversation,
                            text: "This is a group message",
                            date: Date(),
                            delivered: true,
                            id: Data(BytesUtility.toBytes(hexString: expectedMessageID)!),
                            isOwn: false,
                            read: false,
                            sent: true,
                            userack: false,
                            sender: contact,
                            remoteSentDate: Date(timeIntervalSinceNow: -100)
                        )
                    }
            }

            let userSettingsMock = UserSettingsMock()
            userSettingsMock.blockUnknown = false
            userSettingsMock.pushDecrypt = testData["pushDecrypt"] as! Bool
            
            let settingsStoreMock = SettingsStoreMock()
            if testData["pushShowNickname"] as! Bool {
                settingsStoreMock.notificationType = .restrictive
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            else {
                settingsStoreMock.notificationType = .balanced
                settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            }
            
            let contactStoreMock = ContactStoreMock(callOnCompletion: false, contact)

            let pendingUserNotification = PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID)")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": expectedSenderID,
                    "messageId": expectedMessageID,
                    "voip": false,
                    "cmd": expectedCmd,
                ])
            pendingUserNotification.baseMessage = message

            let entityManager = EntityManager(databaseContext: databaseCnx)
            let pushSettingManager = PushSettingManager(
                userSettingsMock,
                GroupManagerMock(),
                entityManager,
                TaskManagerMock(),
                false
            )
            
            let userNotificationManager = UserNotificationManager(
                settingsStoreMock,
                userSettingsMock,
                MyIdentityStoreMock(),
                PushSettingManagerMock(),
                contactStoreMock,
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result?.messageID, expectedMessageID)
            XCTAssertEqual(result?.senderID, expectedSenderID)
            XCTAssertEqual(result?.fromName, testData["expectedFromName"] as? String)
            XCTAssertEqual(result?.title, testData["expectedTitle"] as? String)
            XCTAssertEqual(result?.body, testData["expectedBody"] as? String)
            XCTAssertEqual(result?.attachmentName, expectedAttachmentName)
            XCTAssertEqual(result?.attachmentURL, expectedAttachmentURL)
            XCTAssertEqual(result?.cmd, expectedCmd)
            XCTAssertEqual(result?.categoryIdentifier, expectedCategoryIdentifier)
            XCTAssertEqual(result?.isGroupMessage, expectedIsGroupMessage)
            XCTAssertEqual(result?.groupID, testData["expectedGroupId"] as? String)

            var pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification)
            XCTAssertEqual(pushSetting?.groupIdentity, GroupIdentity(id: groupID, creator: groupCreator))
            XCTAssertEqual(pushSetting?.type, .on)
        }
    }

    func testUserNotificationContentPushWithEditMessage() throws {
        // Create abstract message for mocking
        let expectedSenderID = "ECHOECHO"
        let expectedMessageID = MockData.generateMessageID()
        let expectedGroupID = MockData.generateGroupID()

        let expectedGroup = databasePreparer.save {
            let member = databasePreparer.createContact(identity: expectedSenderID)
            let groupEntity = databasePreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversationEntity = databasePreparer.createConversation(groupID: expectedGroupID)
            conversationEntity.members = [member]

            return Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversationEntity,
                lastSyncRequest: nil
            )
        }

        let myIdentityStoreMock = MyIdentityStoreMock()
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        groupManagerMock.getGroupReturns.append(expectedGroup)

        let deleteMessage = DeleteMessage()
        deleteMessage.decoded = try CspE2e_DeleteMessage.with { message in
            message.messageID = try MockData.generateMessageID().littleEndian()
        }
        deleteMessage.fromIdentity = expectedSenderID
        deleteMessage.messageID = expectedMessageID

        let deleteGroupMessage = DeleteGroupMessage()
        deleteGroupMessage.decoded = try CspE2e_DeleteMessage.with { message in
            message.messageID = try MockData.generateMessageID().littleEndian()
        }
        deleteGroupMessage.groupID = expectedGroupID
        deleteGroupMessage.groupCreator = myIdentityStoreMock.identity
        deleteGroupMessage.fromIdentity = expectedSenderID
        deleteGroupMessage.messageID = expectedMessageID

        let editMessage = EditMessage()
        editMessage.decoded = try CspE2e_EditMessage.with { message in
            message.messageID = try MockData.generateMessageID().littleEndian()
            message.text = "This is a message"
        }
        editMessage.fromIdentity = expectedSenderID
        editMessage.messageID = expectedMessageID

        let editGroupMessage = EditGroupMessage()
        editGroupMessage.decoded = try CspE2e_EditMessage.with { message in
            message.messageID = try MockData.generateMessageID().littleEndian()
            message.text = "This is a message"
        }
        editGroupMessage.groupID = expectedGroupID
        editGroupMessage.groupCreator = myIdentityStoreMock.identity
        editGroupMessage.fromIdentity = expectedSenderID
        editGroupMessage.messageID = expectedMessageID

        let testCases: [(abstractMessage: AbstractMessage, cmd: String)] = [
            (deleteMessage, "newmsg"),
            (deleteGroupMessage, "newgroupmsg"),
            (editMessage, "newmsg"),
            (editGroupMessage, "newgroupmsg"),
        ]

        for testCase in testCases {
            let pendingUserNotification =
                PendingUserNotification(key: "\(expectedSenderID)\(expectedMessageID.hexString)")
            pendingUserNotification
                .threemaPushNotification =
                try ThreemaPushNotification(from: [
                    "from": expectedSenderID,
                    "messageId": expectedMessageID.hexString,
                    "voip": false,
                    "cmd": testCase.cmd,
                ])
            pendingUserNotification.abstractMessage = testCase.abstractMessage

            let entityManager = EntityManager(databaseContext: databaseCnx)
            let pushSettingManager = PushSettingManager(
                UserSettingsMock(),
                groupManagerMock,
                entityManager,
                TaskManagerMock(),
                false
            )

            let userNotificationManager = UserNotificationManager(
                SettingsStoreMock(),
                UserSettingsMock(),
                myIdentityStoreMock,
                pushSettingManager,
                ContactStoreMock(),
                groupManagerMock,
                entityManager,
                false
            )
            let result = userNotificationManager.userNotificationContent(pendingUserNotification)

            XCTAssertEqual(result?.messageID, expectedMessageID.hexString)
        }
    }

    func testApplyContent() throws {
        let groupID: Data = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let expectedGroupID: String = groupID.hexString
        let expectedGroupCreator = "ECHOECHO"

        let testsData = [
            // Single push
            [
                "cmd": "newmsg",
                "expectedGroupId": nil,
                "expectedGroupCreator": nil,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "none",
                "silent": false,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "SINGLE-ECHOECHO",
            ],
            [
                "cmd": "newmsg",
                "expectedGroupId": nil,
                "expectedGroupCreator": nil,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "pong",
                "silent": false,
                "expectedSound": true,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "SINGLE-ECHOECHO",
            ],
            [
                "cmd": "newmsg",
                "expectedGroupId": nil,
                "expectedGroupCreator": nil,
                "pushDecrypt": false,
                "pushGroupSound": "pong",
                "pushSound": "none",
                "silent": false,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "SINGLE-ECHOECHO",
            ],
            [
                "cmd": "newmsg",
                "expectedGroupId": nil,
                "expectedGroupCreator": nil,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "none",
                "silent": true,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "SINGLE-ECHOECHO",
            ],
            [
                "cmd": "newmsg",
                "expectedGroupId": nil,
                "expectedGroupCreator": nil,
                "pushDecrypt": true,
                "pushGroupSound": "pong",
                "pushSound": "pong",
                "silent": true,
                "expectedSound": false,
                "expectedCategoryIdentifier": "SINGLE",
                "expectedThreadIdentifier": "SINGLE-ECHOECHO",
            ],
            // Group push
            [
                "cmd": "newgroupmsg",
                "expectedGroupId": expectedGroupID,
                "expectedGroupCreator": expectedGroupCreator,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "none",
                "silent": false,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "GROUP-\(expectedGroupID)-\(expectedGroupCreator)",
            ],
            [
                "cmd": "newgroupmsg",
                "expectedGroupId": expectedGroupID,
                "expectedGroupCreator": expectedGroupCreator,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "pong",
                "silent": false,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "GROUP-\(expectedGroupID)-\(expectedGroupCreator)",
            ],
            [
                "cmd": "newgroupmsg",
                "expectedGroupId": expectedGroupID,
                "expectedGroupCreator": expectedGroupCreator,
                "pushDecrypt": false,
                "pushGroupSound": "pong",
                "pushSound": "none",
                "silent": false,
                "expectedSound": true,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "GROUP-\(expectedGroupID)-\(expectedGroupCreator)",
            ],
            [
                "cmd": "newgroupmsg",
                "expectedGroupId": expectedGroupID,
                "expectedGroupCreator": expectedGroupCreator,
                "pushDecrypt": false,
                "pushGroupSound": "none",
                "pushSound": "none",
                "silent": true,
                "expectedSound": false,
                "expectedCategoryIdentifier": "",
                "expectedThreadIdentifier": "GROUP-\(expectedGroupID)-\(expectedGroupCreator)",
            ],
            [
                "cmd": "newgroupmsg",
                "expectedGroupId": expectedGroupID,
                "expectedGroupCreator": expectedGroupCreator,
                "pushDecrypt": true,
                "pushGroupSound": "pong",
                "pushSound": "pong",
                "silent": true,
                "expectedSound": false,
                "expectedCategoryIdentifier": "GROUP",
                "expectedThreadIdentifier": "GROUP-\(expectedGroupID)-\(expectedGroupCreator)",
            ],
        ]

        let expectedTitle = ""
        let expectedBody = "This is a message"

        for testData in testsData {
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.pushDecrypt = testData["pushDecrypt"] as! Bool
            userSettingsMock.pushGroupSound = testData["pushGroupSound"] as? String
            userSettingsMock.pushSound = testData["pushSound"] as? String
            
            let settingsStoreMock = SettingsStoreMock()
            settingsStoreMock.notificationType = .restrictive
            settingsStoreMock.pushShowPreview = testData["pushDecrypt"] as! Bool
            
            let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
            pendingUserNotification.threemaPushNotification = try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": true,
                "cmd": testData["cmd"] as! String,
            ])
            
            let userNotificationContent = UserNotificationContent(pendingUserNotification)
            userNotificationContent.body = expectedBody
            userNotificationContent.groupID = testData["expectedGroupId"] as? String
            userNotificationContent.groupCreator = testData["expectedGroupCreator"] as? String

            let userNotificationManager = UserNotificationManager(
                settingsStoreMock,
                userSettingsMock,
                MyIdentityStoreMock(),
                PushSettingManagerMock(),
                ContactStoreMock(),
                GroupManagerMock(),
                EntityManager(databaseContext: databaseCnx),
                false
            )

            var result = UNMutableNotificationContent()
            userNotificationManager.applyContent(userNotificationContent, &result, testData["silent"] as! Bool, nil)

            XCTAssertEqual(result.title, expectedTitle)
            XCTAssertEqual(result.body, expectedBody)
            XCTAssertEqual(result.sound != nil, testData["expectedSound"] as! Bool)
            XCTAssertEqual(result.attachments.count, 0)
            XCTAssertEqual((result.userInfo["threema"] as! [AnyHashable: String?])["cmd"], testData["cmd"] as? String)
            XCTAssertEqual((result.userInfo["threema"] as! [AnyHashable: String?])["from"], "ECHOECHO")
            XCTAssertEqual((result.userInfo["threema"] as! [AnyHashable: String?])["messageId"], "94c605d0e3150619")

            if testData["cmd"] as! String == "newmsg" {
                XCTAssertNil((result.userInfo["threema"] as! [AnyHashable: String?])["groupId"] ?? nil)
            }
            else {
                XCTAssertEqual(
                    (result.userInfo["threema"] as! [AnyHashable: String?])["groupId"],
                    testData["expectedGroupId"] as? String
                )
            }
            XCTAssertEqual(result.categoryIdentifier, testData["expectedCategoryIdentifier"] as? String)
            XCTAssertEqual(result.threadIdentifier, testData["expectedThreadIdentifier"] as! String)
        }
    }
}
