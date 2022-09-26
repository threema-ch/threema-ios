//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class UserNotificationContentTests: XCTestCase {
    private var databaseCnx: DatabaseContext!
    private var databasePreparer: DatabasePreparer!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, _) = DatabasePersistentContext.devNullContext()
        databaseCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databasePreparer = DatabasePreparer(context: mainCnx)
    }
    
    func testNoInformation() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertNil(userNotificationContent.cmd)
    }
    
    func testThreemaPushMsg() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newmsg",
                "nick": "red99",
            ])

        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }

    func testThreemaPushGroupMsg() throws {
        let pendingUserNotification = PendingUserNotification(key: "ECHOECHO94c605d0e3150619")
        pendingUserNotification
            .threemaPushNotification =
            try ThreemaPushNotification(from: [
                "from": "ECHOECHO",
                "messageId": "94c605d0e3150619",
                "voip": false,
                "cmd": "newgroupmsg",
                "nick": "red99",
            ])

        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }

    func testAbstractMessage() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.abstractMessage = BoxTextMessage()
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }
    
    func testAbstractGroupMessage() throws {
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.abstractMessage = GroupTextMessage()
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }
    
    func testMessage() throws {
        let expectedIdendity = "ECHOECHO"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 32)!
        
        var textMessage: TextMessage!
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: expectedMessageID,
                identity: expectedIdendity,
                verificationLevel: 0
            )
            databasePreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                conversation.contact = contact
                
                textMessage = self.databasePreparer.createTextMessage(
                    conversation: conversation,
                    text: "Hello world!",
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: contact
                )
            }
        }
        
        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.baseMessage = textMessage
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newmsg")
    }

    func testGroupMessage() throws {
        let expectedIdendity = "ECHOECHO"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 32)!
        
        var textMessage: TextMessage!
        databasePreparer.save {
            let contact = databasePreparer.createContact(
                publicKey: expectedMessageID,
                identity: expectedIdendity,
                verificationLevel: 0
            )
            let group = databasePreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: expectedIdendity
            )
            databasePreparer.createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                conversation.groupID = group.groupID
                conversation.contact = contact
                
                textMessage = self.databasePreparer.createTextMessage(
                    conversation: conversation,
                    text: "Hello world!",
                    date: Date(),
                    delivered: false,
                    id: expectedMessageID,
                    isOwn: true,
                    read: false,
                    sent: false,
                    userack: false,
                    sender: nil
                )
            }
        }

        let pendingUserNotification = PendingUserNotification(key: "1")
        pendingUserNotification.baseMessage = textMessage
        
        let userNotificationContent = UserNotificationContent(pendingUserNotification)
        
        XCTAssertEqual(userNotificationContent.cmd, "newgroupmsg")
    }
}
