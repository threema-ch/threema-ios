//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class AppMigrationTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!
    
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
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    func testRunMigrationToLatestVersion() throws {
        setupDataForMigrationVersion4_8()
        
        // Verify that the migration was started by `doMigrate` and not some other function accidentally accessing the
        // database before the proper migration was initialized.
        DatabaseManager.db().doMigrateDB()
        
        // Setup mocks
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.appMigratedToVersion = AppMigrationVersion.none.rawValue

        let businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            userSettings: userSettingsMock
        )

        let appMigration = AppMigration(
            businessInjector: businessInjectorMock
        )
        XCTAssertNoThrow(try appMigration.run())
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 4.8 started"))
        XCTAssertTrue(ddLoggerMock.exists(message: "[AppMigration] App migration to version 4.8 successfully finished"))

        let entityManager = EntityManager(databaseContext: dbMainCnx)
        let conversations = entityManager.entityFetcher.allConversations()
        XCTAssertEqual(conversations?.count ?? 0, 2)

        // Checks for 4.8 migration
        for conversation in ["SENDER01", "SENDER02"]
            .map({ entityManager.entityFetcher.conversation(forIdentity: $0) }) {
            XCTAssertEqual(
                entityManager.entityFetcher.unreadMessages(for: conversation).count, 1
            )
        }
    }

    private func setupDataForMigrationVersion4_8() {
        let calendar = Calendar.current

        let addTextMessage: (Conversation, String, Bool) -> Void = { conversation, text, read in
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
                    identity: sender,
                    verificationLevel: 0
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
}
