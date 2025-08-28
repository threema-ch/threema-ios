//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
@testable import Threema
@testable import ThreemaFramework

class AppMigrationTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    private var myIdentityStoreMock: MyIdentityStoreMock!
    private var groupManagerMock: GroupManagerMock!
    private var userSettingsMock: UserSettingsMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)

        myIdentityStoreMock = MyIdentityStoreMock()
        groupManagerMock = GroupManagerMock()
        userSettingsMock = UserSettingsMock()
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testRunMigrationToLatestVersion() throws {
        setupDataForMigrationVersion4_8()
        setupDataForMigrationVersion5_5()
        setupDataForMigrationVersion5_6()
        setupDataForMigrationVersion5_7()
        setupDataForMigrationVersion5_9()
        setupDataForMigrationVersion5_9_2()
        setupDataForMigrationVersion6_2()
        setupDataForMigrationVersion6_2_1()
        try setupDataForMigrationVersion6_6()

        // Verify that the migration was started by `doMigrate` and not some other function accidentally accessing the
        // database before the proper migration was initialized.
        DatabaseManager.db().doMigrateDB()

        // Setup mocks
        userSettingsMock.appMigratedToVersion = AppMigrationVersion.none.rawValue

        let keychainHelperMock = KeychainHelperMock()

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbMainCnx, myIdentityStore: myIdentityStoreMock),
            groupManager: groupManagerMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            keychainHelper: keychainHelperMock
        )

        let appMigration = AppMigration(
            businessInjector: businessInjectorMock
        )
        XCTAssertNoThrow(try appMigration.run())

        DDLog.sharedInstance.flushLog()

        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 4.8 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 4.8 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.1 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.1 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.2 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.2 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.3.1 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] App migration to version 5.3.1 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.4 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.4 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.5 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] Removed own contact from contact list"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.5 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.6 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.6 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.7 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.7 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.9 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.9 successfully finished"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 5.9.2 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] App migration to version 5.9.2 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 6.2 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] App migration to version 6.2 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] Files migration to version 6.2.1 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] Files migration to version 6.2.1 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] Files migration to version 6.3 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] Files migration to version 6.3 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 6.6 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] App migration to version 6.6 successfully finished")
        )
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 6.8 started"))
        XCTAssertTrue(
            ddLoggerMock
                .exists(message: "[AppMigration] App migration to version 6.8 successfully finished")
        )

        let entityManager = EntityManager(databaseContext: dbMainCnx)
        let conversations: [ConversationEntity] = entityManager.entityFetcher
            .allConversations() as! [ConversationEntity]
        XCTAssertEqual(conversations.count, 7)

        // Checks for 4.8 migration
        for conversation in ["SENDER01", "SENDER02"]
            .map({ entityManager.entityFetcher.conversationEntity(forIdentity: $0) }) {
            XCTAssertEqual(
                entityManager.entityFetcher.unreadMessages(for: conversation).count, 1
            )
        }

        // Checks for 5.5 migration

        let ownContact = entityManager.entityFetcher.contactsContainOwnIdentity()
        // Own contact should be removed from contact list
        XCTAssertNil(ownContact)

        for conversation in conversations.filter(\.isGroup) {
            let ownMember = conversation.unwrappedMembers.filter { $0.identity == myIdentityStoreMock.identity }
            // Own contact should be removed from group
            XCTAssertEqual(ownMember.count, 0)
        }

        // Checks for 5.6 migration
        let blockList = userSettingsMock.blacklist
        XCTAssertFalse(blockList!.contains(myIdentityStoreMock.identity))

        // Checks for 5.7 migration
        let pushSettings = userSettingsMock.pushSettings
        XCTAssertEqual(pushSettings.count, 4)

        let pushSettingManager = PushSettingManager(
            userSettingsMock,
            GroupManagerMock(),
            EntityManager(),
            TaskManager(),
            false
        )
        var pushSetting1 = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))
        XCTAssertEqual(pushSetting1.type, .offPeriod)
        XCTAssertFalse(pushSetting1.mentioned)
        XCTAssertFalse(pushSetting1.muted)
        XCTAssertNotNil(pushSetting1.periodOffTillDate)

        var pushSetting2 = pushSettingManager.find(forContact: ThreemaIdentity("TESTID01"))
        XCTAssertEqual(pushSetting2.type, .off)
        XCTAssertFalse(pushSetting2.mentioned)
        XCTAssertTrue(pushSetting2.muted)
        XCTAssertNil(pushSetting2.periodOffTillDate)

        let groupIdentity = GroupIdentity(
            id: Data(BytesUtility.toBytes(hexString: "d25fe35845c34ebd")!),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )
        var pushSetting3 = pushSettingManager.find(forGroup: groupIdentity)
        XCTAssertEqual(pushSetting3.type, .on)
        XCTAssertTrue(pushSetting3.mentioned)
        XCTAssertFalse(pushSetting3.muted)
        XCTAssertNil(pushSetting3.periodOffTillDate)

        var pushSetting4 = pushSettingManager.find(forContact: ThreemaIdentity("MEMBER01"))
        XCTAssertEqual(pushSetting4.type, .off)
        XCTAssertFalse(pushSetting4.mentioned)
        XCTAssertFalse(pushSetting4.muted)
        XCTAssertNil(pushSetting4.periodOffTillDate)

        // Checks for 5.9 migration
        let conversation = entityManager.entityFetcher.conversationEntity(forIdentity: "FILEID01")
        let fileMessages = entityManager.entityFetcher.fileMessages(for: conversation) as? [FileMessageEntity]
        XCTAssertNotNil(fileMessages)

        for fileMessage in fileMessages! {
            XCTAssertEqual(fileMessage.caption, "Caption as database field")
        }

        XCTAssertNil(AppGroup.userDefaults().array(forKey: "UnknownGroupAlertList"))

        // Checks for 5.9.2 migration
        XCTAssertNil(AppGroup.userDefaults().object(forKey: "PendingCreateID"))
        // .noSetup because my identity is not valid
        XCTAssertEqual(AppSetupState.notSetup, AppSetup.state)

        // Checks for 6.2 migration
        XCTAssertNil(AppGroup.userDefaults().object(forKey: "LastWorkUpdateRequest"))

        // Checks for 6.3 migration (6.2.1 downgrade of 6.3+ was running before
        // (see `setupDataForMigrationVersion6_2_1()`)
        let outgoingQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "outgoingQueue",
            isDirectory: false
        )
        XCTAssertFalse(FileUtility.shared.isExists(fileURL: outgoingQueuePath))
        let taskQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "taskQueue",
            isDirectory: false
        )
        XCTAssertTrue(FileUtility.shared.isExists(fileURL: taskQueuePath))
        
        // Checks for 6.6 migration
        // Ack/Dec
        let reactionConversation = entityManager.entityFetcher.conversationEntity(forIdentity: "REACTION")
        let reactionConversationMessages = try XCTUnwrap(
            entityManager.entityFetcher
                .textMessages(for: reactionConversation) as? [TextMessageEntity]
        )
        
        XCTAssertEqual(reactionConversationMessages.count, 2)
        for message in reactionConversationMessages {
            XCTAssertNil(message.userackDate)
            
            if message.isOwnMessage {
                let reaction = try XCTUnwrap(message.reactions?.first)
                XCTAssertNotNil(reaction.creator)
                XCTAssertEqual(reaction.reaction, "👎")
            }
            else {
                let reaction = try XCTUnwrap(message.reactions?.first)
                XCTAssertNil(reaction.creator)
                XCTAssertEqual(reaction.reaction, "👍")
            }
        }
        
        // Group reactions
        let reactionContact = entityManager.entityFetcher.contact(for: "REACTION")
        let reactionGroup = entityManager.entityFetcher.groupConversations(for: reactionContact)
            .first as? ConversationEntity
        let reactionGroupMessage = try XCTUnwrap(
            (
                entityManager.entityFetcher
                    .textMessages(for: reactionGroup) as? [TextMessageEntity]
            )?.first
        )
        
        XCTAssertEqual(reactionGroupMessage.groupDeliveryReceipts!.count, 0)
        
        let reactions = try XCTUnwrap(reactionGroupMessage.reactions)
        for reaction in reactions {
            if reaction.creator == nil {
                XCTAssertNil(reaction.creator)
                XCTAssertEqual(reaction.reaction, "👎")
            }
            else {
                XCTAssertNotNil(reaction.creator)
                XCTAssertEqual(reaction.reaction, "👍")
            }
        }

        // Check for 6.8 migration
        XCTAssertEqual(keychainHelperMock.migrateToDowngradeCalls, 0)
    }

    private func setupDataForMigrationVersion4_8() {
        let calendar = Calendar.current

        let addTextMessage: (ConversationEntity, String, Bool) -> Void = { conversation, text, read in
            let date = calendar.date(byAdding: .second, value: +1, to: Date())!
            self.dbPreparer.createTextMessage(
                conversation: conversation,
                text: text,
                date: date,
                delivered: true,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: read,
                sent: false,
                userack: false,
                sender: conversation.contact,
                remoteSentDate: date
            )
        }

        let senders = ["SENDER01", "SENDER02"]
        for sender in senders {
            dbPreparer.save {
                let contact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: sender
                )
                dbPreparer
                    .createConversation(typing: false, unreadMessageCount: 1, visibility: .default) { conversation in
                        conversation.contact = contact

                        addTextMessage(conversation, "text from \(sender)", false)
                        addTextMessage(conversation, "text from \(sender)", true)
                        addTextMessage(conversation, "text from \(sender)", false)
                    }
            }
        }
    }

    private func setupDataForMigrationVersion5_5() {
        dbPreparer.save {
            let ownContactIdentity = dbPreparer.createContact(
                publicKey: myIdentityStoreMock.publicKey,
                identity: myIdentityStoreMock.identity
            )

            let groupIdentity = GroupIdentity(id: MockData.generateGroupID(), creator: ThreemaIdentity("MEMBER01"))
            let expectedMember01 = "MEMBER01"
            let expectedMember02 = "MEMBER02"

            let (groupEntity, conversation) = dbPreparer.save {

                let groupEntity = dbPreparer.createGroupEntity(
                    groupID: groupIdentity.id,
                    groupCreator: nil
                )

                let member01 = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: expectedMember01
                )
                let member02 = dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: expectedMember02
                )

                let conversation = dbPreparer
                    .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                        // swiftformat:disable:next acronyms
                        conversation.groupId = groupEntity.groupId
                        conversation.groupMyIdentity = self.myIdentityStoreMock.identity
                        conversation.members?.insert(member01)
                        conversation.members?.insert(member02)
                        conversation.members?.insert(ownContactIdentity)
                        conversation.lastUpdate = Date(timeIntervalSince1970: 0)
                    }

                dbPreparer.createTextMessage(
                    conversation: conversation,
                    isOwn: false,
                    sender: member01,
                    remoteSentDate: Date()
                )

                return (groupEntity, conversation)
            }

            groupManagerMock.getGroupReturns.append(Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            ))
        }
    }

    private func setupDataForMigrationVersion5_6() {
        // Setup mocks

        let mutableBlocklist = NSMutableOrderedSet()
        mutableBlocklist.add(myIdentityStoreMock.identity)
        userSettingsMock.blacklist = mutableBlocklist

        XCTAssertTrue(userSettingsMock.blacklist!.contains(myIdentityStoreMock.identity))
    }

    private func setupDataForMigrationVersion5_7() {
        dbPreparer.save {
            dbPreparer.createContact(identity: "ECHOECHO")
            dbPreparer.createContact(identity: "TESTID01")

            let groupID = Data(BytesUtility.toBytes(hexString: "d25fe35845c34ebd")!)
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: groupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: groupID) { conversation in
                conversation.groupMyIdentity = self.myIdentityStoreMock.identity
            }

            groupManagerMock.getGroupReturns.append(Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            ))
        }

        // Test data for `UserSetting.NoPushIdentities`
        AppGroup.userDefaults().setValue(["ECHOECHO", "MEMBER01", "D25FE35845C34EBD"], forKey: "NoPushIdentities")

        // Test data for `UserSetting.PushSettingsList`
        let dicKeyIdentity = NSString(string: "identity")
        let dicKeyType = NSString(string: "type")
        let dicKeyPeriodOffTillDate = NSString(string: "periodOffTillDate")
        let dicKeySilent = NSString(string: "silent")
        let dicKeyMentions = NSString(string: "mentions")

        let dateFormatter = Foundation.DateFormatter()
        dateFormatter.locale = Locale(identifier: "de_CH_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        let mutablePushSettingsList = NSMutableOrderedSet()

        // Group not exists in DB
        let dic1 = NSMutableDictionary()
        dic1.setObject("3fb9ad4261d0d30c", forKey: dicKeyIdentity)
        dic1.setObject(NSNumber(integerLiteral: 0), forKey: dicKeyMentions)
        dic1.setObject(NSNumber(integerLiteral: 0), forKey: dicKeySilent)
        dic1.setObject(NSNumber(integerLiteral: 0), forKey: dicKeyType)
        mutablePushSettingsList.add(dic1)

        let dic2 = NSMutableDictionary()
        dic2.setObject("ECHOECHO", forKey: dicKeyIdentity)
        dic2.setObject(NSNumber(integerLiteral: 0), forKey: dicKeyMentions)
        dic2.setObject(
            // Date in the future, type should be .offPeriod
            NSDate(timeIntervalSince1970: Date().addingTimeInterval(60).timeIntervalSince1970),
            forKey: dicKeyPeriodOffTillDate
        )
        dic2.setObject(NSNumber(integerLiteral: 0), forKey: dicKeySilent)
        dic2.setObject(NSNumber(integerLiteral: 2), forKey: dicKeyType)
        mutablePushSettingsList.add(dic2)

        let dic3 = NSMutableDictionary()
        dic3.setObject("TESTID01", forKey: dicKeyIdentity)
        dic3.setObject(NSNumber(integerLiteral: 0), forKey: dicKeyMentions)
        dic3.setObject(NSNumber(integerLiteral: 1), forKey: dicKeySilent)
        dic3.setObject(NSNumber(integerLiteral: 1), forKey: dicKeyType)
        mutablePushSettingsList.add(dic3)

        let dic4 = NSMutableDictionary()
        dic4.setObject("d25fe35845c34ebd", forKey: dicKeyIdentity)
        dic4.setObject(NSNumber(integerLiteral: 1), forKey: dicKeyMentions)
        dic4.setObject(
            // Date in the past, type should be .on
            NSDate(timeIntervalSince1970: dateFormatter.date(from: "2023-11-07T11:21:15+0000")!.timeIntervalSince1970),
            forKey: dicKeyPeriodOffTillDate
        )
        dic4.setObject(NSNumber(integerLiteral: 0), forKey: dicKeySilent)
        dic4.setObject(NSNumber(integerLiteral: 2), forKey: dicKeyType)
        mutablePushSettingsList.add(dic4)

        AppGroup.userDefaults().setValue(mutablePushSettingsList.array, forKey: "PushSettingsList")
    }

    private func setupDataForMigrationVersion5_9() {
        // Caption migration

        // Setup mocks
        let calendar = Calendar.current

        let addFileMessage: (ConversationEntity, String) -> Void = { conversation, caption in
            let testBundle = Bundle(for: DBLoadTests.self)
            let testImageURL = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
            let testImageData = try? Data(contentsOf: testImageURL!)
            let dbFile: FileDataEntity = self.dbPreparer.createFileDataEntity(data: testImageData!)

            let testThumbnailData = MediaConverter.getThumbnailFor(UIImage(data: testImageData!)!)?
                .jpegData(compressionQuality: 1.0)
            let testThumbnailFile: ImageDataEntity = self.dbPreparer.createImageDataEntity(
                data: testThumbnailData!,
                height: 100,
                width: 100
            )

            let date = calendar.date(byAdding: .second, value: +1, to: Date())!
            let encryptionKey = BytesUtility.generateRandomBytes(length: Int(kBlobKeyLen))!
            let messageID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!

            let fileMessageEntity = self.dbPreparer.createFileMessageEntity(
                conversation: conversation,
                encryptionKey: encryptionKey,
                data: dbFile,
                thumbnail: testThumbnailFile,
                mimeType: "image/jpeg",
                type: NSNumber(integerLiteral: 1),
                messageID: messageID,
                date: Date(),
                isOwn: true,
                sent: true,
                delivered: true,
                read: true,
                userack: false
            )

            if let jsonWithoutCaption = FileMessageEncoder.jsonString(for: fileMessageEntity),
               let dataWithoutCaption = jsonWithoutCaption.data(using: .utf8),
               var dict = try? JSONSerialization.jsonObject(with: dataWithoutCaption) as? [String: AnyObject] {
                dict["d"] = caption as AnyObject
                let dataWithCaption = try? JSONSerialization.data(withJSONObject: dict)
                fileMessageEntity.json = String(data: dataWithCaption!, encoding: .utf8)
            }
        }

        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "FILEID01"
            )
            dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = contact
                    addFileMessage(conversation, "Caption as database field")
                    addFileMessage(conversation, "Caption as database field")
                    addFileMessage(conversation, "Caption as database field")
                }
        }

        // Unknown group message removal
        AppGroup.userDefaults()
            .setValue(["groupid": MockData.generateGroupID(), "creator": "CREATOR1"], forKey: "UnknownGroupAlertList")
    }

    private func setupDataForMigrationVersion5_9_2() {
        // Setup should be completed
        AppGroup.userDefaults().set(false, forKey: "PendingCreateID")
    }

    private func setupDataForMigrationVersion6_2() {
        AppGroup.userDefaults().set(["Key", "Value"], forKey: "LastWorkUpdateRequest")
        AppGroup.userDefaults().synchronize()
    }

    private func setupDataForMigrationVersion6_2_1() {
        let outgoingQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "outgoingQueue",
            isDirectory: false
        )
        if FileUtility.shared.isExists(fileURL: outgoingQueuePath) {
            FileUtility.shared.delete(at: outgoingQueuePath)
        }

        let taskQueuePath = FileUtility.shared.appDataDirectory?.appendingPathComponent(
            "taskQueue",
            isDirectory: false
        )
        if !FileUtility.shared.isExists(fileURL: taskQueuePath) {
            _ = FileUtility.shared.write(fileURL: taskQueuePath, text: "Test")
        }
    }
    
    private func setupDataForMigrationVersion6_6() throws {
        let contact = dbPreparer.save {
            dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
                identity: "REACTION"
            )
        }

        try dbPreparer.save {
            // Ack/Dec
            let conversation = dbPreparer
                .createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                    conversation.contact = contact
                }
            dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                userackDate: Date.now,
                userack: true,
                sender: contact,
                remoteSentDate: Date.now
            )
            dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                userackDate: Date.now,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
            
            // Group reactions
            let groupID = MockData.generateGroupID()
            let (_, _, groupConversation) = try dbPreparer.createGroup(
                groupID: groupID,
                groupCreatorIdentity: "REACTION",
                members: ["REACTION"]
            )

            let groupTextMessage = dbPreparer.createTextMessage(
                conversation: groupConversation,
                isOwn: false,
                sender: contact,
                remoteSentDate: Date.now
            )

            groupTextMessage.groupDeliveryReceipts = [
                GroupDeliveryReceipt(
                    identity: "REACTION",
                    deliveryReceiptType: .acknowledged,
                    date: .now
                ),
                GroupDeliveryReceipt(
                    identity: myIdentityStoreMock.identity,
                    deliveryReceiptType: .declined,
                    date: .now
                ),
            ]
        }
    }
}
