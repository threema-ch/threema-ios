//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

final class IntentCreatorTests: XCTestCase {
    private var mainCnx: NSManagedObjectContext!
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    
    private var ddLoggerMock: DDLoggerMock!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
        self.mainCnx = mainCnx
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }
    
    func testAllowedDonateInteractionForIncomingMessage() throws {
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.complete.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNotNil(interaction)
        XCTAssertNotNil(groupInteraction)
    }
    
    func testNotAllowedDonateInteractionForIncomingMessage() throws {
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.balanced.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNil(interaction)
        XCTAssertNil(groupInteraction)
        XCTAssertTrue(ddLoggerMock.exists(message: "Donations for incoming interactions are disabled by the user"))
    }
    
    func testDoNotDonateForPrivateChats1() throws {
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.balanced.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                conversation.changeCategory(to: .private)
                _ = contact1.conversations!.insert(conversation)
                
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                }
            )
        }
        
        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNil(interaction)
        XCTAssertNil(groupInteraction)
    }
    
    func testDoNotDonateForPrivateChats2() throws {
        let entityManager = EntityManager(databaseContext: dbMainCnx)
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.notificationType = NSNumber(integerLiteral: NotificationType.complete.userSettingsValue)

        let groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let dp = DatabasePreparer(context: mainCnx)
        dp.save {
            let contact1 = dp.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "TESTER01",
                verificationLevel: 0
            )
            dp.createConversation(typing: false, unreadMessageCount: 2, visibility: .default) { conversation in
                _ = contact1.conversations!.insert(conversation)
                
                dp.createTextMessage(
                    conversation: conversation,
                    text: "msg1",
                    date: Date(),
                    delivered: true,
                    id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                    isOwn: false,
                    read: false,
                    sent: true,
                    userack: false,
                    sender: contact1,
                    remoteSentDate: Date(timeIntervalSinceNow: -100)
                )
            }
            
            dp.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = groupID
                    conversation.contact = contact1
                    conversation.groupName = "Testgruppe"
                    
                    conversation.changeCategory(to: .private)
                }
            )
        }

        let intentCreator = IntentCreator(userSettings: userSettingsMock, entityManager: entityManager)
        let interaction = intentCreator.inSendMessageIntentInteraction(for: "TESTER01", direction: .incoming)
        let groupInteraction = intentCreator.inSendMessageIntentInteraction(
            for: groupID,
            creatorID: "TESTER01",
            contactID: "TESTER01",
            direction: .incoming
        )
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertNotNil(interaction)
        XCTAssertNil(groupInteraction)
    }
}
